#!/usr/bin/env bash
# classify-diff.sh — READ-ONLY helper.
# Detects the project profile from repo-root markers and classifies the branch
# diff to decide the local verify command and any artifact-regeneration command.
# The pipeline consumes the emitted variables, so it stays stack-agnostic.
#
# Usage:   classify-diff.sh [base_ref]     (base_ref default: origin/main)
# Output:  KEY=VALUE lines on stdout:
#            PROJECT_PROFILE=backend-python|frontend-node
#            VERIFY_CMD=<local gate command to run>
#            REGEN_CMD=<artifact regeneration command, or empty>
# Exit:    0 on success; 2 if base ref missing; 3 if the profile is unknown.
#
# This helper only reads git and filesystem state; it never mutates anything.
set -euo pipefail

base_ref="${1:-origin/main}"

if ! git rev-parse --verify --quiet "${base_ref}" >/dev/null; then
  echo "classify-diff: base ref '${base_ref}' not found" >&2
  exit 2
fi

repo_root="$(git rev-parse --show-toplevel)"
if [ -f "${repo_root}/pyproject.toml" ] && [ -f "${repo_root}/Makefile" ]; then
  profile="backend-python"
elif [ -f "${repo_root}/package.json" ] && [ -f "${repo_root}/pnpm-lock.yaml" ]; then
  profile="frontend-node"
else
  echo "classify-diff: unknown project profile (need pyproject.toml+Makefile or package.json+pnpm-lock.yaml)" >&2
  exit 3
fi

merge_base="$(git merge-base "${base_ref}" HEAD)"
changed="$(git diff --name-only "${merge_base}" HEAD)"

verify_cmd=""
regen_cmd=""

if [ "${profile}" = "backend-python" ]; then
  verify_cmd="make verify-fast"
  while IFS= read -r f; do
    [ -z "${f}" ] && continue
    case "${f}" in
      src/infra/database/migrations/*|\
      src/infra/database/models.py|\
      src/infra/database/models/*|\
      alembic.ini|\
      tests/integration/infra/migrations/*|\
      tests/utils/integration/migration_database.py)
        verify_cmd="make verify-full" ;;
    esac
    case "${f}" in
      src/presentation/api/*) regen_cmd="make export-openapi" ;;
    esac
  done <<< "${changed}"
else
  verify_cmd="pnpm check"
  while IFS= read -r f; do
    [ -z "${f}" ] && continue
    case "${f}" in
      src/lib/api/generated/*) regen_cmd="pnpm api:gen" ;;
    esac
  done <<< "${changed}"
fi

echo "PROJECT_PROFILE=${profile}"
echo "VERIFY_CMD=${verify_cmd}"
echo "REGEN_CMD=${regen_cmd}"
