# Pipeline — phase-by-phase command reference

Load this file before running the loop. Each phase lists the concrete commands
and the exact tool calls. Phases run in order; a phase only starts after the
previous one succeeds, and the pipeline stops when a remediation loop hits its
bound (the SKILL.md Required Reading Router mandates the circuit-breaker reading
before any remediation).

## Contents

- Run-state file (write rule)
- Modifiers (`--dry-run`, `--resume`, `--yolo`, `--finalize`)
- Phase 0 — Pre-flight
- Phase 1 — Issue + Explore + Clarify + Spec
- Phase 2 — Isolated worktree
- Phase 3 — Implementation via the cmux worker (3a spawn, 3b plan gate, 3c build)
- Phase 4 — Local verify gate
- Phase 5 — Review + auto-remediation (fix first, thermo last)
- Phase 6 — Pull request
- Phase 7 — CI watch
- Phase 8 — Human merge checkpoint (STOP)
- Phase 9 — Finalize (post-merge re-invocation)
- Resume (`--resume`)
- Abort (`--abort`)

## Run-state file

Persist run state so an interrupted run can resume. Write it to the **scratchpad**
(the same directory that holds the lean `_spec.md`), **never** inside a
skeeper-tracked repo path:

```
<scratchpad>/fix-linear-issue-<ISSUE>/run-state.json
```

Schema (example):

```json
{
  "issue": "SAL-76",
  "branch": "SAL-76-fix-ranking-scale",
  "worktree": "/Users/me/.claude/worktrees/SAL-76-fix-ranking-scale",
  "projectProfile": "frontend-node",
  "issueType": "bug",
  "assumptions": [
    "Assumed the frontend label marks the affected area, not the issue type."
  ],
  "collateralIssues": [
    "SAL-99"
  ],
  "flakes": [
    "ranking skeleton-overlay test: passed on the 2nd gate run under load"
  ],
  "executorSurface": "surface:7",
  "reviewerSurface": "surface:9",
  "phase": "5a",
  "rounds": {
    "planGate": 1,
    "driftReentry": 0,
    "verify": 0,
    "review5a": 2,
    "thermo5b": 0,
    "ci": 0
  },
  "prNumber": 123,
  "prUrl": "https://github.com/org/salesmart-web/pull/123",
  "initialLinearState": "Backlog",
  "linearState": "In Review"
}
```

**Write rule:** the orchestrator writes/updates `run-state.json` at every phase
transition, and whenever a surface is (re)spawned (`executorSurface` /
`reviewerSurface`), a round counter increments, an assumption is made, a
collateral issue is filed, or a flake is observed. Round counters never reset on
resume. `issueType` and `initialLinearState` are filled in Phase 1 (capture the
issue's state **before** moving it to In Progress, so `--abort` can restore it);
`prNumber` / `prUrl` are filled in at Phase 6; `linearState` tracks the last
Linear state the pipeline set.

## Modifiers

- `--dry-run` — run Phase 0 + Phase 1 only, then stop. See the note under Phase 1.
- `--resume` — continue an interrupted run from `run-state.json`. See the Resume
  section at the end of this file.
- `--yolo` — skip the Phase 1 clarification gate (see
  `references/clarification-gate.md`).
- `--finalize` — post-merge cleanup only (Phase 9).
- `--abort` — cancel an in-flight run cleanly. See the Abort section at the end of
  this file.

## Phase 0 — Pre-flight

Confirm the runtime before touching anything. Abort with a clear message if any
check fails.

- cmux available and the caller workspace resolvable (both the executor and the
  reviewer workers run here): `rtk proxy cmux identify --json` and a non-empty
  `CMUX_WORKSPACE_ID` (fall back to `CMUX_SOCKET_PATH` targeting). If cmux is
  unavailable or the workspace cannot be resolved, abort before Phase 3. See
  `references/cmux-execution.md`.
- Docker up (testcontainers depend on it): `docker info >/dev/null 2>&1`.
- GitHub CLI authenticated: `gh auth status`.
- Linear MCP reachable: call `mcp__linear__list_teams` (cheap probe).
- Fetch the base: `git fetch origin main`. The worktree is cut from the
  freshly-fetched `origin/main`, never the possibly-stale local `main`.
- Orchestrator session is at `xhigh` reasoning effort (orchestration and review
  run at xhigh; execution runs at `medium` on the cmux worker). The skill cannot
  set the host session's effort — confirm it before starting.
- The pipeline runs inside one repo and adapts to its profile
  (`backend-python` or `frontend-node`); `classify-diff.sh` reports the profile
  and the gate in Phase 4. Docker is required only for the backend profile
  (testcontainers).

## Phase 1 — Issue + Explore + Clarify + Spec

1. Fetch the issue: `mcp__linear__get_issue` with the identifier argument
   (e.g. `SAL-76`). Also call `mcp__linear__list_comments` for context.
2. Explore: dispatch the `Explore` agent to locate the files, layers, and
   existing patterns relevant to the issue. Keep the conclusion, not file dumps.
3. Classify `issueType` as `bug` | `feature` | `tech-debt` from the Linear labels,
   body, comments, and exploration conclusion. The workspace uses team `SAL` and
   leaf-name labels, so area labels are not enough by themselves. Record
   `issueType` in `run-state.json` and the lean spec; for `--dry-run`, include the
   classification in the report instead of creating run-state. Full policy:
   `references/flow-discipline.md`.
4. If `issueType=bug`, establish reproduction by **static evidence** on the
   freshly-fetched `origin/main` — read the code and point to the path/condition
   that produces the reported behavior. Do NOT run tests, dev servers, or any
   mutating command here: no worktree exists yet, and running outside one breaks
   the isolation guardrails. The executable proof (a failing regression test) comes
   in Phase 3 inside the worktree. If the static evidence shows the bug does not
   reproduce or is already fixed on `origin/main`, STOP before the worktree: emit a
   terminal notification, post the evidence as a Linear comment, leave the issue
   state unchanged, and end the run. Never implement for a non-reproducible bug.
   Full policy: `references/flow-discipline.md`.
5. **Clarification gate** (skip only with `--yolo`): classify the issue's
   readiness. Settle everything the code answers via the exploration; if a genuine
   product/scope/business decision remains that the code and issue do not settle,
   STOP here — before the worktree — emit a terminal notification, then ask the
   human and wait. Do not guess a product decision. Proceed only when clear (or
   after answers). The stop/ask criteria are load-bearing — the SKILL.md Required
   Reading Router mandates the clarification-gate reading for this step. Record
   every below-bar self-answered question as an assumption in `run-state.json` and
   the spec.
6. Write a lean spec to the **scratchpad** (never inside skeeper-tracked paths).
   Include: issue summary, acceptance criteria (with any answers folded in),
   `issueType`, assumptions, target files, and the binding `CLAUDE.md` constraints
   (Clean Architecture/DDD layer discipline, Arrow for time, no comments/docstrings,
   test placement, async discipline). For bugs, the spec must require the
   reproduce-first sequence: write a regression test, run it and confirm it fails
   for the reported reason, implement the root-cause fix, and confirm the test
   passes inside `$VERIFY_CMD`. It must also require the root-cause statement.
7. Capture the issue's current state name into `run-state.json` as
   `initialLinearState` (so `--abort` can restore it), then move the Linear issue
   to **In Progress**: resolve the state id via `mcp__linear__list_issue_statuses`
   for the team, then `mcp__linear__save_issue` with that `stateId`. (If the gate
   stopped for questions, leave the issue in its current state until answered.)

**`--dry-run`:** run Phase 0 and Phase 1 only, then STOP and report the spec path
(`<scratchpad>/…/_spec.md`). Skip step 7 — do **not** move Linear to In Progress —
and create no worktree, no worker, and no run-state file. This is a spec preview:
pre-flight, issue fetch, explore, clarification gate, and the written spec, nothing
that mutates the repo or the issue.

## Phase 2 — Isolated worktree

The skeeper and isolation handling for this phase is mandated separately by the
SKILL.md Required Reading Router; complete that reading before proceeding.
Execute, in order:

1. Create the worktree from `origin/main` (freshly fetched in Phase 0) on branch
   `SAL-XX-<slug>` via `using-git-worktrees`. Do not branch from the local `main`,
   which may be behind.
2. Copy the project's local env file(s) into the worktree (backend: `.env`;
   frontend: `.env` / `.env.local` if present).
3. Run `skeeper repair` in the worktree, then `export SKEEPER_SKIP=1` for the
   pipeline environment.

## Phase 3 — Implementation via the cmux worker

Delegate the heavy implementation to a cmux-spawned worker TUI, visible in the
user's workspace so the run can be watched. Executor routing is per project (from
the skill profile table): `backend-python` → Codex gpt-5.5,
`frontend-node` → Claude Opus. The mechanics (preflight, spawn, prompt submission
to a running TUI, monitoring, respawn, notification) live in
`references/cmux-execution.md` and the `cmux-orchestration` skill — read them in
full before acting. The worker runs plan-mode first behind a plan-approval gate;
the orchestrator owns commits.

### Phase 3a — Spawn the worker + send the spec (plan mode)

1. Spawn the per-project executor with the bundled bootstrap script (it scopes to
   the caller workspace, reuses/creates the right-side helper pane, launches the
   correct TUI with CWD = worktree and `SKEEPER_SKIP=1` exported, and prints the
   `surface:N` ref):
   `bash "<skill-dir>/scripts/spawn-worker.sh" <PROJECT_PROFILE> executor "<worktree>"`.
   Record the ref as `executorSurface` in `run-state.json`. Launch flags live in
   `references/model-routing.md`; the manual fallback is in
   `references/cmux-execution.md`.
2. Put the executor in its **native plan mode** and send the spec **as a
   single-line instruction that points at the spec file** — never paste the
   multi-line spec (each newline submits in a TUI). The spec is at
   `<scratchpad>/fix-linear-issue-<ISSUE>/_spec.md` (`<spec-path>`):
   - `backend-python` (Codex): enter plan mode with the native `/plan` slash
     command — `rtk cmux send --surface <executorSurface> "/plan Read the spec at <spec-path> and plan from it; do not edit yet"`
     then `rtk cmux send-key --surface <executorSurface> enter`.
   - `frontend-node` (Claude): `spawn-worker.sh` already launched Claude in its
     native plan mode (flag in `references/model-routing.md`), so send
     `rtk cmux send --surface <executorSurface> "Read the spec at <spec-path> and produce a plan; do not edit yet"`
     then `rtk cmux send-key --surface <executorSurface> enter`; Claude drafts a
     plan and pauses at its native `ExitPlanMode` prompt.
   Confirm the prompt submitted (input line cleared, spinner active) via
   `rtk proxy cmux read-screen`. Full mechanics: `references/cmux-execution.md`.

### Phase 3b — Plan capture + review + approval gate

Planning runs at `xhigh` on the executor (Codex: pinned via
`plan_mode_reasoning_effort=xhigh` at launch); approval drops the same session
back to `medium` for implementation. The gate is four steps — wait, capture,
review, drive the affordance — and the orchestrator answers every worker prompt
along the way (mechanics: `references/cmux-execution.md`).

1. **Wait** until the worker presents a plan and stops for approval
   (`wait-worker.sh` prints `PLAN_PROMPT` or `DONE`); during planning, answer any
   clarifying question the worker raises — the orchestrator is its user. A
   genuine product/scope question routes through the clarification-gate protocol
   to the human; everything else the orchestrator decides at `xhigh`.
2. **Capture the full plan output** with scrollback
   (`rtk proxy cmux read-screen --surface <executorSurface> --lines 400`,
   raising the count until the top of the plan is visible). A screen still
   showing mid-work output is a false idle — re-arm the monitor.
3. **Review the captured plan against the spec at `xhigh`**: every acceptance
   criterion, binding `CLAUDE.md` constraints (layer discipline, test placement,
   no comments), scope, and the issue-type requirements. For `issueType=bug`,
   verify that the plan starts with a regression test that reproduces the bug,
   runs it, confirms the expected failure, then implements the root-cause fix.
   Reject any bug plan without that failing-test-first step; the rejection
   counts as a correction round.
4. **Drive the native approval affordance** — Codex's `Implement this plan?`
   picker (option 1 to approve; option 2 when context usage is heavy; option 3 +
   a single-line correction packet to correct) or Claude's `ExitPlanMode`
   prompt. Corrections are **bounded at 2 rounds**; if the plan is still wrong
   after the 2nd, the plan-gate circuit breaker fires — stop, notify, and
   escalate per `references/circuit-breakers.md`.
5. The worker implements only after an explicit approval, at the pinned `medium`
   execution effort. Never end a turn with the plan sitting unanswered at its
   approval prompt.

### Phase 3c — Implementation + monitoring

1. The executor worker implements the approved plan. Monitor via
   `bash "<skill-dir>/scripts/wait-worker.sh" <executorSurface>` (falls back to
   `rtk proxy cmux read-screen` on a ~20–40s cadence, `rtk proxy cmux surface-health`
   for liveness). Reflect progress on the workspace sidebar
   (`set-status`/`set-progress`) for the watching human.
2. "Worker done" = the TUI returns to an idle input prompt and reports completion;
   treat an ambiguous screen as not-done and ask for a status summary.
3. The orchestrator inspects the working-tree diff, checks it against the approved
   plan, and commits it (`SKEEPER_SKIP=1 git commit ...`); the worker never
   commits. Treat all worker output as untrusted until the diff and the local gate
   confirm it. If the executor materially changes approach or files, halt and
   re-enter the plan gate per `references/flow-discipline.md`.

## Phase 4 — Local verify gate

1. Classify the diff (read-only helper) from inside the worktree — it resolves the
   repo root itself, so any subdirectory works:
   `bash "<skill-dir>/scripts/classify-diff.sh" origin/main`
   → emits `PROJECT_PROFILE`, `VERIFY_CMD`, and `REGEN_CMD`.
2. If `REGEN_CMD` is non-empty: run it, then run the diff-vs-plan check before
   committing the regenerated files (`SKEEPER_SKIP=1 git commit`). Backend:
   `make export-openapi` → `docs/openapi.json` (else `check-openapi` fails CI).
   Frontend: `pnpm api:gen` → `src/lib/api/generated/`.
3. Run the gate verbatim: `$VERIFY_CMD` (backend `make verify-fast|verify-full`;
   frontend `pnpm check`).
4. For backend `make`, `rtk` truncates captured output — trust the exit code, or
   read the tee under `~/Library/Application Support/rtk/tee/`, not the inline
   tail. `pnpm` output is not rtk-wrapped.
5. On failure: **re-run the gate once before dispatching any remediation** — the
   suite has known flakes (e.g. the ranking skeleton-overlay timer under load). If
   the second run passes, it was a flake: record it in `run-state.json` under
   `flakes` and proceed; do not spend a remediation round. Only a **deterministic**
   failure (fails twice) is dispatched to the **same** cmux worker with the failure
   log (it keeps context; see the remediation re-prompt protocol in
   `references/cmux-execution.md`); the orchestrator commits the fix, then re-runs
   the gate. Bounded by the verify circuit breaker.
6. After the gate passes, apply the test-delta tripwire from
   `references/flow-discipline.md`: a bug needs a new/changed regression test, a
   feature needs a new/changed acceptance-criteria test, and behavior-changing
   tech debt needs coverage. A missing required test delta becomes an automatic
   high-severity Phase 5a finding.

## Phase 5 — Review + auto-remediation (fix first, thermo last)

Order is deliberate: close correctness before polishing structure.

- **5a. Cross-model correctness review.** Run `/code-review` (Claude) plus a
  second-model pass at `xhigh` on a **cmux reviewer worker** — a second worker
  surface in the helper pane, model opposite the executor (salesmart → Claude
  Opus, salesmart-web → Codex gpt-5.5). Spawn it with
  `bash "<skill-dir>/scripts/spawn-worker.sh" <PROJECT_PROFILE> reviewer "<worktree>"`
  and record `reviewerSurface`; the launch/effort flags live in
  `references/model-routing.md`. The reviewer is **read-only by construction**
  (launched read-only — Claude plan mode / Codex read-only sandbox; exact flags in
  `references/model-routing.md`): send it a single line telling it to run
  `git diff origin/main...HEAD` itself and read the spec at `<spec-path>`, then
  return a structured findings list (severity · file:line · why it is a bug) —
  never paste the diff inline. The reviewer prompt
  must include the test-delta rule and treat a missing required test delta as
  automatic high severity. Consolidate actionable
  findings → re-prompt the **executor** worker to remediate (orchestrator commits)
  → re-run `$VERIFY_CMD` → send the new diff back to the reviewer worker for
  re-review. Loop until clean or the breaker fires. Spawn, effort, read-only rule,
  and lifecycle are in `references/cmux-execution.md`.
- **5b. Thermo final barrier.** Run `thermo-nuclear-code-quality-review` over the
  branch diff. Re-prompt the cmux worker on its findings (orchestrator commits) →
  re-run `$VERIFY_CMD`. Loop until clean or the breaker fires. Only then proceed to
  the PR.

## Phase 6 — Pull request

1. **Freshness check.** `git fetch origin main`. If `origin/main` advanced past the
   branch's merge-base, rebase the feature branch onto fresh `origin/main` (own
   feature branch, so a rebase is allowed; use the `git-rebase` skill on conflicts).
   This closes the semantic-conflict gap where the branch passed against a stale
   base but the real merge would break. An unresolvable rebase stops the pipeline,
   notifies, and escalates — never mask a conflict.
2. Re-run the final gate after the rebase; it must be green.
3. **Secret scan.** `bash "<skill-dir>/scripts/scan-secrets.sh" "<worktree>" origin/main`.
   A hit means do NOT push: treat it as a high-severity finding, re-prompt the
   executor to remove the value and reference it through env instead, re-run the
   gate, and re-scan. Env values never enter the diff, the PR, or Linear.
4. Push: `git push --no-verify -u origin SAL-XX-<slug>` (the skeeper `pre-push`
   has no env bypass, so `--no-verify` is required). If the branch is already on
   the remote and the freshness rebase rewrote it, push with `--force-with-lease`
   (allowed only on the pipeline's own feature branch).
5. Open the PR with the `create-pr-with-template` skill, base `main`.
   - **Title.** A Conventional Commit `<type>: <description>` — lowercase,
     imperative, **no scope**, no trailing period. The squash merge promotes this
     title to the commit message on `main`, so it must satisfy the repo's commit
     convention.
   - **Body.** Reference the Linear issue and fill the template with the checkpoint
     dossier: issue id + `issueType`; bug root-cause statement when applicable;
     approved plan or faithful summary; diff stats and files touched; a **High
     attention** list (migrations, dependency/lockfile changes, regenerated
     artifacts, or `none`); a **large-diff warning + per-file summary** when the
     diff crosses the thresholds in `references/flow-discipline.md`; Phase 5a/5b
     found → fixed counts by round; observed flakes; exact `$VERIFY_CMD` and final
     exit status; CI status; `## Assumptions`; out-of-scope findings filed;
     blocking collateral fix if any; and what was NOT done.
6. Move the Linear issue to **In Review** (`save_issue` with the resolved
   `stateId`) and post the PR URL as a comment (`mcp__linear__save_comment`).
   The Linear comment also carries the assumptions ledger and collateral issue
   ids so the human can veto assumptions or inspect filed follow-ups cheaply.

## Phase 7 — CI watch

Replaces the video's CodeRabbit watch. Watch GitHub Actions until green.

- `gh pr checks <pr-number> --watch` (or `gh run watch <run-id>`).
- On a failing job: use the `gh-fix-ci` skill to pull logs → re-prompt the same
  cmux worker to remediate (orchestrator commits) → re-run `$VERIFY_CMD` locally →
  re-run `scan-secrets.sh` (a hit blocks the push, same as Phase 6) →
  `git push --no-verify` → re-watch. Bounded by the CI circuit breaker.
- Post-CI fixes are surgical; they must not reopen structural work (thermo
  already ran in Phase 5).

## Phase 8 — Human merge checkpoint (STOP)

When CI is green and review is clean: **STOP**. Do not merge. Emit a terminal
notification visible in the user's cmux session with the PR URL
(`rtk cmux notify --title "..." --body "<PR URL>" --workspace "${CMUX_WORKSPACE_ID:-}"`;
fallback `terminal-notifier` — see `references/cmux-execution.md`), then message the
user in pt-BR with a concise checkpoint summary of the dossier: issue id and
`issueType`, bug root cause when applicable, approved-plan summary, diff stats and
files touched, review findings found → fixed by round, verify command and final
exit status, CI status, assumptions, collateral issues, and what was NOT done. The
full durable dossier lives in the PR body.

End the checkpoint message with the **merge checklist** — the few things worth a
look before merging (per `references/flow-discipline.md`): assumptions to veto,
collateral issues filed, the High-attention items (migrations / new dependencies),
diff size versus the approved plan, and (for bugs) the regression test present.
Then give the **exact next command**, so the human does not have to remember it:

```
Após o merge, rode: /fix-linear-issue SAL-XX --finalize
```

The human performs the squash merge; the pipeline does not.

## Phase 9 — Finalize (post-merge re-invocation)

Only when invoked as `/fix-linear-issue SAL-XX --finalize`, after the human merge:

1. **Main-green check.** Resolve the merge commit
   (`rtk proxy gh pr view <pr-number> --json mergeCommit,state,mergedAt`) and check
   the CI on `main` for that commit
   (`rtk proxy gh run list --commit <sha> --branch main --json conclusion,status`).
   If the squash merge broke `main` (any job failing) or CI is still running, do
   NOT move the issue to Done: emit a terminal notification with the diagnosis and
   stop so the human decides. Only a green merge commit proceeds. This catches the
   surprise where the branch was green but the merged `main` is not.
2. On `main`: `git fetch origin main` and fast-forward the base.
3. `skeeper sync` on `main` — reconciles the sidecar and clears the audited
   bypass drift accumulated during the run.
4. Remove the worktree and delete the local branch (worktree removal only; never
   destructive git on tracked content without explicit permission).
5. Move the Linear issue to **Done**.

## Resume (`--resume`)

Only when invoked as `/fix-linear-issue SAL-XX --resume`, to continue an
interrupted run without redoing completed phases:

1. Read `<scratchpad>/fix-linear-issue-<ISSUE>/run-state.json`. If it is missing,
   there is nothing to resume — tell the user to run the pipeline normally and
   stop.
2. Re-run **Phase 0 pre-flight** (cmux, Docker for backend, `gh`, Linear,
   `git fetch origin main`, orchestrator effort). Resume proceeds only if
   pre-flight passes.
3. Verify the recorded `worktree` directory still exists and its checked-out
   branch matches `branch`. If the worktree or branch is gone, do not silently
   recreate it — report the mismatch and stop.
4. Check the recorded surfaces' liveness with
   `rtk proxy cmux surface-health --workspace "${CMUX_WORKSPACE_ID:-}" --json`. If
   `executorSurface` (or `reviewerSurface`, when the recorded phase needs it) is
   dead, respawn per the worker-death rules in `references/cmux-execution.md`
   (`spawn-worker.sh` + re-seed with the approved plan and current-state summary)
   and update the ref in `run-state.json`.
5. Continue from the recorded `phase` using the recorded `rounds` counters — **the
   counters never reset on resume**; a resumed loop keeps counting from where it
   stopped toward the same bound in `references/circuit-breakers.md`.

## Abort (`--abort`)

Only when invoked as `/fix-linear-issue SAL-XX --abort`, to cancel an in-flight
run and leave nothing dangling. Read `run-state.json` first; if it is missing,
there is nothing to abort — report that and stop. Then, in order:

1. Confirm intent with the human in pt-BR (one line: what will be torn down). Abort
   is destructive to run scaffolding, so require a clear go-ahead unless the run
   already hit a breaker.
2. Close both worker surfaces if present, scoped to the caller workspace:
   `rtk cmux close-surface --surface <executorSurface> --workspace "${CMUX_WORKSPACE_ID:-}"`
   and the same for `reviewerSurface`. Clear the sidebar run state
   (`set-status` / `set-progress`).
3. Remove the worktree and delete the local feature branch (worktree removal only;
   this is the single sanctioned cleanup — **never** `reset` / `checkout` / `clean`
   on other tracked content).
4. Restore Linear: move the issue back to `initialLinearState` (`save_issue` with
   the resolved `stateId`) and post a short comment (`run aborted: <reason>`). If a
   PR was already opened, do not merge or delete it; note its state in the comment
   and leave it for the human.
5. Mark `run-state.json` `phase: "aborted"` (keep the file as an audit trail), emit
   a terminal notification, and report what was torn down and what was left for the
   human (any open PR, any collateral issues already filed).
