# Salesmart Test Verification

## Contents

- [Project Gates](#project-gates)
- [Coverage Caveat](#coverage-caveat)
- [Integration Timing](#integration-timing)
- [Smoke Surface](#smoke-surface)
- [E2E Status](#e2e-status)

## Project Gates

Use these Salesmart gates:

- `make verify` is the required fast gate for code-affecting work. It runs lint and unit tests.
- `make verify-full` is the broader pre-push or pre-PR gate. It runs lint, unit tests, and integration tests.
- `make test-integration` is the focused integration layer command when a change touches repositories, mappers, endpoints, Celery tasks, migrations, or database behavior.

Do not replace these gates with ad hoc pytest subsets when claiming broad completion.

## Coverage Caveat

`make test-cov` is not equivalent to `make verify-full`.

`make test-cov` runs `pytest tests/` in one session. That can expose cross-test pollution from global event handlers, autouse fixtures, or monkeypatches that survive teardown. If it fails through teardown pollution, treat the failure as a suite investigation signal.

`make verify-full` separates unit and integration invocations and remains the complete verification gate.

## Integration Timing

Use this command to capture natural integration-suite timing without coverage noise:

```bash
pytest tests/integration/ -p no:cacheprovider --durations=20 --no-cov -q
```

The explicit `--no-cov` is required because `pyproject.toml` injects coverage through global pytest addopts.

## Smoke Surface

The available Salesmart smoke endpoints are:

- `/`
- `/api/v1/health`
- `/api/v1/health/detailed`
- `/api/v1/ready`
- `/openapi.json`

## E2E Status

The repository has `tests/e2e`, but no canonical Makefile E2E target. Treat `pytest tests/e2e -v --tb=short` as a narrow available subset unless the repository adds an official target.
