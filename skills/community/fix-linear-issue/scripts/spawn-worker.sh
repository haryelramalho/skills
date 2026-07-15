#!/usr/bin/env bash
# spawn-worker.sh — BOOTSTRAP helper (mutates cmux: creates a pane/surface and
# launches a worker TUI).
# Resolves the caller cmux workspace, finds or creates one right-side helper
# pane, opens a terminal surface in it (no focus stealing), and launches the
# correct worker TUI for (profile, role) with CWD = the worktree and
# SKEEPER_SKIP=1 exported. Prints exactly the launched `surface:N` ref on stdout.
#
# The launch commands and effort flags below MIRROR references/model-routing.md;
# that file is the single source of truth. Update both together.
#
# Usage:   spawn-worker.sh <profile> <role> <worktree-abs-path>
#            profile: backend-python | frontend-node
#            role:    executor | reviewer
# Output:  surface:N   (the launched worker surface) on stdout
# Exit:    0 on success; 64 on usage error; 65 if the workspace is unresolvable;
#          66 if a cmux command fails.
#
# Parsed cmux output is read through `rtk proxy cmux` so rtk's token filter does
# not truncate JSON. Fire-and-forget input uses `rtk cmux`. Refs are extracted
# with grep (not jq): nested rtk invocations can prepend noise to the JSON
# payload, which breaks a strict parser but not a ref grep. The launch line sent
# into the surface must be portable to the user's login shell (often fish), so
# it uses `env VAR=... cmd` and `&&` only — never `export`.
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: spawn-worker.sh <backend-python|frontend-node> <executor|reviewer> <worktree-abs-path>" >&2
  exit 64
fi

profile="$1"
role="$2"
worktree="$3"

case "${profile}" in
  backend-python|frontend-node) ;;
  *) echo "spawn-worker: unknown profile '${profile}' (want backend-python|frontend-node)" >&2; exit 64 ;;
esac
case "${role}" in
  executor|reviewer) ;;
  *) echo "spawn-worker: unknown role '${role}' (want executor|reviewer)" >&2; exit 64 ;;
esac
if [ ! -d "${worktree}" ]; then
  echo "spawn-worker: worktree path '${worktree}' is not a directory" >&2
  exit 64
fi

# Launch command per (profile, role). Executor plan-mode: Claude uses the native
# --permission-mode plan launch flag; Codex has no plan launch flag — the
# orchestrator enters plan mode after spawn with the /plan slash command
# (see references/cmux-execution.md). The Codex executor pins BOTH effort tiers
# explicitly (plan mode xhigh, execution medium) so the user's codex defaults
# never leak into the run. The reviewer is read-only by construction:
# Claude runs plan mode without --dangerously-skip-permissions; Codex runs
# -s read-only. Flags mirror references/model-routing.md.
case "${profile}:${role}" in
  backend-python:executor) launch="rtk codex -m gpt-5.5 -C \"${worktree}\" -c model_reasoning_effort=medium -c plan_mode_reasoning_effort=xhigh" ;;
  frontend-node:executor)  launch="rtk claude --dangerously-skip-permissions --model opus --permission-mode plan" ;;
  backend-python:reviewer) launch="rtk claude --model opus --effort xhigh --permission-mode plan" ;;
  frontend-node:reviewer)  launch="rtk codex -m gpt-5.5 -C \"${worktree}\" -c model_reasoning_effort=xhigh -s read-only" ;;
esac

ws="${CMUX_WORKSPACE_ID:-}"
if [ -z "${ws}" ]; then
  ws="$(rtk proxy cmux identify --json 2>/dev/null | grep -oE 'workspace:[0-9]+' | head -1 || true)"
fi
if [ -z "${ws}" ]; then
  echo "spawn-worker: cannot resolve caller workspace (set CMUX_WORKSPACE_ID or start cmux)" >&2
  exit 65
fi

caller_pane="$(rtk proxy cmux identify --json 2>/dev/null | grep -oE 'pane:[0-9]+' | head -1 || true)"

# Reuse a non-caller helper pane if one exists; otherwise create one right pane.
helper_pane="$(rtk proxy cmux list-panes --workspace "${ws}" --json 2>/dev/null \
  | grep -oE 'pane:[0-9]+' | grep -vxF "${caller_pane}" | head -1 || true)"

if [ -z "${helper_pane}" ]; then
  helper_pane="$(rtk proxy cmux new-pane --workspace "${ws}" --type terminal --direction right --focus false 2>/dev/null \
    | grep -oE 'pane:[0-9]+' | head -1 || true)"
fi
if [ -z "${helper_pane}" ]; then
  echo "spawn-worker: failed to find or create a helper pane in ${ws}" >&2
  exit 66
fi

surface="$(rtk proxy cmux new-surface --workspace "${ws}" --pane "${helper_pane}" --type terminal --focus false 2>/dev/null \
  | grep -oE 'surface:[0-9]+' | head -1 || true)"
if [ -z "${surface}" ]; then
  echo "spawn-worker: failed to create a worker surface in ${helper_pane}" >&2
  exit 66
fi

# Send the launch line, then Enter to submit it. Do not rely on an embedded
# newline: cmux send may not submit it, so send-key enter is the documented way.
# The surface runs the user's login shell (often fish): `env VAR=... cmd` and
# `&&` are portable across fish/bash/zsh; `export VAR=...` is not.
worker_cmd="cd \"${worktree}\" && env SKEEPER_SKIP=1 ${launch}"
rtk cmux send --surface "${surface}" "${worker_cmd}" >/dev/null 2>&1 || {
  echo "spawn-worker: failed to send the launch command to ${surface}" >&2
  exit 66
}
rtk cmux send-key --surface "${surface}" enter >/dev/null 2>&1 || {
  echo "spawn-worker: failed to submit the launch command to ${surface}" >&2
  exit 66
}

echo "${surface}"
