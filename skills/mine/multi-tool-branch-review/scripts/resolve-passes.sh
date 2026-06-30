#!/usr/bin/env bash
# resolve-passes.sh — READ-ONLY selector for review pass sets.
#
# Usage: resolve-passes.sh [mode]
#   mode:
#     thermo-only   default; run only codex-thermo + claude-thermo
#     all-four      add both native review passes
#     claude-native add only the Claude native review pass
#     codex-native  add only the Codex native review pass
#
# Prints one pass id per line.

set -euo pipefail

MODE="${1:-thermo-only}"

case "${MODE}" in
  thermo-only)
    printf '%s\n' codex-thermo claude-thermo
    ;;
  all-four)
    printf '%s\n' codex-thermo claude-thermo claude-codereview codex-codereview
    ;;
  claude-native)
    printf '%s\n' codex-thermo claude-thermo claude-codereview
    ;;
  codex-native)
    printf '%s\n' codex-thermo claude-thermo codex-codereview
    ;;
  *)
    echo "unknown mode: ${MODE}" >&2
    echo "valid modes: thermo-only | all-four | claude-native | codex-native" >&2
    exit 2
    ;;
esac
