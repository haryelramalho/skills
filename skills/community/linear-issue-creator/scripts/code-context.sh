#!/usr/bin/env bash
# code-context.sh — Given a file path, output a markdown block with git context.
# Usage: code-context.sh <path> [<function-or-symbol>]
# Output: markdown to stdout. Errors to stderr (non-zero exit).
#
# When <function-or-symbol> is omitted, output a single-line reference:
#   - `path/to/file.ext` (branch `main`, commit `abc1234`, [view](https://...))
# When provided, also embed a code snippet (best-effort line range matching the symbol).

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: code-context.sh <path> [<function-or-symbol>]" >&2
  exit 1
fi

path="$1"
symbol="${2:-}"

if [[ ! -f "$path" ]]; then
  echo "ERROR: file not found: $path" >&2
  exit 2
fi

# Verify inside a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Not a git repo — minimal output
  printf -- '- `%s`\n' "$path"
  exit 0
fi

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
commit="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
remote_url="$(git config --get remote.origin.url 2>/dev/null || true)"

# Convert remote to https file URL (github + gitlab + bitbucket common patterns)
viewer_url=""
if [[ -n "$remote_url" ]]; then
  # SSH form: git@github.com:user/repo.git
  # HTTPS form: https://github.com/user/repo.git
  cleaned="$(echo "$remote_url" | sed -E 's#git@([^:]+):#https://\1/#; s#\.git$##')"
  case "$cleaned" in
    https://github.com/*)   viewer_url="$cleaned/blob/$commit/$path" ;;
    https://gitlab.com/*)   viewer_url="$cleaned/-/blob/$commit/$path" ;;
    https://bitbucket.org/*)viewer_url="$cleaned/src/$commit/$path" ;;
    *) viewer_url="" ;;
  esac
fi

# Reference line
if [[ -n "$viewer_url" ]]; then
  printf -- '- `%s` (branch `%s`, commit `%s`, [view](%s))\n' "$path" "$branch" "$commit" "$viewer_url"
else
  printf -- '- `%s` (branch `%s`, commit `%s`)\n' "$path" "$branch" "$commit"
fi

# Embed snippet if symbol requested
if [[ -n "$symbol" ]]; then
  # Find first line matching the symbol declaration heuristically
  start_line="$(grep -n -E "(function|def|const|let|var|class|fn|func|public|private)[[:space:]]+${symbol}[[:space:]\(<{=]" "$path" | head -n1 | cut -d: -f1 || true)"
  if [[ -z "$start_line" ]]; then
    # Fallback: any line containing the symbol
    start_line="$(grep -n -E "\b${symbol}\b" "$path" | head -n1 | cut -d: -f1 || true)"
  fi
  if [[ -n "$start_line" ]]; then
    end_line=$((start_line + 30))
    total="$(wc -l <"$path" | tr -d ' ')"
    if (( end_line > total )); then end_line=$total; fi
    ext="${path##*.}"
    printf '\n```%s\n' "$ext"
    sed -n "${start_line},${end_line}p" "$path"
    printf '```\n'
    printf '_(linhas %s-%s de `%s`)_\n' "$start_line" "$end_line" "$path"
  else
    echo "WARN: symbol '$symbol' not found in $path" >&2
  fi
fi
