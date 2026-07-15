# Clarification gate

Load this file before deciding whether to proceed past Phase 1. The pipeline is
autonomous, but it must not guess genuine product decisions. This gate runs AFTER
the repo exploration and BEFORE the worktree, so a stop is cheap — no executor
spend yet. It is ON by default; the `--yolo` flag skips it.

## Contents

- Principle
- Stop when
- Do NOT stop when
- How to ask

## Principle

Resolve first, ask last. Everything the CODE answers — architecture, placement,
conventions, types, existing patterns — is the agent's job to settle via the
Explore pass. Only a decision the code and the issue do NOT settle, and that only
the human owns, is a reason to stop. Stopping too often kills autonomy; stopping
too rarely ships the wrong thing.

## Stop when

Stop before the worktree and ask when a GENUINE product/scope/business decision
remains:

- Acceptance criteria are missing or self-contradictory.
- The issue admits two materially different interpretations that lead to
  different implementations.
- A business rule is required that is not in the code, the issue, or the linked
  context (a threshold, a rounding rule, an eligibility condition, etc.).
- The scope boundary is unclear (does this include X, or only Y?).
- The change is irreversible or high-blast-radius and the intended behavior is
  ambiguous.

## Do NOT stop when

Do not stop for anything the agent can settle itself:

- Where to place code, which layer, which existing pattern to follow.
- Naming, types, refactors internal to the change.
- Anything already answered by the issue body, its comments, or the code.
- A preference with an obvious project default — pick it and record it in the spec.
- Every self-answered question from this list is recorded in the assumptions
  ledger (→ `references/flow-discipline.md`).

## How to ask

- Notify first: whenever the gate stops for a question, emit a terminal
  notification in the cmux session (→ `references/cmux-execution.md`) before
  asking, so an unattended run does not sit silent.
- Interactive session: ask the human directly with specific, numbered questions
  and a recommended answer for each.
- Unattended run: post the questions as a Linear comment on the issue, keep the
  issue in its current state (do NOT move it to In Progress), and stop/escalate.
- **No answer is not permission to guess.** If the interactive prompt returns
  without an answer — a timeout, a `No response after Ns — continued` message, a
  dismissed dialog, or any empty result — treat the question as UNANSWERED. Do NOT
  continue into the worktree. Fall back to the unattended path: post the questions
  as a Linear comment, leave the issue in its current state, and STOP/escalate. The
  gate blocks until a human answer arrives; a non-answer keeps it blocked.
- Never proceed on a guessed product decision. Resume only after answers, and fold
  them into the spec.
