# Salesmart Layer Placement

## Contents

- [Scope](#scope)
- [Integration-Test Admission Rule](#integration-test-admission-rule)
- [Unit or Presentation Ownership](#unit-or-presentation-ownership)
- [Named Local Patterns](#named-local-patterns)
- [Deletion and Merge Decisions](#deletion-and-merge-decisions)

## Scope

Use this reference only for Salesmart-specific layer placement. Use `testing-boss` for generic invariant, risk, mock, and flaky-test doctrine.

## Integration-Test Admission Rule

A test belongs in `tests/integration/` only when it exercises real cross-layer behavior that cannot be proved without a container or real resource. It must satisfy at least one Salesmart condition:

1. `HTTP -> UseCase -> Repository -> Database` with observable DB effect such as rollback, commit, soft delete visible through a later SELECT, relational constraint, sequence, or unique index.
2. `Event -> Handler -> Repository -> Database` with observable effect such as idempotency, real dispatch, or Redis-backed cache invalidation.
3. `Adapter -> real external resource` where correctness depends on Postgres or Redis behavior such as TTL, pipeline, transaction, execution plan, or applied migration.
4. `Migration -> schema -> mapper round-trip` proving Alembic, SQLAlchemy, mapper behavior, and database schema agree.

If none of these conditions applies, the test does not belong in `tests/integration/`.

## Unit or Presentation Ownership

Move behavior to the mirrored unit layer when it can be proved equivalently without a container:

- Pydantic schema validation.
- Domain entity, value object, specification, or pure domain service rules.
- Pure application calculations.
- Path/query parsing.
- Isolated RBAC rules.
- Projection field selection that does not need database behavior.
- Endpoint `try/except` translation when a fake use case can raise the application/domain exception directly.

## Named Local Patterns

`router try/except -> unit test with fake use case` is the established endpoint pattern. When an integration test only kept coverage for `except (...): raise to_http_exception(...)`, move the behavior to `tests/unit/presentation/api/v1/endpoints/` and use a fake use case that raises the target exception.

Migration upgrade/downgrade tests are allowed to stay expensive when they prove condition 4. Do not optimize them away merely because each setup costs one to three seconds.

## Deletion and Merge Decisions

Use these decisions when auditing existing tests:

| Decision | Meaning |
| --- | --- |
| `keep` | Test satisfies one integration condition and remains in integration. |
| `move` | Test fails integration criteria and moves to the owning unit/presentation layer. |
| `merge` | Test proves the same wiring as another integration test and should consolidate there. |
| `remove-duplicate` | Same invariant is already covered by the destination suite. |
| `remove-trivial` | Test has no meaningful cross-layer value. |
