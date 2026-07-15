---
name: salesmart-testing-patterns
description: Applies Salesmart-specific testing placement, integration criteria, factory conventions, verification commands, and integration-audit rules alongside testing-boss. Use when writing, moving, reviewing, or auditing Salesmart tests, fixtures, factories, conftests, integration timing, coverage evidence, or test verification artifacts. Do not use for generic testing doctrine, non-Salesmart repositories, or test code that does not need project-specific placement or factory rules.
---

# Salesmart Testing Patterns

Use this skill as the Salesmart-specific companion to `testing-boss`. Keep `testing-boss` responsible for generic testing doctrine. Use this skill only for project-local placement rules, named factory conventions, verification commands, and integration-test audit decisions.

## Required Reading Router

Match the task to the row. Read the listed files **in full before** producing output. These references are the contract for Salesmart-specific testing decisions; inline bullets below are tripwires only.

| Task | MUST read |
| --- | --- |
| Deciding whether a Salesmart test belongs in `tests/integration/` or should move to unit/presentation | `references/salesmart-layer-placement.md` |
| Creating or changing factories, fixtures, auth/session helpers, or conftests | `references/salesmart-fixtures-and-factories.md` |
| Choosing verification, coverage, timing, or smoke commands for test work | `references/salesmart-verification.md` |
| Auditing, refactoring, merging, moving, or deleting Salesmart integration tests | `references/salesmart-integration-audit.md` |

## Reference Index

- `references/salesmart-layer-placement.md` — Salesmart's four allowed integration-test conditions, unit exclusions, endpoint exception pattern, and migration placement rule.
- `references/salesmart-fixtures-and-factories.md` — Async SQLAlchemy factory signature, feature/common promotion rules, canonical global fixtures, and conftest duplication policy.
- `references/salesmart-verification.md` — Local gate commands, `make test-cov` caveat, integration timing command, smoke endpoints, and E2E command status.
- `references/salesmart-integration-audit.md` — Self-contained audit decision vocabulary, classification workflow, evidence rules, and temporary audit-table format.

## Operating Rules

1. Load `testing-boss` for generic test quality, then load the Salesmart reference that matches the local decision. Do not restate or override generic doctrine here.
2. Prefer the existing canonical Salesmart suite, helper, and factory path before creating new test structure.
3. Treat this skill bundle as the source of truth for Salesmart-specific test patterns. Use current repository files only to confirm code paths and existing helper names before editing.
4. Keep integration tests narrow: they must prove real Salesmart cross-layer or real resource behavior, not logic that unit tests can prove.
5. Keep local policy strict on flaky-test discipline; failures in `make test-cov` are investigation signals, not tolerated flakes.

Gist tripwires:

- Integration means real cross-layer behavior with Postgres, Redis, migrations, or mapper/schema agreement.
- Factories flush and return models; they do not commit.
- Shared helpers move to `tests/utils/common/` only after two or more real feature consumers exist.

**STOP. Read `references/salesmart-layer-placement.md` in full before placing, moving, merging, or deleting a Salesmart test.** The bullets above are tripwires, not the placement contract.

**STOP. Read `references/salesmart-fixtures-and-factories.md` in full before adding or changing factories, fixtures, or conftests.** That file contains the named local paths and promotion rules.

**STOP. Read `references/salesmart-verification.md` in full before selecting verification, coverage, timing, or smoke commands.** Salesmart has local command caveats that are not generic testing doctrine.

**STOP. Read `references/salesmart-integration-audit.md` in full before auditing, moving, merging, or deleting Salesmart integration tests.** That file contains the local decision vocabulary, classification workflow, and evidence rules.

## Error Handling

- If flaky-test handling is unclear, follow `testing-boss` and keep this skill's rule stricter: investigate failures instead of tolerating them.
- If a helper appears reusable but has fewer than two real feature consumers, keep it feature-local until the second consumer exists.
