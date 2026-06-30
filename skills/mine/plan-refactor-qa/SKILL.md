---
name: plan-refactor-qa
description: Plans and runs qa-report before executing Compozy refactor tasks. Use when the user provides a refactor or issue slug and wants Codex to inspect the matching .compozy/tasks directory, related PRD/TechSpec/ADR/task artifacts, affected code, and existing tests, then invoke $qa-report with a repository-grounded prompt. Do not use to run tests, execute qa-execution, implement code, or perform post-refactor verification.
---

# Plan Refactor QA

## Overview

Prepare and execute the `$qa-report` planning step before a refactor is implemented. Treat this as a two-part handoff: inspect the local task artifacts and current repository surface, build a concise prompt for `qa-report`, then invoke `qa-report` so it creates the QA planning artifacts.

## Input Contract

Require one slug identifying the refactor task directory:

```text
$plan-refactor-qa <slug>
```

Resolve the slug to:

```text
.compozy/tasks/<slug>
```

Use that resolved task directory as the `qa-report` output path. Since `qa-report` creates a `qa/` subdirectory inside its output path, the resulting artifacts must land under:

```text
.compozy/tasks/<slug>/qa/
```

Do not use the repository root, `.`, or a bare `qa/` directory as the output path.

If the directory does not exist, list close matches under `.compozy/tasks/` and ask the user to confirm the intended slug. Do not guess when multiple plausible matches exist.

## Workflow

### 1. Read Local Instructions

Read repository guidance before inspecting the refactor:

- `AGENTS.md`
- `CLAUDE.md` if present and not a duplicate symlink already covered
- project docs that define local command wrappers, verification policy, or ignored artifact paths

Use these only to shape the generated prompt. Do not run verification gates.

### 2. Inspect Compozy Artifacts

Read the refactor directory directly:

- `_prd.md` when present
- `_techspec.md` when present
- `_tasks.md` and `task_*.md` when present
- `adrs/*.md` when present
- `reviews-*` summaries only when they materially affect the refactor scope
- any local memory or notes inside the task directory when they clarify scope

If the refactor directory references a PRD, TechSpec, ADR, or parent task outside the slug directory, follow that explicit reference. Keep the traversal shallow and cite the discovered source path in the generated prompt.

### 3. Discover Affected Surface

Use local code search only. Prefer `rg` and `rg --files`; do not use web search for repository code.

Identify:

- public contracts: APIs, CLIs, events, jobs, schemas, migrations, config, exported types
- domain/application behavior expected to remain stable
- persistence, cache, queue, event, or async boundaries
- external integrations or generated artifacts
- unit, integration, E2E, and smoke tests already covering the area
- related fixtures, builders, factories, and helpers

Search from concrete names found in the task artifacts, not broad generic terms.

### 4. Classify Regression Risk

Classify the refactor risk areas without proposing implementation details:

- calculation or aggregation
- API or CLI contract
- persistence and migrations
- cache keys or invalidation
- event handling, queueing, or background jobs
- date/time semantics
- filtering, sorting, pagination, grouping, or scoping
- authorization, permissions, tenancy, or user identity
- idempotency, retry, deduplication, or replay
- integration with external systems
- frontend, browser, or visual behavior
- test fixture realism and automation gaps

Mark business-critical or public-surface flows as P0/P1 candidates for QA planning.

### 5. Build the qa-report Prompt

Build an internal prompt for `qa-report`. The prompt must start with:

```text
$qa-report .compozy/tasks/<slug>
```

The prompt must ask `qa-report` to create:

- a regression-focused test plan
- a regression suite split into Smoke, Targeted, Full, and Sanity
- P0/P1 test cases for critical flows
- explicit automation annotations
- coverage gaps as gaps, not confirmed bugs

For each planned case, require:

- `Priority`: P0, P1, P2, or P3
- `Automation Target`: Unit, Integration, E2E, or Manual-only
- `Automation Status`: Existing, Missing, Blocked, or N/A
- `Automation Command/Spec` when known
- `Automation Notes` explaining Missing or Blocked states

Include instructions that `qa-report` must not execute tests, alter code, run the refactor, or create bug reports unless it finds a clear documentation inconsistency.

Use the repository's discovered command style in examples. If the repo requires a wrapper command, include it. If no local command convention is discovered, avoid inventing commands and ask `qa-report` to infer commands from repository docs.

### 6. Invoke qa-report

Invoke `$qa-report` with the generated prompt and the same output path:

```text
.compozy/tasks/<slug>
```

Replace `<slug>` with the actual slug before invoking. Let `qa-report` execute its own workflow and write artifacts under `.compozy/tasks/<slug>/qa/`. Do not stop after showing the prompt.

If `$qa-report` is unavailable in the current environment, report that blocker and include the generated prompt as a fallback. Only expose the generated prompt in that blocked case or when the user explicitly asks to see it.

## Output Format

Respond in English unless the user explicitly asks for another language.

Use this structure:

- `Understood Scope:` followed by a short summary.
- `qa-report Result:` followed by the artifact paths created or updated by `qa-report`.
- `Coverage Gaps:` followed by the main gaps reported by `qa-report`, or `None reported.`
- `Blocked Items:` followed by any missing inputs, ambiguous slug, unavailable skill, or environment blocker, or `None.`

Do not include the internal `qa-report` prompt in the final answer unless execution was blocked or the user explicitly requested it.

## Boundaries

Do not:

- run `$qa-execution`
- run tests or verification gates
- edit repository code
- create QA artifacts manually outside the `$qa-report` workflow
- propose refactor implementation steps
- use web search for local code

If the user explicitly asks for prompt-only mode, stop before invoking `$qa-report` and output the generated prompt.

## Error Handling

- Missing `.compozy/tasks/`: report that the repository does not expose the expected Compozy task root and ask for the correct task directory.
- Missing slug directory: list close matches from `.compozy/tasks/` and ask for confirmation before continuing.
- Multiple plausible slugs: stop and ask the user to choose one slug.
- Missing `qa-report`: report the unavailable skill and provide the generated prompt as a fallback.
- Missing PRD, TechSpec, ADRs, or task files: proceed from the artifacts that exist, but state the missing artifact as an assumption in the `qa-report` prompt.
- No existing automated tests found for the affected surface: tell `qa-report` to mark the relevant cases as `Automation Status: Missing` or `Blocked`, not as confirmed bugs.
