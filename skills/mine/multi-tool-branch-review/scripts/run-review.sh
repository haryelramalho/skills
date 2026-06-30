#!/usr/bin/env bash
# run-review.sh — READ-ONLY review driver (it never modifies the repository under review).
# Runs ONE review pass against a base branch and writes that reviewer's report to <outfile>.
# It spawns an external review tool (codex / claude / compozy) that can take 15-25 min, so
# the caller MUST launch this with run_in_background and wait for the completion notification.
#
# Usage: run-review.sh <pass> <base> <outfile> [focus]
#   <pass>    one of: codex-thermo | claude-thermo | claude-codereview | codex-codereview
#   <base>    base branch to compare against (e.g. main)
#   <outfile> path for the report (e.g. /tmp/review-codex-thermo.md). Sibling files
#             <outfile>.stderr.log and <outfile>.run.log capture diagnostics.
#   [focus]   optional extra review focus text. Propagated to the thermo passes and
#             codex native review. Claude native ultrareview ignores it.
#
# Exit 0 only when a usable review report exists at <outfile>.

set -uo pipefail

PASS="${1:?usage: run-review.sh <pass> <base> <outfile> [focus]}"
BASE="${2:?base branch required (e.g. main)}"
OUT="${3:?output file required (e.g. /tmp/review-codex-thermo.md)}"
FOCUS="${4-}"

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERR="${OUT%.md}.stderr.log"
RUN="${OUT%.md}.run.log"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"

rm -f "${OUT}" "${ERR}" "${RUN}"

resolve_thermo_skill() {
  local d
  for d in "${HOME}/.claude/skills" "${HOME}/.agents/skills"; do
    if [ -f "${d}/thermo-nuclear-code-quality-review/SKILL.md" ]; then
      printf '%s' "${d}/thermo-nuclear-code-quality-review/SKILL.md"
      return 0
    fi
  done
  return 1
}

make_thermo_prompt() {
  local reviewer="$1" thermo tmpdir tmp focus_block
  if ! thermo="$(resolve_thermo_skill)"; then
    echo "thermo-nuclear-code-quality-review skill not found in ~/.claude/skills or ~/.agents/skills" >&2
    return 1
  fi
  if ! tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/thermo-prompt.XXXXXX")"; then
    echo "failed to create temp directory for thermo prompt" >&2
    return 1
  fi
  focus_block=""
  if [ -n "${FOCUS}" ]; then
    focus_block="$(cat <<EOF
5. Give extra attention to this user-specified review focus:
   ${FOCUS}
EOF
)"
  fi
  tmp="${tmpdir}/prompt.md"
  if ! REVIEW_BRANCH="${BRANCH}" \
      REVIEW_BASE="${BASE}" \
      REVIEWER="${reviewer}" \
      REVIEW_OUTFILE="${OUT}" \
      EXTRA_FOCUS_BLOCK="${focus_block}" \
      THERMO_SKILL_PATH="${thermo}" \
      python3 - "${SKILL_DIR}/assets/thermo-prompt.md" "${tmp}" <<'PY'; then
import os
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
content = source.read_text()
replacements = {
    "BRANCH": os.environ["REVIEW_BRANCH"],
    "BASE": os.environ["REVIEW_BASE"],
    "REVIEWER": os.environ["REVIEWER"],
    "OUTFILE": os.environ["REVIEW_OUTFILE"],
    "EXTRA_FOCUS_BLOCK": os.environ["EXTRA_FOCUS_BLOCK"],
    "THERMO_SKILL_PATH": os.environ["THERMO_SKILL_PATH"],
}
for key, value in replacements.items():
    content = content.replace("{{" + key + "}}", value)
target.write_text(content)
PY
    echo "failed to render thermo prompt template" >&2
    return 1
  fi
  printf '%s' "${tmp}"
}

report_is_usable() {
  "${SKILL_DIR}/scripts/check-reports.sh" "$1" >/dev/null 2>&1
}

case "${PASS}" in
  codex-thermo)
    PROMPT="$(make_thermo_prompt "Codex (gpt-5.5 xhigh)")" || exit 1
    cat "${PROMPT}" | codex exec --dangerously-bypass-approvals-and-sandbox \
      -m gpt-5.5 -c model_reasoning_effort=xhigh -c 'mcp_servers={}' > "${RUN}" 2> "${ERR}"
    ;;
  claude-thermo)
    PROMPT="$(make_thermo_prompt "Claude Opus xhigh")" || exit 1
    if command -v compozy >/dev/null 2>&1 && command -v claude-agent-acp >/dev/null 2>&1; then
      compozy exec --ide claude --model opus --reasoning-effort xhigh \
        --timeout 25m --prompt-file "${PROMPT}" > "${RUN}" 2> "${ERR}"
    else
      cat "${PROMPT}" | claude --model opus --effort xhigh -p --dangerously-skip-permissions \
        > "${RUN}" 2> "${ERR}"
    fi
    ;;
  claude-codereview)
    claude --model opus --effort xhigh ultrareview "${BASE}" --timeout 25 > "${OUT}" 2> "${ERR}"
    ;;
  codex-codereview)
    if [ -n "${FOCUS}" ]; then
      printf 'Focus especially on this review angle: %s\n' "${FOCUS}" | \
        codex review -c model=gpt-5.5 -c model_reasoning_effort=xhigh -c 'mcp_servers={}' \
          --base "${BASE}" - > "${OUT}" 2> "${ERR}"
    else
      codex review -c model=gpt-5.5 -c model_reasoning_effort=xhigh -c 'mcp_servers={}' \
        --base "${BASE}" > "${OUT}" 2> "${ERR}"
    fi
    ;;
  *)
    echo "unknown pass: ${PASS}" >&2
    echo "valid passes: codex-thermo | claude-thermo | claude-codereview | codex-codereview" >&2
    exit 2
    ;;
esac
command_rc=$?

if { [ "${PASS}" = "codex-thermo" ] || [ "${PASS}" = "claude-thermo" ]; } \
   && [ ! -s "${OUT}" ] && [ -s "${RUN}" ]; then
  cp "${RUN}" "${OUT}"
fi

if [ "${command_rc}" -eq 0 ] && report_is_usable "${OUT}"; then
  echo "OK ${PASS} -> ${OUT} ($(wc -l < "${OUT}" | tr -d ' ') lines)"
  exit 0
fi
echo "FAILED ${PASS}: command exited ${command_rc} or no usable report was produced. Inspect ${ERR} and ${OUT}" >&2
exit 1
