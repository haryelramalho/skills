#!/usr/bin/env bash
# scan-secrets.sh — READ-ONLY helper.
# Scans the branch diff for secrets before a push: literal values from the
# worktree env files (.env / .env.local) and a few classic credential patterns.
# It never mutates anything; it only reads git and filesystem state.
#
# Usage:   scan-secrets.sh <worktree-abs-path> [base_ref]   (base_ref default: origin/main)
# Output:  nothing on a clean scan; on a hit, one "<file>:<line>: <reason> <masked>"
#          per finding on stdout.
# Exit:    0 clean; 1 a secret was found; 2 base ref missing; 64 usage error.
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: scan-secrets.sh <worktree-abs-path> [base_ref]" >&2
  exit 64
fi

worktree="$1"
base_ref="${2:-origin/main}"

if [ ! -d "${worktree}" ]; then
  echo "scan-secrets: worktree path '${worktree}' is not a directory" >&2
  exit 64
fi

cd "${worktree}"

if ! git rev-parse --verify --quiet "${base_ref}" >/dev/null; then
  echo "scan-secrets: base ref '${base_ref}' not found" >&2
  exit 2
fi

merge_base="$(git merge-base "${base_ref}" HEAD)"

secrets_file="$(mktemp)"
trap 'rm -f "${secrets_file}"' EXIT

for env_file in .env .env.local; do
  [ -f "${env_file}" ] || continue
  while IFS= read -r line || [ -n "${line}" ]; do
    case "${line}" in
      ''|\#*) continue ;;
    esac
    key="${line%%=*}"
    value="${line#*=}"
    [ "${key}" = "${line}" ] && continue
    value="${value%\"}"; value="${value#\"}"
    value="${value%\'}"; value="${value#\'}"
    [ "${#value}" -lt 8 ] && continue
    case "${value}" in
      changeme|change_me|placeholder|example|localhost*|http://localhost*|https://localhost*|true|false|null|undefined) continue ;;
      *[!0-9]*) : ;;
      *) continue ;;
    esac
    printf '%s\n' "${value}" >> "${secrets_file}"
  done < "${env_file}"
done

found=0
current_file=""
current_line=0

emit() {
  found=1
  printf '%s\n' "$1"
}

added="$(git diff --unified=0 "${merge_base}" HEAD || true)"

while IFS= read -r dline; do
  case "${dline}" in
    '+++ b/'*)
      current_file="${dline#+++ b/}" ;;
    '@@ '*)
      hunk="${dline#*+}"
      hunk="${hunk%% *}"
      current_line="${hunk%%,*}" ;;
    '+'*)
      content="${dline#+}"
      if [ -s "${secrets_file}" ]; then
        while IFS= read -r secret; do
          [ -z "${secret}" ] && continue
          case "${content}" in
            *"${secret}"*)
              masked="${secret:0:2}***${secret: -2}"
              emit "${current_file}:${current_line}: env value ${masked}" ;;
          esac
        done < "${secrets_file}"
      fi
      case "${content}" in
        *"BEGIN "*"PRIVATE KEY"*) emit "${current_file}:${current_line}: private key block" ;;
        *AKIA[A-Z0-9][A-Z0-9]*) emit "${current_file}:${current_line}: aws access key id" ;;
        *ghp_[A-Za-z0-9]*) emit "${current_file}:${current_line}: github token" ;;
        *sk-[A-Za-z0-9]*) emit "${current_file}:${current_line}: api secret key" ;;
      esac
      current_line=$((current_line + 1)) ;;
  esac
done <<< "${added}"

if [ "${found}" -ne 0 ]; then
  exit 1
fi
exit 0
