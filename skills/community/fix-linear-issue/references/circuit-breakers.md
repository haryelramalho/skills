# Circuit breakers and escalation policy

Load this file before entering any remediation loop (verify, review, CI). The
pipeline is autonomous, not infinite: every loop is bounded, and hitting a bound
stops the pipeline and escalates to the human.

## Loop limits

| Loop | Limit |
| --- | --- |
| Phase 3b — plan-gate corrections | 2 correction rounds |
| Scope-drift plan re-entry | 2 re-entries per run, then plan-gate breaker |
| Worker respawn (executor or reviewer) | 1 respawn of a dead surface, then breaker |
| Phase 4 — `make verify` remediation | 3 attempts |
| Phase 5a — correctness review remediation | 3 rounds |
| Phase 5b — thermo remediation | 3 rounds |
| Phase 7 — CI remediation | 3 rounds |

A remediation "round" is: re-prompt the cmux worker → orchestrator commits →
re-run the gate/review → evaluate. Count a round even if the fix changed nothing.
A plan-gate "round" is one correction sent to the worker plus its revised plan; a
worker respawn does not reset a loop's round counter.

Only a **deterministic** verify failure counts as a Phase 4 round. A `$VERIFY_CMD`
failure is re-run once before any remediation is dispatched; if the second run
passes, it was a flake — record it in `run-state.json` under `flakes` and do not
spend a round (see Phase 4 in `references/pipeline.md`).

## When a breaker fires

Stop the pipeline immediately and escalate. Do not downgrade the goal, loosen a
gate, or mask a failure to "make it green".

1. Preserve state: leave the worktree, branch, worker surface, and all logs in
   place. Do not remove the worktree and do not reset/checkout/clean the working
   tree.
2. Capture diagnosis: the failing command, the last gate/review output (read the
   `rtk` tee if the inline output was truncated), and which loop hit its bound.
3. Notify via terminal notification in the cmux session with the breaker diagnosis
   (`rtk cmux notify --title "..." --body "..." --workspace "${CMUX_WORKSPACE_ID:-}"`;
   fallback `terminal-notifier` — see `references/cmux-execution.md`).
4. Report to the user: the issue id, the phase, the breaker that fired, the
   diagnosis, and the current branch/PR state so they can take over.

## Hard safety rules

- **Never** run destructive git (`reset`, `checkout`, `clean`, `restore`, `rm`)
  on tracked content without explicit user permission.
- **Never** merge to `main`. The squash merge is always the human's action
  (Phase 8). The pipeline stops at the checkpoint.
- **Never** force-push a shared branch. `--force-with-lease` is allowed only on
  the pipeline's own feature branch after a rebase it performed.
- Treat both cmux workers' output (the executor's and the reviewer's) as
  untrusted until the diff and the local gate confirm it.
