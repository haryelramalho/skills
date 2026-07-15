#!/usr/bin/env bash
# wait-worker.sh — READ-ONLY helper (only reads the worker screen and health).
# Polls a worker surface until it returns to an idle prompt, then prints DONE and
# exits 0. Exits non-zero if the surface dies or the max-wait guard trips. Idle
# detection is a conservative heuristic: it prefers reporting NOT-DONE over a
# false DONE, so the orchestrator must still confirm completion by asking the
# worker for a status summary (see references/cmux-execution.md).
#
# Usage:   wait-worker.sh <surface-ref> [interval-seconds]
#            interval-seconds default: 30
# Env:     WAIT_WORKER_TIMEOUT   max seconds to wait (default: 2700 = 45m)
# Output:  PLAN_PROMPT on stdout when the worker is stopped at a native
#          plan-approval prompt (Codex "Implement this plan?" picker / Claude
#          ExitPlanMode) — the orchestrator must review the plan and drive the
#          picker NOW. Otherwise DONE when the worker is idle.
# Exit:    0 when idle or at a plan prompt; 64 on usage error; 3 if the surface
#          died; 7 on timeout.
#
# Screen reads go through `rtk proxy cmux` so rtk's token filter does not mangle
# the captured output.
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: wait-worker.sh <surface-ref> [interval-seconds]" >&2
  exit 64
fi

surface="$1"
interval="${2:-30}"
timeout="${WAIT_WORKER_TIMEOUT:-2700}"
ws="${CMUX_WORKSPACE_ID:-}"

case "${surface}" in
  surface:[0-9]*) ;;
  *) echo "wait-worker: expected a surface:N ref, got '${surface}'" >&2; exit 64 ;;
esac

# Any of these on screen means the worker is still active — treat as NOT-DONE.
busy_re='Esc to interrupt|esc to interrupt|Working|Thinking|Running|Generating|Streaming|Compacting|Applying|Editing|Reading|tokens used|⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏'
# The worker stopped at its native plan-approval affordance — report immediately.
plan_prompt_re='Implement this plan\?|Would you like to proceed|ExitPlanMode|Ready to code\?'

elapsed=0
idle_streak=0
while :; do
  if ! screen="$(rtk proxy cmux read-screen --surface "${surface}" 2>/dev/null)"; then
    diag="$(rtk proxy cmux surface-health ${ws:+--workspace "${ws}"} --json 2>/dev/null || true)"
    echo "wait-worker: surface ${surface} is unreadable (dead?): ${diag}" >&2
    exit 3
  fi

  if printf '%s' "${screen}" | grep -Eq "${plan_prompt_re}"; then
    echo "PLAN_PROMPT"
    exit 0
  fi

  if printf '%s' "${screen}" | grep -Eq "${busy_re}"; then
    idle_streak=0
  else
    idle_streak=$((idle_streak + 1))
    # Require three consecutive idle reads before declaring DONE (conservative:
    # Codex idles briefly between plan/exploration segments — two reads gave
    # false DONEs in practice).
    if [ "${idle_streak}" -ge 3 ]; then
      echo "DONE"
      exit 0
    fi
  fi

  if [ "${elapsed}" -ge "${timeout}" ]; then
    echo "wait-worker: timed out after ${timeout}s waiting on ${surface}" >&2
    exit 7
  fi
  sleep "${interval}"
  elapsed=$((elapsed + interval))
done
