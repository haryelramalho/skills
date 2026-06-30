# Capture Rules

## Contents

- Purpose
- Classification
- Destination Paths
- Language Policy
- Topic Files
- Note Quality Bar
- Index Maintenance
- Boundaries

## Purpose

Write project documentation for humans. Capture only durable knowledge that should survive beyond the current conversation: concepts, decisions, gotchas, research, and conventions. The result must be readable in a pull request and useful without hidden context.

## Classification

Choose exactly one primary category:

| Category | Use when | Default path |
| --- | --- | --- |
| Concept | The user wants to explain how a domain idea, subsystem, workflow, or mechanism works. | `docs/concepts/<topic>.md` |
| Decision | The user wants to preserve why one option was chosen over alternatives. | `docs/decisions/<topic>.md` |
| Gotcha | The user wants to preserve a trap, surprising behavior, recurring failure, or operational caution. | `docs/gotchas/<topic>.md` |
| Research | The user wants to preserve investigation results, sources, evidence, or comparisons that should not be repeated. | `docs/research/<topic>.md` |
| Convention | The user wants to preserve a recurring project rule, naming practice, workflow rule, or "from now on" practice. | `docs/conventions/<topic>.md` |

Ask one short question when the destination is ambiguous. Examples:

- If it explains how something works, choose `concepts`.
- If it explains why an option won, choose `decisions`.
- If it prevents a known mistake, choose `gotchas`.
- If it preserves evidence from investigation, choose `research`.
- If it defines how the project should behave going forward, choose `conventions`.

## Destination Paths

Use the project's existing documentation convention if it is explicit and compatible with topic docs. Otherwise use:

```text
docs/
  concepts/
  decisions/
  gotchas/
  research/
  conventions/
  index.md
```

Do not create `docs/sessions/`. Chronological session history, handoffs, and scratch notes are not canonical docs.

## Language Policy

Inspect existing docs before writing:

1. If most existing docs use one language, use that language.
2. If docs are mixed but the surrounding topic has a language, use the surrounding topic language.
3. If there are no docs, use the language of the user request.
4. Do not translate project terms, product names, API names, commands, or code identifiers.

## Topic Files

Prefer one topic per file. Before creating a file:

1. Search the target category for an existing topic with the same subject or close synonym.
2. Update the existing file when it already owns the subject.
3. Create a new file only when no existing topic owns it.
4. Use a lowercase hyphenated slug: `payment-retry-policy.md`, not `Payment Retry Policy.md`.
5. Keep topic names stable. Do not rename existing files unless the user asked.

When updating, preserve correct existing content and add the new knowledge in the smallest coherent change. If new information contradicts existing docs, stop and ask before replacing meaning.

## Note Quality Bar

Every note must answer:

- What is being captured?
- Why should a future reader care?
- What was concluded or decided?
- What evidence, example, or trigger supports it?
- What should the reader do differently next time?

Avoid:

- Session diary prose.
- Chat transcript fragments.
- Unverified claims presented as facts.
- Generic project management text.
- Full implementation plans.
- Placeholder text left from templates.

## Index Maintenance

Create `docs/index.md` when it is missing. Keep it short and grouped:

```markdown
# Project Docs

## Concepts

- [Topic title](concepts/topic.md) - One sentence.

## Decisions

- [Topic title](decisions/topic.md) - One sentence.

## Gotchas

- [Topic title](gotchas/topic.md) - One sentence.

## Research

- [Topic title](research/topic.md) - One sentence.

## Conventions

- [Topic title](conventions/topic.md) - One sentence.
```

Add or update only the relevant entry. Do not turn the index into a changelog.

## Boundaries

Use related skills instead of this one when the artifact is not canonical docs:

- Use `grill-with-docs` for glossary-heavy domain discussion or formal decision records.
- Use `handoff` for conversation transfer.
- Use `writing-plans` for implementation plans.

If the user asks to "remember" something without specifying docs, ask whether it belongs in canonical project docs before writing.
