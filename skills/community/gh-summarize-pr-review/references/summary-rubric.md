# Summary Rubric

Use this rubric to keep the final report decision-oriented and consistent.

## Point Structure

For every point, include these fields in order:
1. `Point`: short title of the concern
2. `Interpretation`: what the reviewer is asking to change
3. `Evidence`: quote plus snippet/image/link reference
4. `Decision impact`: why the point matters now
5. `Suggested action`: minimal next action or question

## Interpretation Rules

- Preserve reviewer intent; do not soften or exaggerate.
- Prefer concrete language over generic quality statements.
- Separate fact from inference:
  - Fact: directly present in quote/snippet/link.
  - Inference: your interpretation of implied risk or behavior.

## Decision Framing

When presenting decision impact, classify each point as:
- `Blocker`: merge should wait for fix/clarification.
- `Important`: should be addressed in this PR unless explicitly deferred.
- `Optional`: can be deferred with rationale.

The script classifies automatically using deterministic keyword rules; review and adjust manually when context indicates a different priority.

If confidence is low, say what evidence is missing and what to verify.
