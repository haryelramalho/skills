# Skeeper handling, worktree isolation, and concurrency

Load this file before creating a worktree or running any commit/push in the
pipeline. It prevents the skeeper commit/push blocks and documents the isolation
that makes concurrent pipelines safe.

## Contents

- Why skeeper blocks
- Worktree setup sequence
- Commit and push rules
- Finalize reconciliation
- Isolation layers (concurrency)
- Concurrency guardrails

## Why skeeper blocks

`skeeper` mirrors spec-driven artifacts into a sidecar repo
(`salesmart-specs.git`) and installs git hooks:

- **pre-commit** blocks on managed-path drift. It accepts an **audited** bypass:
  `SKEEPER_SKIP=1` records `skeeper internal record-bypass` and lets the commit
  through — cleaner than blind `--no-verify` for commits.
- **pre-push** runs `skeeper internal pre-push` and has **no env bypass**. It
  validates the lock and fails a new branch with
  `namespaces[0].commit must be a full 40-character SHA`, because skeeper keeps
  **one sidecar branch per repo branch** (`salesmart/__branches__/<branch>`) and
  a brand-new branch has no sidecar commit yet.

Each worktree carries its own `skeeper.lock`, so per-worktree handling does not
collide across concurrent pipelines.

## Worktree setup sequence

1. Create the worktree from `origin/main` (freshly fetched) on branch
   `SAL-XX-<slug>` using `using-git-worktrees` (native worktree tool preferred;
   git fallback otherwise).
2. Copy the project's local env file(s) into the worktree (backend: `.env`;
   frontend: `.env` / `.env.local` if present). Backend tests use testcontainers
   (ephemeral Postgres/Redis), so no dedicated database is provisioned — Docker
   must be up for the backend profile. The frontend gate (`pnpm check`) needs no
   containers.
3. Repair skeeper for the new branch (bootstrap, local-only):
   `skeeper repair` — sanitizes the worktree `skeeper.lock` and prevents the
   40-char-SHA push error.
4. Set the audited bypass for the whole pipeline environment: in the
   orchestrator's own bash, `export SKEEPER_SKIP=1`; in a cmux worker surface
   (the user's login shell, often fish), prefix the launch instead —
   `env SKEEPER_SKIP=1 <launch>` — never `export`, which is bash-only.

**Env values never leave the worktree.** The copied `.env` / `.env.local` are for
running the gate only. Their values must never appear in the spec, a worker prompt,
the diff, the PR, or a Linear comment — reference config through env, not literals.
`scripts/scan-secrets.sh` enforces this at every push (Phase 6/7); a hit blocks the
push.

## Commit and push rules

One ownership rule: **the cmux executor worker implements; the orchestrator owns
commits.** Execution runs on the worker TUI and it edits the working tree only;
the reviewer worker never edits or commits.

- Commits: after each successful implementation or remediation, the orchestrator
  inspects the working-tree diff and commits it with `SKEEPER_SKIP=1 git commit ...`
  (audited bypass). This keeps skeeper handling and diff review in one place and
  produces a clean per-step diff to verify. `SKEEPER_SKIP=1` is also exported in the
  worker's shell so any incidental worker commit stays audited, but the canonical,
  verified commit is the orchestrator's.
- Push: always `git push --no-verify` (pre-push has no env bypass).
- Keep the lean `_spec.md` in the scratchpad, outside skeeper-tracked paths, to
  avoid generating drift in the first place.

## Finalize reconciliation

The audited bypasses accumulate drift that must be reconciled once, after the
human merge, in the `--finalize` run: `skeeper sync` on `main` pulls remote
specs, pushes local specs, and re-stages `skeeper.lock`. If `skeeper sync`
requires remote auth, surface it to the user rather than guessing credentials.

## Isolation layers (concurrency)

Multiple pipelines run in parallel today. Each layer isolates independently:

| Layer | Isolation |
| --- | --- |
| Git | branch + index per worktree |
| cmux surfaces | executor worker surface (+ Phase 5a reviewer worker surface) per pipeline/worktree, each addressed by explicit `surface:N` |
| Test isolation (backend) | testcontainers on **random ports** (`get_connection_url`, `get_exposed_port`); per-worktree basetemp/coverage via `TEST_RUN_NAMESPACE = <dir>-<hash>-<worker>-<pid>` |
| Test isolation (frontend) | vitest runs in-process (no shared ports); Playwright E2E is out of the `pnpm check` gate |
| Skeeper | `skeeper.lock` + sidecar branch per worktree/branch |

## Concurrency guardrails

- Keep concurrent pipelines to **2–3**. This is a saturation limit, not a
  collision one: each pipeline runs an executor plus the test suite (and, on the
  backend, Postgres+Redis containers); more than that degrades CPU/RAM/Docker.
- Run only the classified gate (`$VERIFY_CMD`). **Never** start a long-running dev
  server or mutate a shared database inside the pipeline — backend: no `make run`
  (uvicorn :8000) or `make migrate` against the `.env` Postgres; frontend: no
  `pnpm dev` (vite) or `pnpm test:e2e:live`. The gate stays collision-free.
