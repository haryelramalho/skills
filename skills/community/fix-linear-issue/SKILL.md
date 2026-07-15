---
name: fix-linear-issue
description: Autonomous loop-engineering pipeline that takes a single Linear issue to a merge-ready pull request. It detects the project profile (salesmart backend via make/testcontainers, or salesmart-web frontend via pnpm/vitest), adapts the verify gate, opens an isolated git worktree, delegates implementation to a cmux-spawned executor worker TUI running native plan mode behind an orchestrator plan-approval gate, cross-checks the change on a second read-only cmux reviewer worker, opens a PR from the template, watches GitHub Actions until green, then stops at a human squash-merge checkpoint. Use it to autonomously fix or implement one specific Linear issue end to end in salesmart or salesmart-web, for example /fix-linear-issue SAL-76, plus its --finalize mode to clean up after the human merge. Do not use it for multi-issue queues or backlog grooming, for repos other than salesmart or salesmart-web, for merging to main without human approval, or when an external CodeRabbit-style PR review provider is required.
---

# Fix Linear Issue

Drive one Linear issue from backlog to a merge-ready PR autonomously, in either
**salesmart** (backend) or **salesmart-web** (frontend) — the skill detects the
project and adapts the gate. Claude Code is the **orchestrator** of the macro
pipeline; a **cmux-spawned executor worker TUI is the execution engine** (Codex
gpt-5.5 for backend, Claude Opus for frontend), running plan-mode first behind an
orchestrator **plan-approval gate**, visible in the user's cmux session so the
human can watch. The Phase 5a cross-model correctness pass runs on a **second cmux
worker — the reviewer** — read-only, model opposite the executor, at `xhigh`. The
pipeline is autonomous up to **PR open + CI green**, emitting terminal
notifications at every stop that waits for a human (clarification questions, any
breaker, the merge checkpoint), then stops at a **human squash-merge checkpoint**. This SKILL.md is the
dispatcher; the load-bearing detail lives in the reference files — inline content
here is a pointer, not a substitute.

## Language protocol

- **Talk to the human in pt-BR (Brazilian Portuguese).** Every message addressed
  to the user — progress updates, questions, summaries, the checkpoint notice —
  is written in pt-BR.
- **Keep all machine-facing artifacts in en-US.** Specs, worker prompts (executor
  and reviewer), subagent instructions, agent-to-agent messages, commit messages,
  PR title/body, code, comments, and Linear updates stay in en-US.
- **Translate on the way out.** When surfacing an en-US artifact (a review
  finding, a CI error, a diff summary) to the human, present it in pt-BR; you may
  quote the original en-US inline when the literal text matters.
- **When in doubt, open an interactive question session with the human in pt-BR**
  rather than guessing — this reinforces the Phase 1 clarification gate and
  applies at any phase where a genuine product/scope ambiguity surfaces.

## Required Reading Router

Match the task to the row. Read the listed files **in full before** acting. They
are the contract; the inline steps below are tripwires only.

| Task | MUST read |
| --- | --- |
| Running the full pipeline (any phase) | `references/pipeline.md` |
| Deciding whether the issue is clear enough to start | `references/clarification-gate.md` |
| Choosing the verify gate / artifact regen for this repo | `references/project-profiles.md` |
| Creating the worktree, committing, or pushing (skeeper) | `references/skeeper-and-isolation.md` |
| Running two or more pipelines at once (concurrency) | `references/skeeper-and-isolation.md` |
| Any cmux action (pane/surface, spawn, send, read-screen, health, notify) | the `cmux-orchestration`, `cmux`, and `cmux-workspace` skills, then `references/cmux-execution.md` |
| Spawning, prompting, plan-approving, or monitoring the cmux executor worker | `references/cmux-execution.md` (+ the cmux skills above) |
| Spawning, prompting, or handing findings back from the cmux reviewer worker | `references/cmux-execution.md` (+ the cmux skills above) |
| Routing the executor and cross-model reviewer workers (runtime/effort, per project) | `references/model-routing.md` |
| Classifying the issue, handling collateral findings, recording assumptions, checking test delta / scope drift, or assembling the PR/checkpoint dossier | `references/flow-discipline.md` |
| Resuming an interrupted run (`--resume`) | `references/pipeline.md` (Resume section) |
| Aborting an in-flight run (`--abort`) | `references/pipeline.md` (Abort section) |
| Entering any remediation loop (verify / review / CI) | `references/circuit-breakers.md` |

## Reference Index

- `references/pipeline.md` — phase-by-phase (0–9) command and tool-call reference
  for the whole loop, plus the run-state schema, the modifiers, and the Resume and
  Abort procedures.
- `references/clarification-gate.md` — when to stop and ask the human vs proceed
  autonomously in Phase 1; the stop / do-not-stop criteria and the `--yolo` skip.
- `references/project-profiles.md` — how the skill detects backend vs frontend
  and the per-profile gate, artifact regen, and test isolation.
- `references/skeeper-and-isolation.md` — skeeper repair/bypass/sync sequence,
  worktree + env + test isolation, and the concurrency guardrails.
- `references/cmux-execution.md` — the cmux workers: per-project executor profile,
  spawn, plan-mode + plan-approval gate, monitoring, remediation re-prompt,
  worker-death respawn, the Phase 5a cross-model reviewer worker (read-only, spawn,
  effort, lifecycle, findings handoff), commit ownership, and terminal notification.
- `references/model-routing.md` — reasoning effort per role (orchestration `xhigh`,
  execution `medium` via the cmux executor worker per project, review `xhigh` via
  the cross-model cmux reviewer worker) and per-project routing (salesmart →
  codex/gpt-5.5 executor + claude/opus reviewer, salesmart-web → claude/opus
  executor + codex/gpt-5.5 reviewer).
- `references/flow-discipline.md` — issue-type classification, bug reproduce-first
  path, collateral findings, assumptions ledger, scope drift, test-delta tripwire,
  and the PR/checkpoint dossier.
- `references/circuit-breakers.md` — per-loop limits, escalation policy, and the
  hard safety rules (no destructive git, no autonomous merge).

## Helper

`<skill-dir>` below is the directory that contains this SKILL.md — the base
directory announced when the skill loads. Invoke every script by that absolute
path.

- `scripts/classify-diff.sh` — **read-only**. Detects the project profile from
  repo markers and classifies the branch diff, printing `PROJECT_PROFILE`,
  `VERIFY_CMD` (the exact gate), and `REGEN_CMD` (artifact regen, or empty).
  Invoke from anywhere inside the worktree (it resolves the repo root itself):
  `bash "<skill-dir>/scripts/classify-diff.sh" origin/main`.
- `scripts/spawn-worker.sh` — **bootstrap** (mutates cmux). Resolves the caller
  workspace, finds or creates the right-side helper pane, opens a worker surface
  (no focus stealing), launches the correct TUI for `(profile, role)` with
  CWD = the worktree and `SKEEPER_SKIP=1` exported, and prints the `surface:N`
  ref. Launch flags mirror `references/model-routing.md`.
  `bash "<skill-dir>/scripts/spawn-worker.sh" <backend-python|frontend-node> <executor|reviewer> "<worktree-abs-path>"`.
- `scripts/wait-worker.sh` — **read-only**. Polls a worker surface until it goes
  idle (conservative: prefers NOT-DONE over a false DONE), printing `DONE`;
  exits non-zero if the surface dies or the max-wait guard (`WAIT_WORKER_TIMEOUT`,
  default 45m) trips. Confirm completion by asking the worker for a status
  summary — do not treat `DONE` as a gate.
  `bash "<skill-dir>/scripts/wait-worker.sh" surface:<N> [interval-seconds]`.
- `scripts/scan-secrets.sh` — **read-only**. Scans the branch diff for secrets
  before a push: literal values from the worktree env files (`.env` / `.env.local`)
  and classic credential patterns. Prints `<file>:<line>: <reason>` per finding;
  exits non-zero on a hit. A hit means do not push.
  `bash "<skill-dir>/scripts/scan-secrets.sh" "<worktree-abs-path>" origin/main`.

## Operating loop

Run the phases in order. Each phase's authoritative commands are in
`references/pipeline.md`.

0. **Pre-flight** — cmux available and the caller workspace resolvable
   (`CMUX_WORKSPACE_ID`/`CMUX_SOCKET_PATH`), `gh` authed, Linear reachable,
   `origin/main` freshly fetched, orchestrator session at `xhigh` (Docker up only
   for the backend profile).
1. **Issue + Explore + Clarify + Spec** — fetch the issue, `Explore` the repo, run
   the clarification gate (stop + ask on genuine product ambiguity unless
   `--yolo`), classify type, bug early-exit if non-reproducible, write a lean spec,
   move Linear → In Progress.
2. **Worktree** — isolated worktree from `origin/main` (freshly fetched), copy the
   env file(s), prepare skeeper.
3. **Implement (cmux executor worker)** — 3a spawn the per-project executor worker
   in the workspace helper pane (`spawn-worker.sh`, effort pinned: plan `xhigh`,
   execution `medium`) and send the spec into its native plan mode, answering any
   clarifying question the worker raises; 3b **capture the full plan output**
   (read-screen with scrollback), review it against the spec at `xhigh`, then
   drive the native approval affordance (Codex `Implement this plan?` picker /
   Claude `ExitPlanMode`) to approve or correct (bounded at 2 rounds); 3c the
   executor worker implements at `medium` while the orchestrator monitors via
   cmux and commits the diff.
4. **Verify** — run `classify-diff.sh` for `PROJECT_PROFILE`/`VERIFY_CMD`/`REGEN_CMD`,
   run `REGEN_CMD` if set, check diff-vs-plan before commit, run `$VERIFY_CMD`,
   then apply the test-delta tripwire.
5. **Review** — correctness cross-model first on a read-only cmux reviewer worker
   (opposite model, `xhigh`), thermo-nuclear last; re-prompt the executor worker to
   remediate each.
6. **PR** — freshness-rebase onto fresh `origin/main`, scan the diff for secrets,
   push `--no-verify`, open PR via template (Conventional-Commit title, no scope;
   it becomes the squash commit) with dossier sections, move Linear → In Review +
   PR comment.
7. **CI watch** — `gh pr checks --watch`; re-prompt the worker for failing jobs;
   re-scan secrets before every re-push, until green.
8. **Checkpoint** — STOP; terminal-notify with PR URL, summarize the dossier + a
   merge checklist + the exact `--finalize` command; the human merges.
9. **Finalize** (`--finalize` only, post-merge) — check the merge commit's CI on
   `main` is green, `skeeper sync`, remove worktree/branch, Linear → Done.

**STOP. Read `references/pipeline.md` in full before executing any phase.** The
list above is a map, not the command contract.

**STOP. Read `references/clarification-gate.md` in full before leaving Phase 1.**
Unless `--yolo`, the pipeline must stop and ask the human when a genuine
product/scope decision the code cannot settle remains. The merge checkpoint is a
safety net, not a license to guess requirements.

**STOP. Read `references/project-profiles.md` in full before running the verify
gate.** The verify command, artifact regen, and test isolation differ between
salesmart (backend) and salesmart-web (frontend); `classify-diff.sh` emits the
right ones. Never assume `make verify` — it is wrong on the frontend.

**STOP. Read `references/skeeper-and-isolation.md` in full before Phase 2 and
before any commit or push.** The skeeper `pre-commit` needs `SKEEPER_SKIP=1`
(audited) and the `pre-push` needs `--no-verify`; a new branch also needs
`skeeper repair`. Getting this wrong blocks every commit and push.

**STOP. Read `references/cmux-execution.md` in full — and load the
`cmux-orchestration`, `cmux`, and `cmux-workspace` skills for the pane/surface
mechanics — before Phase 3 or Phase 5 or any worker interaction.** Execution runs
on a cmux-spawned executor worker TUI (Codex gpt-5.5 backend, Claude Opus
frontend) in its **native plan mode** first, behind an orchestrator plan-approval
gate (bounded at 2 correction rounds). Never let the executor implement without an
explicitly approved plan; remediation re-prompts the same executor worker; the
orchestrator owns commits. The Phase 5a cross-model review runs on a second,
read-only reviewer worker (opposite model, `xhigh`).

**STOP. Read `references/model-routing.md` in full before spawning either worker.**
Execution routing (the cmux executor worker per project, `medium`) and review
routing (the cmux reviewer worker, opposite model, `xhigh`) both live in the skill
profile table. Anything that plans or reviews runs at `xhigh`; anything that
executes runs at `medium`. Never route implementation or remediation to the
reviewer worker.

**STOP. Read `references/circuit-breakers.md` in full before entering any
remediation loop.** Every loop is bounded (2–3 rounds by loop: plan-gate and drift
at 2, remediation loops at 3); hitting a bound stops and escalates. Never mask a
failure to force a gate green.

**STOP. Read `references/flow-discipline.md` in full before writing the spec
(Phase 1) and before any commit or PR.** Bug = failing test first; out-of-scope =
new Linear issue, never a silent fix; every assumption is written down.

## Interface

- `/fix-linear-issue SAL-XX` — run the pipeline (phases 0–8) for one issue; the
  clarification gate is on by default.
- `/fix-linear-issue SAL-XX --yolo` — skip the clarification gate (trust the
  issue; no pre-flight questions).
- `/fix-linear-issue SAL-XX --dry-run` — run Phase 0 + Phase 1 only (pre-flight,
  issue fetch, explore, clarification gate, spec written to scratchpad), then stop
  and report the spec path. No worktree, no worker, no Linear state change.
- `/fix-linear-issue SAL-XX --resume` — resume an interrupted run from its
  run-state file; re-runs Phase 0 pre-flight, revalidates the worktree/branch and
  surfaces, and continues from the recorded phase with its round counters intact
  (→ `references/pipeline.md` Resume section).
- `/fix-linear-issue SAL-XX --finalize` — post-merge cleanup (phase 9), including
  the main-green check on the merge commit before Linear → Done.
- `/fix-linear-issue SAL-XX --abort` — cancel an in-flight run cleanly: close the
  worker surfaces, remove the worktree/branch, revert the Linear issue to the
  state it had before the run, and clear run-state (→ `references/pipeline.md`
  Abort section). Never destructive git on other tracked content.
- One issue per invocation.

## Gist tripwires

The rules most likely to be violated during a run:

- Correctness review runs **before** thermo; thermo is the last local barrier,
  before the PR — not after CI.
- The pipeline **never merges** and **never runs destructive git** without the
  human; it stops at the checkpoint.
- **Never guess a genuine product/scope decision.** Unless `--yolo`, stop in
  Phase 1 and ask; a timed-out or empty answer is UNANSWERED → Linear comment and
  STOP (→ `references/clarification-gate.md`).
- **Bug fixes reproduce first.** The approved plan must write a failing regression
  test before implementation and state root cause.
- **Never fix out of scope silently.** File a new Linear issue for collateral
  findings; only fix a minimal blocker.
- **Every assumption is recorded.** The ledger lives in run-state, spec, PR body,
  and Linear comment.
- The only gate is the classified `$VERIFY_CMD`. Never start a dev server or
  mutate a shared DB (no `make run`/`make migrate`; no `pnpm dev`/`test:e2e:live`).
- **Never implement without an orchestrator-approved plan.** The executor runs
  native plan mode first; the plan gate is capture → `xhigh` review → drive the
  native approval affordance (Codex picker / Claude `ExitPlanMode`), bounded at
  2 correction rounds, then the breaker fires.
- **The orchestrator answers every worker prompt.** Plan-mode questions, pickers,
  permission prompts — the orchestrator is the worker's user and answers via
  `send`/`send-key`; only a genuine product/scope decision goes to the human
  (clarification-gate protocol). A worker left sitting at a prompt is a stalled
  pipeline.
- **Never end a turn with an unattended worker.** Every worker surface has either
  an armed background monitor (`wait-worker.sh`) or a just-sent answer; a `DONE`
  over a mid-work screen is a false idle — re-arm, don't stop.
- Execution runs at `medium` on the cmux executor worker; plan/review run at
  `xhigh` (Codex executor: both pinned at launch via `model_reasoning_effort` +
  `plan_mode_reasoning_effort` — never trust the user's CLI default). Launch
  flags and per-project routing live only in `references/model-routing.md`
  (mirrored by `spawn-worker.sh`).
- **The Phase 5a reviewer is read-only** — a second cmux worker, model opposite
  the executor, `xhigh`. Remediation goes to the executor, never the reviewer.
- **Scan secrets before every push** (`scan-secrets.sh`); env values never leave
  the worktree — not into the spec, PR, Linear, or worker prompts. A hit blocks
  the push.
- **The PR title is the squash commit on `main`** — Conventional Commit, no scope;
  freshness-rebase onto fresh `origin/main` before the push.

## Error handling

- **skeeper commit/push blocked** → `SKEEPER_SKIP=1` for commits, `--no-verify` for
  push, `skeeper repair` on a fresh branch → `references/skeeper-and-isolation.md`.
- **Backend `make` output looks empty/truncated** → `rtk` truncates it; trust the
  exit code or read the tee under `~/Library/Application Support/rtk/tee/`. `pnpm`
  output is not rtk-wrapped.
- **Unknown project profile** → `classify-diff.sh` exits non-zero when repo markers
  match neither backend nor frontend; stop and escalate instead of guessing a gate.
- **A remediation loop stops improving** → the breaker fires at 3 rounds; preserve
  the worktree + logs, terminal-notify, and escalate per
  `references/circuit-breakers.md`.
- **`spawn-worker.sh` fails mid-way** (pane/surface created but launch failed) →
  do not re-run it blindly: inspect the topology (`list-panes` /
  `list-pane-surfaces`), reuse the orphan pane/surface, and launch manually with
  the shell-portable line `cd "<worktree>" && env SKEEPER_SKIP=1 <launch>` (the
  surface shell is often fish; `export` is bash-only) →
  `references/cmux-execution.md` fallback sequence.
- **Worker paused at a question or picker** → that is the orchestrator's prompt
  to answer, not a wait state: read the screen, answer via `send`/`send-key`
  from the spec/issue context, and only route genuine product/scope decisions to
  the human → `references/cmux-execution.md` (orchestrator answers worker
  prompts).
- **Worker surface dead** (TUI exited / surface rejected / `surface-health` gone)
  → respawn one worker of the same role (executor same project profile; reviewer
  same opposite model), re-seed it (executor: spec + current-state summary —
  approved plan, committed diff, active failure; reviewer: branch diff + spec),
  and resume; endless death is a breaker → `references/cmux-execution.md`.
- **cmux unavailable / workspace unresolvable** (no `CMUX_WORKSPACE_ID`, socket
  down, spawn rejected) → stop before Phase 3 and escalate; there is no non-cmux
  fallback for implementation or review → `references/cmux-execution.md`.
- **Reviewer worker cannot be spawned or keeps dying** → one respawn, then the
  worker breaker fires; escalate with the diagnosis. Never route the remediation
  to the reviewer or skip the cross-model review silently.
- **Base advanced before the PR (freshness)** → rebase the feature branch onto
  fresh `origin/main` (`git-rebase` skill on conflicts), re-run `$VERIFY_CMD`, push
  with `--force-with-lease` only if the branch is already on the remote; an
  unresolvable rebase stops and escalates → `references/pipeline.md` Phase 6.
- **`scan-secrets.sh` reports a hit** → do NOT push; treat it as a high-severity
  finding, re-prompt the executor to remove the value and reference it via env
  instead, re-run the gate, re-scan → `references/pipeline.md` Phase 6.
