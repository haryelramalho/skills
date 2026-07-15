# Salesmart Integration Audit

## Contents

- [Scope](#scope)
- [Audit Goal](#audit-goal)
- [Classification Workflow](#classification-workflow)
- [Decision Vocabulary](#decision-vocabulary)
- [Destination Rules](#destination-rules)
- [Evidence Rules](#evidence-rules)
- [Temporary Audit Table](#temporary-audit-table)

## Scope

Use this reference for Salesmart integration-test audits, refactors, moves, merges, and deletions. It is self-contained project guidance.

## Audit Goal

Keep `tests/integration/` focused on behavior that requires real cross-layer execution or real resource behavior. Move logic-only tests to the owning unit or presentation layer. Remove duplicated or trivial tests when a lower layer already protects the same invariant.

## Classification Workflow

For each candidate integration test:

1. Name the invariant in one sentence.
2. Identify the real boundary crossed by the test.
3. Keep the test in integration only if it satisfies one of these Salesmart conditions:
   - `HTTP -> UseCase -> Repository -> Database` with observable DB effect.
   - `Event -> Handler -> Repository -> Database` with observable persistence, idempotency, dispatch, or Redis-backed invalidation.
   - `Adapter -> Postgres/Redis` where correctness depends on real resource behavior.
   - `Migration -> schema -> mapper round-trip` proving Alembic, SQLAlchemy, mapper, and database agreement.
4. If the behavior can be proved without a container, move it to the mirrored unit or presentation suite.
5. If another lower-layer test already proves the same invariant, remove the duplicate integration test.
6. If multiple integration tests prove the same wiring, merge them into the clearest scenario test.

## Decision Vocabulary

Use this vocabulary consistently:

| Decision | Meaning |
| --- | --- |
| `keep` | Test satisfies one integration condition and remains in integration. |
| `move` | Test fails integration criteria and moves to the owning unit/presentation layer. |
| `merge` | Test proves the same wiring as another integration test and should consolidate there. |
| `remove-duplicate` | Same invariant is already covered by the destination suite. |
| `remove-trivial` | Test has no meaningful cross-layer value. |

## Destination Rules

Use these destinations for moved tests:

- Domain rules go to `tests/unit/domain/`.
- Pure application calculations go to `tests/unit/application/`.
- Endpoint exception translation goes to `tests/unit/presentation/api/v1/endpoints/` with a fake use case.
- Pydantic schema validation goes to `tests/unit/presentation/api/v1/schemas/`.
- Repository, mapper, migration, Redis TTL, transaction, and unique-index behavior stays in integration when it needs the real database or Redis.

## Evidence Rules

Before finalizing an audit decision:

- State the invariant and destination.
- State which integration condition was satisfied or why none applies.
- Name the lower-layer suite that will own moved behavior.
- For removals, name the existing test that already covers the invariant.
- For merges, name the surviving integration test.

## Temporary Audit Table

Use this table as scratch evidence while auditing. Do not persist it in release artifacts unless the user explicitly asks for an audit report.

| Test | Decision | Destination | Target Layer | Justification |
| --- | --- | --- | --- | --- |
| `path::ClassName::test_name` | `keep` | `-` | `integration` | Condition 1-4. |
| `path::ClassName::test_name` | `move` | `dest_file::dest_test` | `unit/layer` | Fails integration criteria. |
| `path::ClassName::test_name` | `merge` | `dest_file::dest_test` | `integration` | Same wiring, consolidate. |
| `path::ClassName::test_name` | `remove-duplicate` | `dest_file::dest_test` | `unit/layer` | Already covered. |
| `path::ClassName::test_name` | `remove-trivial` | `-` | `-` | No cross-layer value. |
