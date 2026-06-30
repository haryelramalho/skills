#!/usr/bin/env bash
# check-reports.sh — READ-ONLY validator. Inspects each review report file and reports
# whether it is usable, so the caller knows which passes to re-run before consolidating.
#
# Usage: check-reports.sh <report1.md> [report2.md ...]
#
# Prints one line per file: OK | EMPTY | MISSING | SUSPECT, plus line count.
# Exits 0 only when every file is OK.

set -uo pipefail

rc=0
for f in "$@"; do
  if [ ! -e "${f}" ]; then
    echo "MISSING  ${f}"
    rc=1
    continue
  fi
  if [ ! -s "${f}" ]; then
    echo "EMPTY    ${f}  (see ${f%.md}.stderr.log)"
    rc=1
    continue
  fi
  lines="$(wc -l < "${f}" | tr -d ' ')"
  if grep -qiE 'execution error|ultrareview failed|authorization required|transport channel closed|no report produced|^failed\b' "${f}"; then
    echo "ERROR    ${f}  (${lines} lines — failure text found; inspect manually)"
    rc=1
    continue
  fi
  if grep -qiE 'verdict|finding|severity|^#|issue|review' "${f}"; then
    echo "OK       ${f}  (${lines} lines)"
  else
    echo "SUSPECT  ${f}  (${lines} lines — no review markers found; inspect manually)"
    rc=1
  fi
done
exit ${rc}
