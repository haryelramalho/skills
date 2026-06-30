# Troubleshooting — Known Failure Modes

## Contents
- Claude passes fail: missing `claude-agent-acp`
- Claude native review is opaque or ignores the requested base
- Codex thermo should run via direct `codex exec`
- Codex native review dies: MCP server auth
- Long jobs vanish: subagent orphaning
- A pass produced an empty report
- Output capture: stdout vs reviewer-written file
- Choosing the base branch

## Claude passes fail: missing `claude-agent-acp`
`compozy exec --ide claude` requires the Claude ACP transport binary `claude-agent-acp` on PATH. It is frequently NOT installed, and the `npx` fallback can additionally fail with `ENOENT: process.cwd failed ... uv_cwd` (a node/npm cwd bug, common inside git worktrees).

Symptom in `*.stderr.log`:
```
ACP transport required for "claude". tried claude-agent-acp. command "claude-agent-acp" was not found on PATH.
```

Fix: do not depend on the Claude ACP adapter. Drive Claude directly with `claude --model opus --effort xhigh -p --dangerously-skip-permissions`. `run-review.sh` already does this automatically for the thermo pass — it only uses `compozy --ide claude` when `claude-agent-acp` is present, otherwise it falls back to the `claude` CLI with the same prompt contract. To restore the compozy path instead, install `@agentclientprotocol/claude-agent-acp` and expose `claude-agent-acp` on PATH.

## Claude native review is opaque or ignores the requested base
`claude -p "/code-review high"` is a poor fit for a headless branch-review driver. It does not take the base branch explicitly, gives little early feedback in stdout, and interrupted runs can leave a tiny `Execution error` file that looks non-empty even though no review completed.

Fix: use `claude --model opus --effort xhigh ultrareview <base> --timeout 25` for the native Claude review pass. `ultrareview` is branch-aware, prints launch/progress information immediately, and accepts the base branch directly. Keep `claude -p` only for the thermo prompt path, where the prompt itself defines the review contract.

## Codex thermo should run via direct `codex exec`
Do not route the Codex thermo pass through `compozy exec --ide codex`. The direct `codex exec` path is the contract for this skill.

Fix: always run `codex-thermo` by piping the rendered thermo prompt into `codex exec --dangerously-bypass-approvals-and-sandbox -m gpt-5.5 -c model_reasoning_effort=xhigh -c 'mcp_servers={}'`. This keeps the Codex path consistent with the native Codex environment and avoids adding an extra orchestration layer to the pass.

## Codex native review dies: MCP server auth
`codex review` loads the MCP servers from `~/.codex/config.toml`. If any server needs interactive auth or is unreachable, the worker aborts and no report is written.

Symptom in `*.stderr.log`:
```
ERROR rmcp::transport::worker: worker quit with fatal: Transport channel closed ... Auth(AuthorizationRequired)
```

Fix: disable MCP for the review run with `-c 'mcp_servers={}'`. `run-review.sh` passes this for both codex passes.

## Long jobs vanish: subagent orphaning
Each review pass takes 15-25 min — longer than the foreground Bash timeout ceiling. Do NOT launch the review command inside a spawned subagent that then "waits": when the subagent ends its turn, its backgrounded child process is orphaned and its completion is opaque to the orchestrator.

Fix: run each pass as an ORCHESTRATOR-LEVEL background job (`run_in_background: true` on the Bash tool). These persist across turns and re-invoke the orchestrator on exit. Outputs go to files, so the orchestrator's context stays lean without needing subagents.

## A pass produced an empty report
Run `scripts/check-reports.sh` against the four output files. For any `EMPTY`/`MISSING`/`SUSPECT`/`ERROR` row, read the matching `*.stderr.log` to classify the cause (ACP, MCP, auth, timeout, or a tiny `Execution error` sentinel), apply the fix above, and re-run only that pass with `run-review.sh`.

## Output capture: stdout vs reviewer-written file
For the thermo passes, the canonical report is the file the reviewer is told to write (`<outfile>`); captured stdout also goes to `<outfile>.run.log` as a fallback capture stream. `run-review.sh` copies `.run.log` to `<outfile>` only if the reviewer did not write the file. For the native code-review passes there is no reviewer-written file — the report IS stdout, captured directly to `<outfile>`.

## Choosing the base branch
Default base is `main`. Confirm the actual integration branch first (`git symbolic-ref refs/remotes/origin/HEAD` or ask the user) — comparing against the wrong base produces a misleading diff and wasted review runs.
