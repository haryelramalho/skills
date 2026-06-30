---
name: linear-issue-creator
description: Creates well-formed Linear issues from explicit imperative chat commands. Activates ONLY when the user writes phrases like 'cria issue', 'cria uma issue', 'abre ticket', 'abre uma issue', 'nova issue', 'nova task', 'novo ticket', 'cria task', 'manda pro Linear', 'vamos pro Linear', 'open an issue', 'create a ticket', 'create issue', 'new linear issue', or '/issue ...'. Detects issue type (bug, feature, tech-debt, spike) from the verb in the request and applies a matching template, then posts via the Linear MCP server using leaf-name labels, returning the issue URL plus an opt-in follow-up suggestion. Do NOT activate for descriptive mentions like 'tem um bug em X', 'essa feature', 'isso é dívida técnica', nor for editing existing issues, modifying Linear workspace settings (workflow states, labels, projects), sprint planning, estimation, or generic backlog grooming.
---

# Linear Issue Creator

## Overview

Transforms a single chat sentence into a well-formed Linear issue. Default behavior: fast path (one round of inference + preview + post). The skill defaults to Brazilian Portuguese for issue content; switches to English if the user appends `in english`.

Output to the user is concise. The skill marks every inferred field with `[Assumption]` so the user sees what was guessed. The skill never modifies Linear workspace settings — only creates/updates the issue being authored.

## Procedures

**Step 0: Resolve skill base directory**
1. Capture the absolute path of this skill from the harness load context. Claude Code and Codex both announce it at load time (e.g., `Base directory for this skill: /Users/.../skills/linear-issue-creator`). Store as `<skill-base-dir>` for the rest of the run.
2. ALL subsequent script invocations MUST use this absolute path: `bash <skill-base-dir>/scripts/<script>.sh`. Never use a bare `bash scripts/<script>.sh` — the user's cwd is their project repository, not the skill directory.
3. **Fallback if the harness banner is absent or unparseable** — try in this exact order:
   - First check `${HOME}/.claude/skills/linear-issue-creator/SKILL.md` (preferred Claude Code path).
   - If that file does not exist, check `${HOME}/.codex/skills/linear-issue-creator/SKILL.md`.
   - If NEITHER exists (e.g., custom install root, multi-tenant layout), refuse: `Não consegui resolver o diretório da skill (harness não anunciou base dir e nenhum dos paths padrão existe). Reinstale a skill ou abra issue.` and EXIT.
   - When both exist (typical dual install), pick Claude first. Both should be identical; the choice only matters if a sync drifted, in which case the Claude copy is canonical.

**Step 1: Verify activation gate and detect management commands**
1. Read `references/triggers.md` to confirm the user's message contains an explicit activation phrase.
2. If no activation phrase is matched, abort silently. Do not interfere with the ongoing conversation.
3. If a phrase matches a descriptive pattern from the "MUST NOT activate" list, abort silently.
4. **Management commands check (with normalization):** Strip the activation phrase from the message; the remainder is the brief. **Normalize the brief before matching:** lowercase it, strip leading punctuation (`:`, `-`, `—`), and collapse runs of whitespace to single spaces. Then check whether the normalized brief equals one of:
   - `config reset` or `reconfig` → delete `~/.config/linear-issue-creator/config.json` (if exists) and proceed directly to Step 3 (which will run the first-run wizard).
   - `config show` → print the current config in human-readable form (mask UUIDs, show only leaf names and slugs) and EXIT.
   - `config set <key> <value>` (`config set` prefix) → refuse: `Use o Linear UI ou apague o config.json e rode reconfig.` EXIT.
5. Otherwise treat the brief as an issue brief and continue.

**Step 2: Verify Linear MCP setup (fail fast)**
1. Attempt `mcp__linear__list_teams` with no parameters.
2. Read `references/linear-context.md` section "Setup detection" (anchor `setup-detection`) to classify the outcome into Category A (auth/config — guide user, EXIT) or Category B (intermittent — offer fallback). Success → continue.
3. If user agreed to fallback in Category B, set `mode=fallback`. Persist this flag through the rest of the run; check it explicitly at the start of Step 3 and Step 7.

**Step 3: Load configuration (or run wizard, or use offline minimal config)**
1. **If `mode=fallback`** → read `references/linear-context.md` section "Offline minimal config" (anchor `offline-minimal-config`) and follow it. Do NOT attempt the regular wizard. After offline minimal config completes (with `wasOfflineFirstUse=true` if cached config was missing/invalid), jump to Step 4.
2. Otherwise, read `~/.config/linear-issue-creator/config.json` if it exists. Apply the validation in `references/linear-context.md` section "Configuration file → Required field validation":
   - Missing file → run first-run wizard.
   - Malformed JSON → output the corruption error and EXIT.
   - Missing required keys (`workspaceSlug`, `defaultTeamKey`, or any mandatory `labels.<bug|feature|tech-debt|spike>`) → output `Config existente está incompleto (faltam campos da v2). Rode /issue config reset pra refazer.` and EXIT.
3. If config is missing, run the first-run wizard described in `references/linear-context.md` section "First-run wizard" (anchor `first-run-wizard`). Save the config when done.
4. Run housekeeping (cleanup of old drafts) — fire and forget:
   `find ~/.local/share/linear-issue-creator/drafts -type f -name '*.md' -mtime +30 -delete 2>/dev/null || true`

**Step 4: Parse the user's brief**
1. The brief is the remainder of the user's message after the activation phrase (already extracted in Step 1).
2. Detect the issue type using the verb cues table in `references/triggers.md`. If ambiguous, ask exactly: `É bug, feature, tech-debt ou spike?`. Wait for one-word reply.
3. Extract inline modifiers (documented in `references/triggers.md` — pay attention to the disambiguation rule for `--label` / `[label: X]` and `--assignee` / `[assignee: X]`): `go` / `cria já` / `--no-preview`, `in english`, `em <TEAM>`, `no projeto <NAME>`, `--label <NAME>` / `[label: <NAME>]`, `--assignee <NAME>` / `[assignee: <NAME>]` / `pra @<user>`, `inclui trecho de <FUNC>`. Bare `label` and `assignee` (no sigil) stay in the brief as content. Remove recognized modifiers from the brief once captured.
4. Run path detection on the cleaned brief using the regex from `references/triggers.md`. For each matched path that exists on disk (relative to the user's cwd), run `bash <skill-base-dir>/scripts/code-context.sh <path>` and collect the output. If a snippet was requested via `inclui trecho de <FUNC>`, run `bash <skill-base-dir>/scripts/code-context.sh <path> <FUNC>` and add a `[best-effort]` tag in the section header (the user is expected to validate during preview — no extra warning needed in `## Notas`).

**Step 5: Generate fast-path draft**
1. Read `references/templates.md` for the type's template.
2. Fill placeholders from the brief. For any field NOT explicitly stated, infer a value and prefix the line with `[Assumption]`.
3. Construct the issue title using the type's title format (under 80 characters).
4. Append the path-context blocks (from Step 4) under `## Código relacionado`. Omit the section if no paths.

**Step 6: Preview and confirm**
1. If the user's brief contained `go`, `cria já`, or `--no-preview`, skip to Step 7.
2. Otherwise, render the draft to the chat:
   ```
   ---
   **Título:** <title>
   **Tipo:** <type> · **Project:** <project or "—"> · **Labels:** <leaf names>

   <body>
   ---
   ```
3. Ask exactly: `Cria? (sim/aprofunda/<ajuste inline>)`
4. Branch on the user's reply:
   - `sim` / `ok` / `vai` / `cria` → Step 7.
   - `aprofunda` → enter deep interview: ask 4-6 targeted questions one at a time covering missing fields (one question per chat turn). After answers, regenerate the draft and return to Step 6.
   - `muda <X> pra <Y>` or any natural-language adjustment → apply, return to Step 6.
   - `cancela` / `nada` → abort silently.

**Step 7: Post to Linear (or save fallback)**
1. **If `mode=fallback`** (set in Step 2): pipe the rendered body to `bash <skill-base-dir>/scripts/save-fallback.sh "<workspaceSlug>" "<teamKey>" "<title>"` and skip to Step 8 with the `mode=fallback` indicator. Use the `workspaceSlug` and `teamKey` captured in Step 3 (from cached config OR offline minimal config interview).
2. Otherwise, **mandatory type label safety check** — read `references/linear-context.md` section "Label resolution gotcha" → "Mandatory type label safety check" subsection. If `config.labels[<detected-type>]` is null/missing, print the user-visible warning and proceed without the type label.
3. Map the type label to a UUID using `config.labels[<type>]`. Add area labels likewise. Read `references/linear-context.md` section "Label resolution gotcha" (anchor `label-resolution-gotcha`) before sending. Use UUIDs.
4. **Landing state resolution** — read `references/linear-context.md` section "Issue creation parameters" → "Landing state resolution" to decide whether to send `state: <triage>` or omit. If `defaultLandingState` is `triage` but the team no longer has a triage status, print the one-line warning and omit `state`.
5. Compose the `save_issue` payload according to `references/linear-context.md` section "Issue creation parameters" (anchor `issue-creation-parameters`).
6. Call `mcp__linear__save_issue` with the payload.
   - On success → capture the returned `id` and `url`. Continue to Step 8.
   - On API error / timeout → switch to fallback: pipe to `bash <skill-base-dir>/scripts/save-fallback.sh "<workspaceSlug>" "<teamKey>" "<title>"`, then continue to Step 8 with `mode=fallback`.
   - On success but with empty `labels` array (the prefixed-name gotcha): retry once with leaf names. If still empty, log a warning and continue.

**Step 8: Report and suggest follow-up**
1. **If `mode=fallback`:** print what `scripts/save-fallback.sh` produced. Then, if `wasOfflineFirstUse == true` (the offline minimal config asked the user inline because cached config was missing/incomplete), append exactly ONE additional line: `Quando o Linear voltar, roda /issue config reset pra completar o wizard.`. Stop.
2. Otherwise, print exactly two lines:
   - `Issue criada: <id> — <url>`
   - The follow-up suggestion below, depending on type. If type is `feature` or `spike`, omit the second line entirely.
3. Type → suggestion mapping:
   - `bug` → `Quer rodar /systematic-debugging agora pra começar a investigar?`
   - `tech-debt` → `Quer rodar /architectural-analysis pra dimensionar o escopo?`
   - `feature` / `spike` → no suggestion.
4. Do NOT auto-invoke the suggested skill. The user decides.

## Error Handling

- If `mcp__linear__save_issue` returns an empty `labels` array despite labels being passed, the labels were sent with prefixed names. Re-read `references/linear-context.md` section "Label resolution gotcha" and retry with UUIDs.
- If `bash <skill-base-dir>/scripts/code-context.sh` exits non-zero, log the error to stderr and OMIT the path from `## Código relacionado`. Do not abort.
- If `bash <skill-base-dir>/scripts/save-fallback.sh` exits non-zero, fall back further: print the rendered markdown directly to chat with the deeplink `https://linear.app/<workspaceSlug>/issue/new` and instruct the user to copy manually.
- If the user requests an out-of-scope operation (modifying labels, workflow states, bulk-closing issues, etc.), output: `Essa operação está fora do escopo do linear-issue-creator. Use o Linear UI ou outra skill.` Do not attempt.
- If multiple type-cue verbs appear in the brief (e.g., "refatorar e investigar"), ask the user once: `Detectei 'tech-debt' e 'spike' na sua frase. Qual escolho?`. Do NOT pick silently.
- If `<skill-base-dir>` could not be resolved in Step 0, refuse to proceed with script-dependent operations (path detection, fallback save). Output the failure message in Step 0 and EXIT.

## Tone constraints

- Output to the user is concise. No narration of routine actions ("Calling list_teams now...", "Generating draft..."). Just do, then show the preview.
- Prefix every inferred field in the draft with `[Assumption]`. Never silently fill in a value the user did not state.
- When asking a clarification question, ask exactly one. No bundles.
- When pushing back (out-of-scope request, ambiguous type), state the constraint in one sentence without apology.
