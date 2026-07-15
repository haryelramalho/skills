# Linear Context, Taxonomy Discovery, and MCP Gotchas

> **Stable section IDs — DO NOT RENAME these section headers without updating `SKILL.md`.**
> The skill's procedure references these sections by exact name. Each section also has an HTML anchor (`<a id="...">`) so references can target IDs even if a heading word changes. Anchors are the canonical contract; treat them as load-bearing.

## Required MCP server

The skill uses the Linear MCP server registered as `linear` (HTTP transport at `https://mcp.linear.app/mcp`). Tools have prefix `mcp__linear__`.

### Required tools
- `mcp__linear__list_teams`
- `mcp__linear__list_projects`
- `mcp__linear__list_issue_labels`
- `mcp__linear__list_issue_statuses` (requires team)
- `mcp__linear__list_users`
- `mcp__linear__save_issue`
- `mcp__linear__get_issue`

<a id="setup-detection"></a>

### Setup detection (run before any user interview)

Attempt `mcp__linear__list_teams`. Classify the outcome into ONE of two categories using keyword matching on the error message:

**Category A — Auth or config broken (recoverable by user setup).**
Match if error contains any of: `not authenticated`, `unauthorized`, `401`, `403`, `forbidden`, `not configured`, `not registered`, `tool not found`, `unknown tool`, `not installed`, `no credentials`.

Output (in pt-br):
```
Linear MCP precisa de setup. Possíveis causas:
  1. Não instalado: claude mcp add -s user linear --transport http https://mcp.linear.app/mcp
  2. Não autenticado: rode /mcp e autorize no browser
Resolve e tenta de novo.
```
Then EXIT. Do not interview the user.

**Category B — Anything else (treated as intermittent, eligible for fallback).**
Includes: timeout, connection reset, 5xx, generic exception, or any error not matching category A.

Output (in pt-br):
```
Linear parece fora do ar (erro: <truncated message>).
Quer gerar o draft mesmo assim e salvar como fallback (arquivo + clipboard)? (sim/não)
```
If user agrees, set `mode=fallback` and continue. If user declines, EXIT.

**Success branch.** No error → proceed to Step 3.

> Note: the LLM should NOT try to invent extra categorization. When in doubt, default to category B (fallback) — that path is non-destructive.

<a id="configuration-file"></a>

## Configuration file

Path: `~/.config/linear-issue-creator/config.json`

Schema:
```json
{
  "version": 2,
  "defaultTeamId": "uuid",
  "defaultTeamKey": "SAL",
  "workspaceSlug": "salesmart",
  "defaultProjectId": "uuid or null",
  "defaultAssignee": "me or user-uuid or null",
  "defaultLabels": ["uuid", "uuid"],
  "defaultLandingState": "backlog",
  "labels": {
    "bug": "uuid",
    "feature": "uuid",
    "tech-debt": "uuid",
    "spike": "uuid",
    "chore": "uuid",
    "research": "uuid",
    "area/frontend": "uuid",
    "area/backend": "uuid",
    "area/api": "uuid",
    "area/infra": "uuid",
    "area/db": "uuid"
  },
  "createdAt": "ISO-8601 timestamp"
}
```

### Field semantics

- `workspaceSlug` — Linear URLs use it (`https://linear.app/<workspaceSlug>/...`), NOT the team key. **Required.**
- `defaultTeamKey` — used for `save_issue` team field. **Required.**
- `defaultLandingState` — `"triage"` or `"backlog"`. User preference for where new issues land. Triage capability is detected fresh each run (not persisted), so this preference can sit unchanged even if the team enables/disables Triage later.
- Mandatory `labels.<name>` keys (must be non-null): `bug`, `feature`, `tech-debt`, `spike`. Optional ones may be null.

### Required field validation (run on every config load)

When loading config from disk:

1. If file does not exist → run first-run wizard.
2. If file is malformed JSON → output `Config corrompido em ~/.config/linear-issue-creator/config.json. Apaga e roda de novo pra refazer o wizard.` and EXIT.
3. **Validate required keys.** If any of `workspaceSlug`, `defaultTeamKey`, or any of the mandatory `labels.<bug|feature|tech-debt|spike>` are missing or null:
   - In normal mode: output `Config existente está incompleto (faltam campos da v2). Rode /issue config reset pra refazer.` and EXIT.
   - In `mode=fallback`: skip the cached config entirely and fall through to "Offline minimal config" step 2 (ask `workspaceSlug` and `defaultTeamKey` inline).
4. Otherwise the config is usable; proceed.

This handles the v1→v2 upgrade path: pre-v2 configs lack `workspaceSlug` and trigger reconfig instead of producing broken deeplinks.

<a id="first-run-wizard"></a>

### First-run wizard (when config missing AND mode != fallback)

1. **Reset detection:** if the user's brief is `config reset`, `reconfig`, `/issue config reset`, or `/issue reconfig`, delete any existing `~/.config/linear-issue-creator/config.json` BEFORE running this wizard. (This branch is also handled in `SKILL.md` Step 1, but enforce idempotence here.)

2. **Team selection.** Call `list_teams`.
   - If 1 team → auto-pick. Save `defaultTeamId`, `defaultTeamKey`.
   - If multiple → show picker, ask which is default.

3. **Workspace slug discovery.** Linear's `list_teams` response sometimes contains an `organization.urlKey` field that maps to the workspace slug. If absent, ask the user explicitly: `Qual é o slug do teu workspace? (aparece em https://linear.app/<slug>/...). Ex: salesmart`. Save as `workspaceSlug`. Validate it's lowercase alphanumeric+hyphens. **Required — do not let the wizard finish without this.**

4. **User selection.** Call `list_users` for the chosen team.
   - Filter out bots/agents (users with email matching `*@linear.linear.app`, or display name "Linear").
   - If only 1 human user → auto-pick as `defaultAssignee = "me"`.
   - Else → ask "quem é o assignee default? (digita o nome ou 'none')".

5. **Label discovery with normalization.** Call `list_issue_labels` (workspace-wide).

   For each EXPECTED leaf name in this list, find a matching label in the workspace using **normalized comparison**:
   - Lowercase both sides
   - Trim whitespace
   - Replace runs of spaces or underscores with single hyphens (e.g., `Tech Debt` → `tech-debt`, `tech_debt` → `tech-debt`)

   Expected mandatory leaf names (TYPE labels — required):
   - `bug`, `feature`, `tech-debt`, `spike`

   Expected optional leaf names (categorization labels — degrade gracefully if missing):
   - `chore`, `research`, `customer`, `internal`, `performance`, `tests`
   - `frontend`, `backend`, `api`, `infra`, `db`

   For each MANDATORY label NOT found via normalized match, ask exactly:
   ```
   O label de tipo '<name>' não foi encontrado por match direto. Qual nome no teu workspace mapeia pra esse conceito? (digita o nome exato OU 'cancel' pra abortar o wizard)
   ```
   - If the user provides a name, look it up case-insensitively. If found, save its UUID under `labels.<name>` in config and continue.
   - If the lookup fails OR the user types `cancel`, ABORT the wizard with: `Wizard abortado. Crie o label '<name>' no Linear UI e rode /issue reconfig.`. EXIT.
   - Do **not** silently proceed without a mandatory label. Do **not** offer a `skip` option for mandatories. Do **not** offer a `create` option (skill cannot create labels — see Anti-actions below).

   For each OPTIONAL label NOT found: print a single warning `Label opcional '<name>' não encontrado — área será omitida quando aplicável`. Do not block.

6. **Triage preference.** Ask explicitly: `Quer mandar issues novas pra Triage primeiro (review antes do board) ou direto pro Backlog? (triage/backlog)`. Save the answer as `defaultLandingState`.

   Do NOT persist the capability detection (`hasTriageState`). Triage availability is checked fresh each run in Step 7 — if the user picked `triage` but the team no longer has a triage state, the post falls back to default state with a one-line warning.

7. **Default project (optional).** Ask: `Tem projeto default? (digita o nome ou 'none')`. If specified, lookup via `list_projects` and save `defaultProjectId`.

8. **Save config.** `mkdir -p ~/.config/linear-issue-creator` then write `config.json` with `version: 2`. Confirm:
   `Config salva em ~/.config/linear-issue-creator/config.json. Próximas execuções usam silenciosamente.`

### Reconfiguration

The skill recognizes these as management commands (handled in `SKILL.md` Step 1, before normal brief parsing):

- `/issue config reset` or `/issue reconfig` → delete config + run wizard
- `/issue config show` → print current config (without UUIDs, just leaf names and slugs)
- `/issue config set <key> <value>` → out of scope, refuse with: `Use o Linear UI ou apague o config.json e rode reconfig.`

<a id="offline-minimal-config"></a>

## Offline minimal config (fallback path)

When `mode=fallback` is set in Step 2 (intermittent MCP failure), the regular wizard cannot run because it depends on `list_*` MCP calls. Use this minimal flow instead:

1. Try to load `~/.config/linear-issue-creator/config.json`. If it exists AND passes the required-field validation in "Configuration file → Required field validation" above, use the cached `workspaceSlug` and `defaultTeamKey` and skip to draft generation + `save-fallback.sh`. Skip everything else.

2. If config is missing OR fails validation (pre-v2 format, corrupted, etc):
   - Ask: `Qual é o slug do teu workspace Linear? (ex: salesmart)`. Validate lowercase alphanumeric+hyphens. Save just to memory for this run (not to disk — incomplete config).
   - Ask: `Qual é a key do teu team? (ex: SAL)`. Validate uppercase alphanumeric. Save to memory.
   - Skip team/user/label/project discovery entirely. Generate the draft using ONLY the user's brief and template, no labels, no project, no assignee.
   - Pass `workspaceSlug` and `teamKey` to `save-fallback.sh` and finish.

3. After fallback completes, the skill's Step 8 should append the reminder: `Quando o Linear voltar, roda /issue config reset pra completar o wizard.`. This reconciles with `SKILL.md` Step 8 which permits a single follow-up line in fallback mode.

Do NOT attempt any MCP call after `mode=fallback` is set.

<a id="label-resolution-gotcha"></a>

## Label resolution gotcha (when posting via save_issue)

The MCP `save_issue` tool accepts `labels: string[]`. **Critical behavior**:

- Passing leaf names like `["bug", "frontend"]` works (returns issue with labels populated).
- Passing prefixed names like `["type/bug", "area/frontend"]` **silently fails** — the issue is created with empty labels, no error returned.
- Passing UUIDs always works.

**Rule:** When applying labels, prefer UUIDs from the config file (`config.labels[<name>]`). Fall back to leaf names ONLY if UUID is missing in config. Never use prefixed names.

After `save_issue` returns, verify the response's `labels` array is non-empty if labels were sent. If empty, retry once with leaf names. If still empty, log a warning and continue.

### Mandatory type label safety check (run before posting)

Before calling `save_issue`, the skill MUST resolve `config.labels[<detected-type>]` (where `<detected-type>` is `bug`, `feature`, `tech-debt`, or `spike`). If the resolved value is null or missing:

1. Print a user-visible warning: `⚠ Label de tipo '<detected-type>' não está mapeado no config. Issue vai ser criada SEM o label de tipo. Rode /issue reconfig pra mapear.`
2. Proceed with whatever other labels are available, or with no labels at all.
3. Do NOT silently drop the issue or hide the missing label from the user.

This catches the case where a user with an old config that has `null` for some mandatory label posts an issue — they see the gap explicitly instead of getting a silently-untyped ticket.

<a id="issue-creation-parameters"></a>

## Issue creation parameters

When calling `mcp__linear__save_issue`:

```
{
  "title": "string, max 80 chars, no trailing punctuation",
  "team": "<defaultTeamKey or override>",
  "description": "<rendered template body, plain markdown, no escape sequences>",
  "labels": ["<uuid>", "<uuid>"],
  "project": "<projectId if applicable>",
  "assignee": "me or <uuid> or null",
  "priority": <0|1|2|3|4 — see below>,
  "state": "<state name if explicitly chosen, otherwise omit to use team default>"
}
```

### Priority mapping

| value | name | when to use |
|---|---|---|
| 0 | No priority | default if not inferable |
| 1 | Urgent | bug with severity `Bloqueia`, security issue |
| 2 | High | bug with severity `Degrada`, customer-blocking feature |
| 3 | Normal | most feature/tech-debt |
| 4 | Low | nice-to-have, cosmetic bug |

### Landing state resolution

If `config.defaultLandingState == "triage"`:

1. Call `list_issue_statuses` for the team. Look for a status with `type == "triage"`.
2. If found → set `state` to that status name in the payload.
3. If NOT found → omit `state` (uses team default), and print a one-line warning: `⚠ Triage configurado como padrão mas o team não tem mais um status de tipo 'triage'. Issue foi pro estado default do team. Rode /issue reconfig se quiser ajustar.`

If `config.defaultLandingState == "backlog"` → omit `state` (uses team default).

This makes capability detection a per-run check instead of a persisted boolean.

<a id="anti-actions"></a>

## Anti-actions (operations the skill must never perform)

Even if the user requests them within the same turn, refuse politely and explain the skill's scope:

- Modifying workflow states (creating, deleting, renaming workflow statuses).
- Creating/deleting/renaming labels.
- Modifying project metadata beyond setting `project` on the new issue.
- Modifying team settings.
- Bulk operations (closing many issues, mass-deleting).
- Updating other issues besides the one being created.

For any of these, output: `Essa operação está fora do escopo do linear-issue-creator. Use o Linear UI ou outra skill.`
