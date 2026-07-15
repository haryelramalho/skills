# Flow discipline

Load this file before classifying the issue, writing the Phase 1 spec, handling
a collateral finding, recording an assumption, checking test delta or scope
drift, committing, opening the PR, or assembling the Phase 8 checkpoint dossier.
It adds flow-level discipline to the pipeline without weakening the existing
clarification gate, plan gate, verify gate, review gates, CI watch, or human
merge checkpoint.

## Contents

- Issue-type classification
- Bug path (reproduce first)
- Collateral findings policy
- Assumptions ledger
- Scope-drift re-entry
- Test-delta tripwire
- Checkpoint dossier

## Issue-type classification

Classify every issue in Phase 1 before writing the lean spec. Use exactly one of:

| Type | Use when |
| --- | --- |
| `bug` | The issue describes broken, regressed, incorrect, missing, or unexpected behavior in an existing path. |
| `feature` | The issue asks for new user-visible behavior, a new workflow, a new integration, or changed acceptance criteria. |
| `tech-debt` | The issue asks for internal cleanup, migration, refactor, dependency work, or behavior-neutral structure. |

Use Linear labels and the body together. The workspace uses the single team
`SAL` and leaf-name labels, so area labels such as `frontend` or `backend` are
not issue-type labels by themselves. Treat explicit labels such as `bug`,
`feature`, or `tech-debt` as strong signals; otherwise infer from the body and
comments.

Record the result immediately:

- Write `issueType` to `run-state.json`.
- Include `issueType` in the lean spec.
- Include `issueType` in the PR body and Phase 8 checkpoint dossier.
- In `--dry-run`, report the classification with the spec path.

When classification is ambiguous but the implementation path is not materially
different, choose the safest type and record the reason as an assumption. When
classification changes the required behavior and the issue does not settle it,
the clarification gate blocks.

## Bug path (reproduce first)

For `issueType=bug`, the pipeline must prove the bug before fixing it. Proof comes
in two stages, in two places:

- **Phase 1 — static evidence.** Before any worktree exists, establish
  reproduction by reading the code on the freshly-fetched `origin/main` and
  pointing to the exact path/condition that produces the reported behavior. Do not
  run tests, servers, or mutating commands outside a worktree — that breaks the
  isolation guardrails. Static evidence is enough to justify the not-reproducible
  early exit below.
- **Phase 3 — executable proof.** The failing regression test is written and run
  by the executor inside the isolated worktree, never in Phase 1.

The lean spec must require this order for Phase 3:

1. Write a regression test that describes the reported bug.
2. Run that test before implementation.
3. Confirm it fails for the reason the issue describes.
4. Implement the root-cause fix.
5. Confirm the regression test passes inside the classified `$VERIFY_CMD` gate.

Phase 3b enforces the order. Reject a bug plan that lacks the failing-test-first
step. Count the rejection as a plan-gate correction round. Do not approve a plan
that starts by editing production code, changing expectations, or broadening the
issue before the failing regression test exists.

The bug spec must also require a root-cause statement in this form:

```
The bug was <specific broken behavior> because <specific root cause>.
```

Symptom patches are not fixes. Treat a bug plan or review result that cannot
state root cause as a finding and route it back to the executor.

If Phase 1 exploration concludes the bug does not reproduce or is already fixed
on `origin/main`, stop before Phase 2:

1. Preserve the evidence: commands run, observed behavior, commit/base checked,
   and why it does not reproduce.
2. Post the evidence as a Linear comment.
3. Leave the Linear issue state unchanged.
4. Notify the human in pt-BR.
5. End the run without creating a worktree or implementing anything.

Never implement speculative cleanup for a non-reproducible bug.

## Collateral findings policy

Default: never fix out of scope. One PR maps to one Linear issue.

Collateral findings can surface during exploration, implementation, verify,
review, thermo, or CI. A finding is collateral when it is real but not required
to satisfy the current issue.

Handle every collateral finding as follows:

1. Do not fix it in the current PR.
2. Create a new Linear issue with `mcp__linear__save_issue`.
3. Use team `SAL`.
4. Apply leaf-name labels by area, for example `frontend` or `backend`.
5. Reference the current issue in the body and explain how the finding surfaced.
6. Record the created issue id in `run-state.json` under `collateralIssues`.
7. List the ids in the PR body as
   `Out-of-scope findings filed: SAL-XX, SAL-YY`; write `none` when empty.

The single exception: a collateral bug blocks the current fix because the
classified verify gate cannot pass without touching it. In that case:

- Fix the blocker minimally.
- Keep the diff limited to what unblocks the current issue.
- Still create a Linear issue if follow-up work remains.
- Document the PR body line:
  `Blocking collateral fix: <what changed> because <why the current gate could not pass without it>.`

When unsure whether a finding is required by the current issue, compare it to the
approved plan and acceptance criteria. If it is not required, file it instead of
fixing it. If it changes the current approach materially, use scope-drift
re-entry before more implementation.

## Assumptions ledger

The clarification gate stops for genuine product decisions. Everything below
that bar is an assumption: defaults picked, project patterns followed, label/body
interpretations, and self-answered questions from the clarification gate's
"Do NOT stop" list.

Record each assumption at the moment it is made:

- Append a short string to `run-state.json` under `assumptions`.
- Add it to the lean spec.
- Preserve the full list in the PR body under `## Assumptions`.
- Include the list in the Phase 6 Linear comment.

Write assumptions as plain, reviewable statements:

| Good | Bad |
| --- | --- |
| `Assumed the existing analytics table filter pattern is the project default for this route.` | `Used normal pattern.` |
| `Assumed label frontend means the affected area, not the issue type.` | `Frontend bug maybe.` |
| `Assumed no copy change is required because the issue acceptance criteria only mention sorting behavior.` | `No copy.` |

Under `--yolo`, the assumptions ledger is mandatory and is the primary
accountability mechanism. Every question the pipeline answers for itself must
appear there. Empty assumptions under `--yolo` are only valid when the issue and
code leave no material interpretation choices; state that explicitly in the
spec.

## Scope-drift re-entry

The approved Phase 3b plan is the implementation contract. Re-enter the plan gate
when Phase 3c, Phase 4, or Phase 5 reveals material drift:

- Different mechanism from the approved plan.
- Different production files or layers from the approved plan.
- Broader scope than the issue or acceptance criteria.
- A new dependency, data flow, migration, API contract, or generated artifact not
  covered by the plan.
- A collateral finding that appears necessary to touch.

On drift:

1. Halt implementation before more edits.
2. Ask the executor for a revised plan that names the changed mechanism and
   changed files.
3. Review the revised plan at `xhigh`.
4. Approve or correct through Phase 3b.
5. Record the drift re-entry count in `rounds.driftReentry` in `run-state.json`.

The drift re-entry bound is 2 per run. After the second re-entry, the plan-gate
breaker fires: preserve state, notify, and escalate.

Before every commit, the orchestrator checks diff versus plan:

- Allowed: files named in the approved plan.
- Allowed: test files needed for the issue's coverage.
- Allowed: classified `REGEN_CMD` outputs.
- Not allowed: any out-of-plan production, config, script, generated, or docs
  file unless a revised plan has been approved.

If the diff contains an out-of-plan file, do not commit. Treat it as drift and
re-enter the plan gate, or treat it as a collateral finding and file a Linear
issue, whichever matches the reason the file changed.

## Test-delta tripwire

After Phase 4 passes, inspect the branch diff for test changes before Phase 5a
is accepted as clean.

Apply the rule by issue type:

| Type | Required test delta |
| --- | --- |
| `bug` | A new or changed regression test that failed before the fix for the reported reason. |
| `feature` | A new or changed test that covers the acceptance criteria. |
| `tech-debt` | Test delta required unless the diff is provably behavior-neutral, such as a pure rename or move. |

If the rule fails, create an automatic high-severity Phase 5a finding and route
it to the executor like any other review finding. The reviewer prompt must state
this rule so the cross-model reviewer checks it independently.

The classified `$VERIFY_CMD` proves the suite still passes. The test-delta
tripwire proves the new or fixed behavior is covered. Do not use the green gate
as a substitute for this check.

For a `tech-debt` exemption, write the justification in the PR body:

```
Test-delta exemption: behavior-neutral <rename/move/refactor>; no runtime behavior changed.
```

## Checkpoint dossier

The PR body is the durable dossier. Keep the `create-pr-with-template` flow; fill
the template with these sections instead of replacing it. The Phase 8 pt-BR
message summarizes the same dossier, while the terminal notification remains
short and includes the PR URL.

The dossier must include:

- Issue id and `issueType`.
- For bugs, the root-cause statement.
- The approved plan or a faithful summary of it.
- Diff stats and the list of files touched.
- **High attention** — the highest-blast-radius changes, called out so they are
  never buried in the file list: schema migrations, dependency/lockfile changes
  (`package.json` / `pnpm-lock.yaml`, `pyproject.toml` / `uv.lock`), and
  regenerated artifacts. Write `none` when there are none.
- **Large-diff warning** when the diff crosses the thresholds below.
- Review findings per round: found and fixed counts for Phase 5a and Phase 5b.
- Observed flakes (tests that passed only on a re-run), or `none`.
- Verify-gate evidence: exact `$VERIFY_CMD` and final exit status.
- CI status.
- `## Assumptions` with the full ledger.
- Out-of-scope findings filed, or `none`.
- What was NOT done: explicit non-goals and deferred items.

Build the dossier from recorded state, git, and gate outputs:

| Evidence | Source |
| --- | --- |
| Issue id, type, assumptions, collateral issues, flakes | `run-state.json` |
| Approved plan | Phase 3b approval record / lean spec |
| Diff stats | `git diff --stat origin/main...HEAD` |
| Files touched | `git diff --name-only origin/main...HEAD` |
| High attention | files touched, filtered to migration / lockfile / generated paths |
| Review counts | Phase 5a / 5b review loop notes |
| Verify evidence | Final `$VERIFY_CMD` invocation and exit status |
| CI status | `gh pr checks` / GitHub Actions watch result |

### Large-diff guard

A large diff cannot be reviewed in the two-minute glance the checkpoint assumes.
When the branch diff crosses **400 changed lines OR 15 files**, the dossier and the
Phase 8 message must OPEN with a highlighted large-diff warning plus a one-line
per-file summary, so the human knows this PR needs a real review, not a rubber
stamp. This does not block — it only makes the size impossible to miss.

### Merge checklist

The Phase 8 pt-BR message ends with a short merge checklist — the few things worth
a look before merging:

- Assumptions to veto (from the ledger).
- Collateral issues filed.
- High-attention items (migrations, new dependencies).
- Diff size versus the approved plan (flag the large-diff warning if set).
- For bugs, the regression test is present and was failing first.

Then give the exact next command so the human does not have to remember it:
`/fix-linear-issue SAL-XX --finalize`.

For Phase 8, send a short terminal notification in pt-BR with the PR URL. Then
message the human in pt-BR with the checkpoint summary (issue type, root cause for
bugs, verify/CI status, assumptions, collateral issues, high attention, flakes, and
what was not done) followed by the merge checklist and the finalize command. Do not
merge.
