# Project profiles

Load this file to adapt the pipeline to the repo it runs in. The flow is ONE
skill; only the verify gate, diff classification, artifact regeneration, and test
isolation differ per project. The `scripts/classify-diff.sh` helper detects the
profile from repo markers and emits the concrete commands, so the pipeline stays
project-agnostic — it runs the emitted commands verbatim and never hardcodes a
stack-specific one.

## Contents

- Detection
- Profile table
- Emitted variables
- Adding a new project

## Detection

`classify-diff.sh` selects the profile from repo-root markers (the skill supports
exactly these two today):

| Markers | Profile |
| --- | --- |
| `pyproject.toml` + `Makefile` | `backend-python` (salesmart) |
| `package.json` + `pnpm-lock.yaml` | `frontend-node` (salesmart-web) |

If neither matches, the helper exits non-zero. Stop and escalate rather than
guessing a gate for an unknown stack.

## Profile table

| Aspect | backend-python (salesmart) | frontend-node (salesmart-web) |
| --- | --- | --- |
| Executor (cmux worker TUI, `medium`) | Codex gpt-5.5 | Claude Opus |
| Verify gate | `make verify-fast` or `make verify-full` (by diff) | `pnpm check` (lint + typecheck + test + build) |
| Diff → full gate | migration/model paths | n/a (single gate) |
| Artifact regen | `make export-openapi` if diff touches `src/presentation/api/` | `pnpm api:gen` if diff touches `src/lib/api/generated/` |
| Test isolation | testcontainers (ephemeral Postgres/Redis) | vitest in-process; Playwright for E2E |
| Cross-model reviewer worker (Phase 5a, xhigh) | Claude Opus (opposite the executor) | Codex gpt-5.5 (opposite the executor) |
| Skeeper namespace | `salesmart` | `salesmart-web` |
| `rtk`-wrapped output | yes (`make`) | no (`pnpm`) |

## Emitted variables

`classify-diff.sh` prints, and the pipeline consumes:

- `PROJECT_PROFILE` — `backend-python` | `frontend-node`.
- `VERIFY_CMD` — the exact local gate to run (e.g. `make verify-full`, `pnpm check`).
- `REGEN_CMD` — artifact regeneration command, or empty. If non-empty, run it and
  commit the regenerated files before the gate.

## Adding a new project

Extend `classify-diff.sh` with a new marker branch that sets `PROJECT_PROFILE`,
`VERIFY_CMD`, and `REGEN_CMD`, then add a row to the profile table above with its
cmux executor worker and its cross-model reviewer worker (opposite model, launched
at `xhigh`). The literal launch commands and effort flags live only in
`references/model-routing.md` (mirrored by `scripts/spawn-worker.sh`); add the new
project there and to `spawn-worker.sh` together.
