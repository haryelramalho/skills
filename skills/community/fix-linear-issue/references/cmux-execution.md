# cmux worker execution

Load this file before Phase 3 or any interaction with the implementation
(executor) worker, and before Phase 5 or any interaction with the reviewer
worker (spawn, plan review, prompting, monitoring, remediation, respawn, review
handoff, notification). Both the executor and the cross-model reviewer are
cmux-spawned worker TUIs: the orchestrator (Claude Code) spawns them inside the
current cmux workspace and drives them. The whole point is visual observability:
the human can WATCH each worker run in the pane.

Before any cmux action, load and follow these skills — they are the
authoritative source for cmux commands, scoping, helper-pane reuse, and health
checks:

- `cmux-orchestration` — the controller/worker orchestration model.
- `cmux` — windows, workspaces, panes, surfaces, routing, and health.
- `cmux-workspace` — caller-workspace scoping, helper-pane reuse, socket
  targeting, and non-disruptive automation.

This file only adds the pipeline-specific protocol on top of those skills.

## Contents

- cmux command invocation (rtk split)
- Roles at a glance
- Executor worker profile (per project)
- Preflight and spawn
- Plan-mode + plan-approval gate
- The orchestrator answers worker prompts (never the human by default)
- Implementation + monitoring
- Remediation re-prompt protocol
- Reviewer worker (Phase 5a cross-model)
- Worker-death respawn
- Commit ownership
- Terminal notification

## cmux command invocation (rtk split)

`rtk` is a token-filtering proxy that can truncate or mangle output, so parsing a
cmux JSON payload through it is fragile. Split the cmux commands:

- **Parsed / inspected output → `rtk proxy cmux …`**: `identify`, `list-panes`,
  `list-pane-surfaces`, `read-screen`, `surface-health`, and the ref-returning
  `new-pane` / `new-surface` (the orchestrator reads their `surface:N` /
  `pane:N`). `rtk proxy` runs the raw command with no filtering.
- **Fire-and-forget → plain `rtk cmux …`**: `send`, `send-key`, `notify`,
  `set-status`, `set-progress` — nothing the orchestrator parses.

The bundled `spawn-worker.sh` / `wait-worker.sh` already apply this split; every
inline command below follows it too.

## Roles at a glance

| Role | Runtime | Effort |
| --- | --- | --- |
| Orchestration | this Claude Code session | `xhigh` |
| Executor plan mode (planning only) | same executor TUI, native plan mode | `xhigh` (Codex: pinned at launch) |
| Execution (implement + remediate) | cmux executor worker TUI, per project | `medium` (pinned at launch) |
| Review (Phase 5a cross-model) | cmux reviewer worker TUI, model opposite the executor | `xhigh` |

Both roles run on cmux worker surfaces. The **executor** implements and
remediates at `medium`; the **reviewer** only inspects the diff and reports
findings at `xhigh`. Remediation always goes back to the executor worker, never
to the reviewer.

## Executor worker profile (per project)

Executor routing is per project (preserved decision): `backend-python` → Codex
gpt-5.5, `frontend-node` → Claude Opus. **The literal launch commands and effort
flags live only in `references/model-routing.md`** (mirrored by
`spawn-worker.sh`); this file states the behavior and defers the flags.

Always launch the worker with its CWD set to the isolated worktree directory so
it edits the branch in isolation, at the model and effort tier
`model-routing.md` fixes for the profile and role. If the TUI rejects the model,
auth, CWD, or a flag, stop the worker and report the exact blocker (fire the
plan-gate/worker breaker per `circuit-breakers.md`) — do not silently switch
tools or downgrade the model.

## Preflight and spawn

Follow `cmux-orchestration` / `cmux-workspace` preflight and scoping. Scope every
action to the caller workspace via `CMUX_WORKSPACE_ID` (and `CMUX_SOCKET_PATH` /
`CMUX_SURFACE_ID` when set); never use focus-changing commands.

**Primary path — `spawn-worker.sh`.** Run the bundled bootstrap script; it does
the whole spawn (resolve workspace → find/create the right-side helper pane →
open a terminal surface with `--focus false` → launch the correct TUI for the
profile and role with CWD = worktree and `SKEEPER_SKIP=1` exported) and prints the
`surface:N` ref:

```
bash "<skill-dir>/scripts/spawn-worker.sh" <backend-python|frontend-node> <executor|reviewer> "<worktree-abs-path>"
```

Record the printed `surface:N` in the **run-state file** (executor →
`executorSurface`, reviewer → `reviewerSurface`; see
`references/pipeline.md` Resume section) and address the worker only by that
explicit ref for the rest of the run.

**Fallback — manual sequence** (only if the script fails; each step follows the
rtk split above):

1. Inspect layout: `rtk proxy cmux identify --json`,
   `rtk proxy cmux list-panes --workspace "${CMUX_WORKSPACE_ID:-}" --json`,
   `rtk proxy cmux list-pane-surfaces --workspace "${CMUX_WORKSPACE_ID:-}" --json`.
2. Prefer one right-side helper pane. If a non-caller helper pane exists, add the
   worker surface to it:
   `rtk proxy cmux new-surface --workspace "${CMUX_WORKSPACE_ID:-}" --pane pane:<helper> --type terminal --focus false`.
   Otherwise create exactly one right-side pane:
   `rtk proxy cmux new-pane --workspace "${CMUX_WORKSPACE_ID:-}" --type terminal --direction right --focus false`.
3. Capture the returned `surface:N` into the run-state file; address the worker
   only by that explicit `surface:N` ref for the rest of the run.
4. Launch the worker profile for the project with CWD = worktree, using the launch
   command from `references/model-routing.md`. Because the worker shell must never
   block on skeeper, set the audited bypass in the worker environment as well
   (`SKEEPER_SKIP=1`, see `skeeper-and-isolation.md`). The surface runs the
   user's login shell — often **fish** — so the launch line must be
   shell-portable: `cd "<worktree>" && env SKEEPER_SKIP=1 <launch>` (never
   `export VAR=…`, which is bash-only).

Then reflect run state on the workspace sidebar for the watching human:
`rtk cmux set-status fix-linear-issue "SAL-XX: implementing" --workspace "${CMUX_WORKSPACE_ID:-}" --color "#ff9500"`
and `rtk cmux set-progress <0..1> --label "<phase>" --workspace "${CMUX_WORKSPACE_ID:-}"`.
Clear both when the run ends or is abandoned.

## Plan-mode + plan-approval gate

The executor runs its **native plan mode first** — a real read-only planning
mode in the TUI, not an emulated "please write a plan" prompt. Never let it
implement without an orchestrator-approved plan.

**Never paste multi-line content into a worker via `send`.** In a TUI every
newline submits the line, so a pasted spec or diff fragments into stray prompts.
Always send a **single-line** instruction that points the worker at a file it can
read. The spec lives at its absolute scratchpad path,
`<scratchpad>/fix-linear-issue-<ISSUE>/_spec.md` (`<spec-path>` below), readable
from the worktree. The mechanics differ per runtime:

- **Codex executor (`backend-python`).** Codex has no plan-mode launch flag; enter
  plan mode with the native `/plan` slash command ("Switch to plan mode and
  optionally send a prompt"; the `plan_mode_reasoning_effort` config confirms it).
  After spawn, send one line then Enter:
  `rtk cmux send --surface surface:<worker> "/plan Read the spec at <spec-path> and plan from it; do not edit yet"`
  then `rtk cmux send-key --surface surface:<worker> enter`. In plan mode Codex is
  consultative — it browses and proposes but will not edit or run commands until a
  plan is approved.
- **Claude executor (`frontend-node`).** `spawn-worker.sh` launches Claude Code
  with the native `--permission-mode plan` flag (from `claude --help`), so the
  session starts in plan mode. Send one line then Enter:
  `rtk cmux send --surface surface:<worker> "Read the spec at <spec-path> and produce a plan; do not edit yet"`
  then `rtk cmux send-key --surface surface:<worker> enter`. Claude drafts a plan
  and pauses at its native `ExitPlanMode` approval prompt without editing files.

If a runtime's sandbox blocks reading the scratchpad path, stage a copy of the
spec inside the worktree at an untracked path (add it to the worktree's
`.git/info/exclude`) and reference that path instead — the diff-vs-plan check keeps
it out of any commit.

Include in the plan instruction line that the worker should **ask the
orchestrator directly** if anything is ambiguous — the orchestrator is its user
and will answer in the terminal (see the next section).

Then run the gate as four explicit steps — waiting, **capturing**, **reviewing**,
and **driving the approval affordance**. Steps 2–4 are the gate; skipping any of
them (approving unread, or reading and then ending the turn) is a pipeline
violation.

1. **Wait** until the worker presents a plan and stops for approval (poll via
   `read-screen` / `wait-worker.sh`, see monitoring cadence below). Confirm first
   that the prompt submitted (input line cleared, spinner active) via
   `rtk proxy cmux read-screen --surface surface:<worker>`. `wait-worker.sh`
   prints `PLAN_PROMPT` when it sees the native approval prompt, or `DONE` on
   generic idle; either way the next step is yours **immediately** — never end
   the turn here.
2. **Capture the full plan.** The plan is longer than one screen; read it with
   scrollback — `rtk proxy cmux read-screen --surface surface:<worker> --lines 400`
   (raise the line count / use `--scrollback` until the top of the plan is
   visible). If the tail shows the worker still mid-work (exploration bullets, a
   "drafting the plan" note, no approval prompt), it was a false idle: re-arm
   `wait-worker.sh` in the background and hand control back — do not treat a
   partial screen as the plan.
3. **Review the captured plan against the spec at `xhigh`.** Check: does it
   satisfy every acceptance criterion, respect the binding `CLAUDE.md`
   constraints (layer discipline, test placement, no comments), and stay in
   scope?
4. **Approve or correct through the TUI's native approval affordance**, driven
   via `send`/`send-key`. The affordances are pickers/prompts, not free text:
   - **Codex** ends plan mode with a numbered picker:
     `Implement this plan?` → `1. Yes, implement this plan` /
     `2. Yes, clear context and implement` / `3. No, stay in Plan mode`.
     Option 1 is pre-highlighted (`>`), so a bare
     `rtk cmux send-key --surface surface:<worker> enter` approves it; to pick
     another option, move with `send-key down`/`send-key up` and then `enter`.
     After every keypress, confirm the picker state via `read-screen`.
     - **Approve → option 1** by default. Approval drops the same Codex session
       back to `medium` (the pinned execution effort) and it starts implementing
       with the plan in context.
     - **Approve → option 2** ("clear context and implement") when the picker
       shows heavy context usage (roughly ≥ 75% used) or the plan took 2
       correction rounds — a fresh thread executes the approved plan without the
       planning debris.
     - **Correct → option 3** ("stay in Plan mode"), then send the specific
       corrections as a single line + `send-key enter`.
   - **Claude** pauses at its native `ExitPlanMode` approval prompt: accept it to
     approve (confirm the highlighted option via `read-screen`, then
     `send-key enter`), or reject/stay in plan mode and send corrections as a
     single line.
   - **Corrections are bounded at 2 rounds.** Each correction round re-runs steps
     1–4. If the plan is still wrong after the 2nd correction, the **plan-gate
     circuit breaker fires** — stop, preserve state, notify, and escalate per
     `circuit-breakers.md`.
5. Only after an explicit approval does the worker implement. A plan left
   sitting at its approval prompt is an orchestrator failure, not a worker state:
   if you cannot approve yet (review in progress, human question pending), say so
   to the human and keep the gate as your active task — never end the turn with
   the picker unanswered and no monitor armed.

## The orchestrator answers worker prompts (never the human by default)

To the worker, **the orchestrator is the user**. Whenever a worker pauses on an
interactive prompt — a clarifying question during plan mode, a numbered picker,
a permission/mode prompt, a "should I also…?" — the orchestrator answers it via
`send`/`send-key`, from what it already knows: the spec, the Linear issue, the
Phase 1 exploration, and `CLAUDE.md`. The watching human is an observer, not the
worker's operator.

- **Detect**: prompts surface as a stopped worker; on every `wait-worker.sh`
  return or ambiguous screen, read the tail and look for a question or picker
  before assuming "done".
- **Answer promptly**, single-line (`send` + `send-key enter`; pickers via
  `send-key` arrows + `enter`), and confirm via `read-screen` that the worker
  resumed.
- **Scope guard**: if the worker's question is a **genuine product/scope
  decision** the spec cannot settle (the `clarification-gate.md` criteria), do
  not guess — notify + ask the human (pt-BR), then relay the decision to the
  worker in en-US. Everything else (file placement, naming, which existing
  pattern to follow, test placement, contract details already in the spec) the
  orchestrator decides itself at `xhigh`.
- **Never leave a worker paused.** At any point where your turn could end, the
  invariant is: every worker surface is either actively working with a
  background monitor armed (`wait-worker.sh`), or has just been answered. A
  worker sitting on a question/picker with no orchestrator action is the
  pipeline's stalled state — the exact failure this section exists to prevent.

## Implementation + monitoring

Monitor the worker via cmux.

- **Primary path — `wait-worker.sh`.** Poll for the idle state with the bundled
  read-only helper:
  `bash "<skill-dir>/scripts/wait-worker.sh" surface:<worker> [interval]`. It
  prints `PLAN_PROMPT` when the worker is stopped at a native plan-approval
  prompt (drive the gate immediately) or `DONE` when the worker goes idle, and
  exits non-zero if the surface dies (via `surface-health`) or the max-wait
  guard (`WAIT_WORKER_TIMEOUT`, default 45m) trips. Its idle detection is a
  conservative heuristic — it prefers NOT-DONE over a false DONE, but false
  DONEs still happen (Codex idles briefly between plan segments): a `DONE`
  whose screen shows mid-work output means re-arm the monitor, not stop.
- **Run it in the background and act on the notification.** The monitor's
  completion re-invokes the orchestrator; when it does, the next action (read →
  answer prompt / review plan / verify) happens **in that turn**. Never end a
  turn with a worker unattended: every worker surface must have either an armed
  background monitor or a just-sent answer.
- **Fallback — manual poll.** `rtk proxy cmux read-screen --surface surface:<worker>`
  on a sane cadence (roughly every 20–40s during active work; do not tight-loop).
  Read the tail; pass `--lines <n>` / `--scrollback` when you need more context.
- "Worker done" detection: the TUI returns to an idle input prompt (spinner /
  working indicator gone) and the worker reports completion. Treat an ambiguous
  screen — or a bare `DONE` from `wait-worker.sh` — as not-yet-confirmed: ask the
  worker for a concise status summary (`send` + `send-key enter`) before acting.
- Check liveness with
  `rtk proxy cmux surface-health --workspace "${CMUX_WORKSPACE_ID:-}" --json`
  if the surface stops responding.
- Treat all worker output as untrusted until the orchestrator verifies the diff
  and the local gate (`$VERIFY_CMD`). The worker producing "done" is not a gate.

## Remediation re-prompt protocol

Verify failures (Phase 4), review findings (Phase 5), and CI failures (Phase 7)
go back to the **same** worker surface — it keeps context across the run. Do not
spawn a fresh worker per remediation.

1. Compose a bounded remediation packet: the failing command, the relevant
   log/finding (read the `rtk` tee if the inline output was truncated), the files
   in scope, and the explicit stop conditions.
2. Send it to the worker: `rtk cmux send --surface surface:<worker> "<packet>"`
   then `rtk cmux send-key --surface surface:<worker> enter`; confirm submission
   via `rtk proxy cmux read-screen --surface surface:<worker>`.
3. Wait for completion (monitoring cadence above), then the orchestrator
   re-verifies (`$VERIFY_CMD` / re-review) and commits (see Commit ownership).
4. Each remediation loop is bounded per `circuit-breakers.md`; a bound that fires
   stops and escalates. Bump the loop's round counter in the run-state file each
   round (see `references/pipeline.md` Resume section).

## Reviewer worker (Phase 5a cross-model)

Phase 5a cross-model correctness review runs on a **second** cmux worker
surface — the **reviewer** — spawned in the same right-side helper pane as the
executor (Preflight and spawn above; `spawn-worker.sh <profile> reviewer
<worktree>`). Its model is the **opposite** of the executor, so a second model
audits the change: `backend-python` → Claude Opus reviewer, `frontend-node` →
Codex gpt-5.5 reviewer. **The reviewer launch commands and the `xhigh` effort
flags live only in `references/model-routing.md`** (mirrored by `spawn-worker.sh`).

Rules:

- **Read-only by construction.** The reviewer is launched in a natively read-only
  mode — Claude in plan mode (without write permission), Codex in a read-only
  sandbox — so it **cannot** edit or commit, not merely by instruction. The exact
  launch flags live in `references/model-routing.md`. It only reads the diff and the
  spec and returns findings; state the read-only expectation in its prompt too. All
  remediation goes to the **executor** worker (Remediation re-prompt protocol
  above). The Claude reviewer, being in plan mode, presents its findings and pauses
  at `ExitPlanMode`; the orchestrator reads the findings and does **not** approve —
  the reviewer never implements.
- **Review runs at `xhigh`.** The effort is set at launch by the flag in
  `model-routing.md`. Also instruct the reviewer in-prompt to reason
  exhaustively, so the intent holds even if a CLI build ignores or caps the flag.
- **Findings packet.** Send the reviewer **one line** (never paste the diff — see
  the multi-line rule in Plan-mode above): instruct it to run
  `git diff origin/main...HEAD` in the worktree itself and read the spec at
  `<spec-path>`, then return a structured findings list — each finding as
  `severity` · `file:line` · why it is a bug — and nothing else. Submit via `send`
  + `send-key enter`, confirm with `rtk proxy cmux read-screen`.
- **Findings handoff.** The orchestrator consolidates the reviewer's findings,
  then re-prompts the **executor** worker to remediate (orchestrator commits),
  re-runs `$VERIFY_CMD`, and sends the new diff back to the reviewer for
  re-review. Reuse the **same** reviewer surface across rounds — it keeps context.
- **Lifecycle.** Spawn at Phase 5a; keep it alive for every re-review round in
  the loop; it may be closed after Phase 5 completes. The
  findings → remediation → re-review loop is bounded at **3 rounds** per
  `circuit-breakers.md`. Reviewer spawn/liveness follows the executor rules: one
  respawn of a dead reviewer surface, then the breaker fires.

## Worker-death respawn

If the worker surface has died (surface rejected, TUI exited, `surface-health`
reports it gone):

1. Spawn a fresh worker surface of the same role and project profile with
   `spawn-worker.sh` (Preflight and spawn above), and update its surface ref in
   the run-state file.
2. Re-seed it with the `_spec.md` **plus a current-state summary**: the approved
   plan, what is already committed on the branch (`git log`/diff summary), and the
   outstanding failure or finding driving the current loop.
3. If the worker died mid-implementation before the plan was ever approved,
   restart from the plan-mode gate. If it died during remediation, the approved
   plan still stands — re-seed and resume the current remediation loop; the
   respawn does not reset the loop's round counter (it lives in the run-state
   file, not on the surface).
4. Repeated worker death that blocks progress is a breaker condition — escalate
   rather than respawning endlessly.

## Commit ownership

One rule: **the worker implements; the orchestrator owns commits.**

- The worker edits the working tree only. After each successful implementation or
  remediation, the **orchestrator** inspects the working-tree diff and commits it
  with `SKEEPER_SKIP=1 git commit ...` (audited bypass, see
  `skeeper-and-isolation.md`). This keeps skeeper handling and diff review in the
  orchestrator's hands and gives a clean per-step diff to verify.
- Before every commit, apply the diff-vs-plan rule in
  `references/flow-discipline.md`; out-of-plan files are drift or collateral
  findings, never silent commits.
- Push stays `git push --no-verify` (Phase 6), because the skeeper `pre-push` has
  no env bypass.
- `SKEEPER_SKIP=1` is also exported in the worker's shell so that any incidental
  commit the worker makes is still audited, but the canonical, verified commit is
  the orchestrator's.

## Terminal notification

Notify the watching human in the cmux session at **every stop that waits for a
human** — not only the end. Emit a notification when:

- the Phase 8 merge checkpoint is reached (with the PR URL);
- any circuit breaker fires (with the breaker diagnosis);
- the Phase 1 clarification gate stops to ask a genuine product/scope question;
- a bug is judged non-reproducible and the run ends early (Phase 1);
- the run is aborted (`--abort`).

The reason: the human is the bottleneck at these stops, and an unattended run can
sit silent for hours otherwise.

- Primary mechanism (cmux): `rtk cmux notify --title "<title>" --body "<message>"
  --workspace "${CMUX_WORKSPACE_ID:-}"` (add `--surface surface:<worker>` to
  anchor it to the worker pane). Titles/bodies are user-facing → write them in
  pt-BR, quoting the en-US PR URL / command verbatim.
- Fallback (only if cmux notify is unavailable in the environment):
  `terminal-notifier -title "<title>" -message "<message>"` on macOS. Document
  which one you used in the escalation report.
