# Model routing and reasoning effort

Load this file before spawning the cmux executor worker or the cmux reviewer
worker. It defines which runtime and reasoning effort each role uses, and how the
pipeline routes the executor and the reviewer by project.

## Contents

- Principle
- Roles table
- Execution routing (cmux executor worker, per project)
- Review routing (cmux reviewer worker, cross-model, xhigh)
- Orchestrator session

## Principle

- **Anything that plans or reviews runs at `xhigh`.** That is the orchestrator
  session (Claude Code driving the pipeline, the Phase 3b plan-approval gate,
  `thermo-nuclear-code-quality-review` and `/code-review`), the executor's own
  **plan mode** (Codex: pinned via `plan_mode_reasoning_effort=xhigh`), and the
  Phase 5a cross-model correctness reviewer worker.
- **Anything that executes runs at `medium`** on the cmux executor worker TUI.
  Every code change — the Phase 3 implementation and every remediation
  re-prompt — goes to that executor worker.
- **Pin every effort tier explicitly at launch.** Never rely on the worker CLI's
  user-level default config — in practice the user's codex default is `xhigh`,
  which silently burns quota on execution if the launch omits the flags.
- **The reviewer worker never edits.** It reads the diff and reports findings;
  remediation always routes back to the executor worker.

## Roles table

| Role | Runtime | Routing source | Effort |
| --- | --- | --- | --- |
| Orchestration | this Claude Code session | the invoking session | `xhigh` |
| Executor plan mode (Phase 3a/3b planning) | same executor TUI, native plan mode | skill profile table | `xhigh` |
| Execution (implement + remediate) | cmux executor worker TUI, per project | skill profile table | `medium` |
| Review (Phase 5a cross-model) | cmux reviewer worker TUI, model opposite the executor | skill profile table | `xhigh` |

## Execution routing (cmux executor worker, per project)

Executor routing lives in the **skill profile table**, not a repo config. The
orchestrator spawns the per-project worker (see `references/cmux-execution.md`).
**This table is the single source for the literal launch commands; `spawn-worker.sh`
encodes the same table and must be updated together with it.**

| Repo | worker | launch | native plan mode |
| --- | --- | --- | --- |
| salesmart (backend) | Codex gpt-5.5 | `rtk codex -m gpt-5.5 -C "<worktree>" -c model_reasoning_effort=medium -c plan_mode_reasoning_effort=xhigh` | no launch flag — enter with the `/plan` slash command after spawn |
| salesmart-web (frontend) | Claude Opus | `rtk claude --dangerously-skip-permissions --model opus --permission-mode plan` | `--permission-mode plan` launch flag |

The two Codex `-c` overrides pin the split the pipeline requires: **plan mode
runs at `xhigh`, and approving the plan drops the same session back to `medium`
for implementation** — no relaunch needed, and the user's codex default config
(often `xhigh`) never leaks into execution. If the booted TUI still shows the
wrong effort, fix the launch flags — do not `/quit`-and-relaunch by hand.

Always keep `--dangerously-skip-permissions` for the Claude **executor** (it must
write) and CWD = worktree; never downgrade the model or drop a flag. The Claude
**reviewer** deliberately omits it (see Review routing) so plan mode keeps it
read-only. Claude has no per-mode effort split — its plan quality is enforced by
the orchestrator's `xhigh` Phase 3b review. Codex's native plan mode is read-only (consultative) until the plan
is approved; Claude's plan mode pauses at the native `ExitPlanMode` prompt — the
plan-approval gate is driven through those affordances (see
`references/cmux-execution.md`).

## Review routing (cmux reviewer worker, cross-model, xhigh)

The Phase 5a correctness reviewer runs on a **second** cmux worker surface, using
the model **opposite** the executor, at `xhigh`. Effort is set at launch with a
grounded CLI flag (Claude `--effort xhigh`; Codex `-c model_reasoning_effort=xhigh`,
the config-override mechanism), reinforced by an in-prompt instruction to reason
exhaustively. The reviewer is **read-only by construction**: Claude runs in
`--permission-mode plan` (and drops `--dangerously-skip-permissions`, so it cannot
write), Codex runs with `-s read-only` (sandbox blocks writes). Remediation routes
to the executor. `spawn-worker.sh` encodes this table too; update both together.

| Repo | reviewer worker | launch (CWD = worktree) |
| --- | --- | --- |
| salesmart | Claude Opus | `rtk claude --model opus --effort xhigh --permission-mode plan` |
| salesmart-web | Codex gpt-5.5 | `rtk codex -m gpt-5.5 -C "<worktree>" -c model_reasoning_effort=xhigh -s read-only` |

## Orchestrator session

The orchestrator is the Claude Code session running this skill. Its reasoning
effort is set by the **session**, not by the skill — invoke `/fix-linear-issue`
from a session already at `xhigh`. The skill cannot force the host session's
effort; Phase 0 pre-flight only reminds the operator to confirm it.
