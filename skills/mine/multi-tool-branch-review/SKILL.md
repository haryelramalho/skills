---
name: multi-tool-branch-review
description: Orchestrates a multi-tool branch review of the current git branch against a base branch. By default it runs two independent thermo-nuclear maintainability audits, one on Codex GPT-5.5 xhigh and one on Claude Opus xhigh, then consolidates the findings into a single remediation plan via writing-plans. If the user explicitly asks for native reviews, it can add the Claude native review pass, the Codex native review pass, or both. Use when the user wants a deep cross-model review of a branch or PR before merge, or asks to review this branch with multiple tools or models. Encodes known infra failure modes and their fixes (missing Claude ACP adapter, Codex MCP auth hangs, false-positive report files, long jobs orphaned inside subagents). Do not use for reviewing a single uncommitted snippet, for non-git work, for running only one reviewer, or when the user only wants a quick lint or test run.
disable-model-invocation: true
---

# Multi-Tool Branch Review

Fan out the current branch's diff to four independent reviewers, then merge their findings into one plan. The four passes are a 2×2 matrix: two tools (Codex, Claude) × two doctrines (a strict "thermo-nuclear" maintainability audit, and each tool's native branch-review command). The diversity is the point — keep the passes independent and let disagreement surface.

This SKILL.md is a dispatcher. The bundled scripts hold the exact, fragile tool invocations; the reference holds the failure-mode fixes. Do not retype the commands from memory — call the scripts.

## Bundled Path Rule

The agent's working directory is the repository under review, NOT this skill's folder. Resolve every bundled path against the directory printed as "Base directory for this skill: …" at launch. Expand `<skill-dir>` to that absolute path before running a helper (e.g. `<skill-dir>/scripts/run-review.sh`).

## Required Reading Router

Match the situation to the row. Read the listed file **in full before** acting. Inline text here is a pointer, not a substitute.

| Situation | MUST read |
| --- | --- |
| Deciding which reviewers to run by default vs. explicit native opt-in | `<skill-dir>/scripts/resolve-passes.sh` |
| Any pass reports EMPTY/MISSING, or stderr shows an ACP / MCP / auth / timeout error | `<skill-dir>/references/troubleshooting.md` |
| Deciding how to launch long jobs (subagent vs background) | `<skill-dir>/references/troubleshooting.md` |

### Reference & Asset Index
- `references/troubleshooting.md` — the known infra failure modes (missing `claude-agent-acp`, Codex MCP auth abort, subagent orphaning, empty-report triage, output-capture mechanics, base-branch choice) and the exact fix for each.
- `scripts/resolve-passes.sh` — **read-only selector**. Resolves the requested review mode into the exact pass ids to launch.
- `scripts/run-review.sh` — **read-only driver** (never modifies the repo). Runs ONE pass and writes its report. Auto-selects the working invocation per tool and applies the fixes.
- `scripts/check-reports.sh` — **read-only validator**. Classifies each report file as OK/EMPTY/MISSING/SUSPECT/ERROR.
- `assets/thermo-prompt.md` — the thermo-nuclear prompt template the driver fills in for the two thermo passes.

## Review Modes

Default behavior is **thermo-only**. Native reviews are opt-in.

| Mode | When to use | Passes launched |
| --- | --- | --- |
| `thermo-only` | Default when the user just asks for a branch review with this skill | `codex-thermo`, `claude-thermo` |
| `all-four` | The user explicitly asks for both native reviews too | `codex-thermo`, `claude-thermo`, `claude-codereview`, `codex-codereview` |
| `claude-native` | The user explicitly wants Claude native review in addition to the thermo pair | `codex-thermo`, `claude-thermo`, `claude-codereview` |
| `codex-native` | The user explicitly wants Codex native review in addition to the thermo pair | `codex-thermo`, `claude-thermo`, `codex-codereview` |

Treat these exact mode names as the contract. If the user says "run the native reviewers too", map that to `all-four`. If they mention only one native reviewer, map to that single-native mode. If they do not explicitly ask for native review, use `thermo-only`.

## Invocation Contract

The skill accepts three explicit request overrides in the user's message:

- `base=<git-ref>` — override the base branch or tag to compare against. Examples: `base=origin/release/2026-06`, `base=origin/feat/foo`, `base=hotfix/bar`.
- `mode=<mode>` — one of `thermo-only`, `all-four`, `claude-native`, `codex-native`.
- `focus="<review angle>"` — optional extra review focus to propagate into the downstream reviewers that support custom instructions.

If the user provides no explicit overrides, use:

- `base=origin/main` when that ref exists; otherwise use `main`
- `mode=thermo-only`
- no `focus`

Examples:

- `Use $multi-tool-branch-review base=origin/release/2026-06`
- `Use $multi-tool-branch-review base=origin/feat/foo mode=all-four`
- `Use $multi-tool-branch-review base=release/hotfix mode=codex-native focus="stress queue boundaries and transaction commits"`

Propagation rules:

- `base` is passed to every downstream review command.
- `focus` is passed to `codex-thermo`, `claude-thermo`, and `codex-codereview`.
- `focus` is NOT passed to `claude-codereview`, because `claude ultrareview` does not expose a custom prompt/input channel for that path.
- If the user requires the same custom focus on all reviewers, prefer `thermo-only`.

## Available Passes

| Pass id | Tool | Doctrine |
| --- | --- | --- |
| `codex-thermo` | Codex (gpt-5.5, xhigh) | thermo-nuclear maintainability audit |
| `claude-thermo` | Claude Opus (xhigh) | thermo-nuclear maintainability audit |
| `claude-codereview` | Claude Opus (xhigh) | native `ultrareview` |
| `codex-codereview` | Codex (gpt-5.5, xhigh) | native `codex review` |

## Procedure

**Step 1: Establish scope.**
1. Confirm the repo is a git repository and read the current branch: `git rev-parse --abbrev-ref HEAD`.
2. Determine the base branch from `base=<git-ref>` when present. Otherwise default to `origin/main` when it exists, falling back to `main`. Sanity-check the diff size: `git diff <base>...HEAD --stat`.
3. If there are no commits ahead of base, stop and tell the user there is nothing to review.
4. Resolve the review mode. **STOP. Read `<skill-dir>/scripts/resolve-passes.sh` in full before launching anything.** Use `thermo-only` unless the user explicitly opts into native review with `all-four`, `claude-native`, or `codex-native`.
5. Extract `focus="<...>"` when present and carry it forward only to the reviewers that support custom input.

**Step 2: Launch the selected passes as background jobs.**
1. **STOP. Read `<skill-dir>/references/troubleshooting.md` in full before launching** — it defines why each pass must run as an orchestrator-level background job (subagent-held processes get orphaned) and why the commands are shaped the way they are. The mode table above is the contract.
2. Resolve the exact pass list:
   ```
   <skill-dir>/scripts/resolve-passes.sh <mode>
   ```
3. For each returned pass id, launch with the Bash tool using `run_in_background: true`:
   ```
   <skill-dir>/scripts/run-review.sh <pass-id> <base> /tmp/review-<pass-id>.md "<focus>"
   ```
   Launch all selected passes in one batch so they run concurrently. Each takes ~15–25 min. Do NOT wrap these in spawned subagents that "wait" — run them directly so the orchestrator is re-invoked on exit and its context stays lean (reports live in files).

**Step 3: Wait, then validate.**
1. Wait for the completion notifications for the selected passes. Do not poll aggressively.
2. Validate the outputs for exactly the selected pass set:
   ```
   <skill-dir>/scripts/check-reports.sh /tmp/review-<pass-1>.md ...
   ```

**Step 4: Re-run any failed pass.**
1. For each non-`OK` row, read the matching `/tmp/review-<pass-id>.stderr.log` to classify the cause.
2. **STOP. Read `<skill-dir>/references/troubleshooting.md`** and apply the fix for that cause, then re-run only that one pass via `run-review.sh` (again in the background). Repeat Step 3 until every pass is `OK` or is confirmed unrecoverable (report which, and why, rather than silently dropping it).

**Step 5: Consolidate into a plan.**
1. Read all selected report files in full.
2. Deduplicate findings across reviewers (same file+symbol/line = one issue) and record agreement: an issue flagged by multiple reviewers is higher-confidence; a lone flag may be noise — judge it on merits, do not auto-include.
3. Invoke the `writing-plans` skill to produce one consolidated remediation plan. Group by severity (blockers → majors → minors), and for each item cite which reviewer(s) raised it and the concrete remedy. Note any direct contradictions between reviewers as open decisions for the user.

## Error Handling
- If `scripts/run-review.sh` exits non-zero or prints `FAILED`, the report is missing/empty — go to Step 4 (classify via stderr, fix via the troubleshooting reference, re-run that one pass).
- If `scripts/check-reports.sh` reports `SUSPECT` or `ERROR`, open the file: a reviewer may have returned prose without the expected markers or a failure sentinel instead of a real review. Keep it only if it contains real findings.
- If the thermo passes error with "thermo-nuclear-code-quality-review skill not found", install that skill into `~/.claude/skills` (or `~/.agents/skills`); the thermo passes depend on it.
- Never fabricate findings to fill a failed pass. Consolidate only from reports that actually ran, and state which passes are included.
