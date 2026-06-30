---
name: knowledge-capture
description: Use when preserving human-readable project knowledge in docs, including durable concepts, decisions, gotchas, research, or conventions. Don't use for implementation plans, PRDs, session handoffs, transient scratch notes, or agent memory.
---

# Knowledge Capture

Capture durable project knowledge as human-readable Markdown under `docs/`. Treat project docs as the canonical source; do not write session logs or runtime memory artifacts.

## Required Reading Router

Match the requested capture to the row. Read the listed files in full before producing or editing project docs. They are load-bearing, not appendices.

| Task | MUST read |
| --- | --- |
| Explain a durable domain, system, or mechanism concept | `references/capture-rules.md` + `assets/concept-template.md` |
| Record a choice, tradeoff, rejected option, or rationale | `references/capture-rules.md` + `assets/decision-template.md` |
| Preserve a known trap, failure mode, surprising behavior, or operational caution | `references/capture-rules.md` + `assets/gotcha-template.md` |
| Save research, evidence, sources, or investigation results that should not be repeated | `references/capture-rules.md` + `assets/research-template.md` |
| Record a project convention, recurring rule, or "from now on" practice | `references/capture-rules.md` + `assets/convention-template.md` |

## Reference Index

- `references/capture-rules.md`: classification, destination paths, update rules, language policy, quality bar, and index maintenance.
- `assets/concept-template.md`: template for `docs/concepts/<topic>.md`.
- `assets/decision-template.md`: template for `docs/decisions/<topic>.md`.
- `assets/gotcha-template.md`: template for `docs/gotchas/<topic>.md`.
- `assets/research-template.md`: template for `docs/research/<topic>.md`.
- `assets/convention-template.md`: template for `docs/conventions/<topic>.md`.
- `scripts/check-doc-note.py`: read-only validator for generated or updated note files.

## Procedure

1. Confirm the request is a capture request.
   - Proceed when the user explicitly asks to document, register, preserve, save, or record durable project knowledge.
   - If another skill recommends capture, ask for confirmation before writing.
   - Decline this skill for implementation plans, PRDs, handoffs, transient scratch notes, and session logs.

2. Inspect existing documentation.
   - Check whether `docs/` exists and whether the project already has a clear documentation convention.
   - Use the existing convention when it is explicit and compatible with human-readable topic docs.
   - Otherwise use the default directories: `docs/concepts/`, `docs/decisions/`, `docs/gotchas/`, `docs/research/`, `docs/conventions/`, and `docs/index.md`.
   - Detect the dominant language of existing docs. If there are no docs, use the language of the request.

3. Classify the capture.
   - Use exactly one primary destination.
   - If two categories are plausible and the destination changes the result, ask one short question before writing.
   - Do not create `docs/sessions/` or session-style chronology.
   - **STOP. Read `references/capture-rules.md` in full before creating or updating any project doc.** The bullets above are routing tripwires, not the contract.

4. Load the matching template.
   - Concept: **STOP. Read `assets/concept-template.md` in full before writing `docs/concepts/<topic>.md`.**
   - Decision: **STOP. Read `assets/decision-template.md` in full before writing `docs/decisions/<topic>.md`.**
   - Gotcha: **STOP. Read `assets/gotcha-template.md` in full before writing `docs/gotchas/<topic>.md`.**
   - Research: **STOP. Read `assets/research-template.md` in full before writing `docs/research/<topic>.md`.**
   - Convention: **STOP. Read `assets/convention-template.md` in full before writing `docs/conventions/<topic>.md`.**

5. Create or update one topic file.
   - Prefer one topic per file.
   - Use a lowercase hyphenated slug.
   - Search for an existing matching topic before creating a new file.
   - Update the existing topic file when it already covers the subject.
   - Keep the note useful to a human reviewer without conversation history.

6. Update `docs/index.md`.
   - Create it when missing.
   - Keep it as a short map grouped by `concepts`, `decisions`, `gotchas`, `research`, and `conventions`.
   - Link the topic file from the relevant group.

7. Validate before finalizing.
   - Resolve `<knowledge-capture-dir>` to the directory containing this `SKILL.md`.
   - Run the read-only helper: `python3 <knowledge-capture-dir>/scripts/check-doc-note.py <path-to-note>`.
   - Fix reported path, section, or placeholder errors and rerun until it passes.

## Related Skills

- Use `grill-with-docs` when the capture needs glossary sharpening or a formal decision record.
- Use `handoff` when the user needs another conversation to continue work.
- Use `writing-plans` when the content is an implementation plan rather than canonical project documentation.

## Error Handling

- If the project has no `docs/`, create only the needed directory and `docs/index.md`.
- If the target topic already exists but conflicts with the new information, surface the conflict and ask before overwriting meaning.
- If source evidence is unavailable for a research note, mark the missing evidence explicitly instead of inventing sources.
- If validation fails, treat the validator output as the correction checklist.
