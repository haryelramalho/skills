#!/usr/bin/env bash
# save-fallback.sh — Cleanup old drafts, save new draft, copy to clipboard, print deeplink.
# Usage: echo "<markdown body>" | save-fallback.sh <workspace-slug> <team-key> <title>
#
# Effects:
#   - Removes drafts older than 30 days from ~/.local/share/linear-issue-creator/drafts/
#   - Saves the stdin content to ~/.local/share/linear-issue-creator/drafts/YYYY-MM-DD-HHMMSS-XXXX-<slug>.md
#   - Copies the body (without metadata header) to the system clipboard (pbcopy / xclip / wl-copy)
#   - Prints the saved file path, clipboard status, and the Linear "new issue" deeplink

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: echo <body> | save-fallback.sh <workspace-slug> <team-key> <title>" >&2
  exit 1
fi

workspace_slug="$1"
team_key="$2"
title="$3"

drafts_dir="${HOME}/.local/share/linear-issue-creator/drafts"
mkdir -p "$drafts_dir"

# 1. Capture stdin BEFORE any other I/O — avoids head/tail portability issues
body="$(cat)"

# 2. Cleanup drafts older than 30 days (best-effort; ignored if dir is fresh)
find "$drafts_dir" -type f -name '*.md' -mtime +30 -delete 2>/dev/null || true

# 3. Slugify title (NFD-normalize accents → ASCII, then lowercase + hyphenize, max 50 chars)
slug="$(printf '%s' "$title" \
  | python3 -c "import sys, unicodedata; print(unicodedata.normalize('NFD', sys.stdin.read()).encode('ascii','ignore').decode())" 2>/dev/null \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' \
  | cut -c1-50)"
[[ -z "$slug" ]] && slug="untitled"

# 4. Filename with seconds + 4-char random hex (avoids collisions on retry)
stamp="$(date +%Y-%m-%d-%H%M%S)"
rand="$(printf '%04x' $((RANDOM & 0xffff)))"
filename="${stamp}-${rand}-${slug}.md"
filepath="${drafts_dir}/${filename}"

# 5. Write file with metadata wrapper around the captured body
{
  printf '# %s\n\n' "$title"
  printf '_Saved as fallback at %s. Workspace: %s · Team: %s_\n\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$workspace_slug" "$team_key"
  printf -- '---\n\n'
  printf '%s\n' "$body"
  printf '\n---\n\n'
  printf 'Retry: edita acima e cola no Linear via deeplink abaixo, ou tenta criar de novo na skill.\n'
} > "$filepath"

# 6. Copy the body (without metadata) to the clipboard
clipboard_status="(clipboard not available — install pbcopy, xclip, or wl-copy)"
if command -v pbcopy >/dev/null 2>&1; then
  printf '%s' "$body" | pbcopy
  clipboard_status="(copiado pro clipboard via pbcopy)"
elif command -v xclip >/dev/null 2>&1; then
  printf '%s' "$body" | xclip -selection clipboard
  clipboard_status="(copiado pro clipboard via xclip)"
elif command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "$body" | wl-copy
  clipboard_status="(copiado pro clipboard via wl-copy)"
fi

# 7. Build deeplink using workspace slug (NOT team key — Linear URLs use workspace slug)
deeplink="https://linear.app/${workspace_slug}/issue/new"

cat <<EOF
Draft salvo: ${filepath}
${clipboard_status}
Deeplink: ${deeplink}
EOF
