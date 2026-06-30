---
name: to-prompt-gpt
description: Use when preparing or rewriting prompts for GPT-5.5, OpenAI API agents, Responses workflows, coding agents, research synthesis, support assistants, or model-specific prompt optimization. Do not use for Claude/Opus prompts or raw context packaging without GPT-specific tuning.
---

# To Prompt GPT

Transform a user request, rough context, or existing prompt into a GPT-5.5-ready prompt.

## Required Reading Router

Match the task to every applicable row. Read the listed files **in full before** producing output. They are load-bearing; inline guidance is only a router.

| Task | MUST read |
| --- | --- |
| Any GPT-5.5 prompt rewrite | `references/gpt-5.5-guidance.md` + `references/output-template.md` |
| Raw, incomplete, or issue-like context | Apply `to-prompt` behavior first, then read `references/gpt-5.5-guidance.md` + `references/output-template.md` |
| OpenAI API, Responses, tool, retrieval, validation, or runtime prompt | `references/gpt-5.5-guidance.md` |
| Missing critical context | `references/output-template.md` |

## Reference Index

- `references/gpt-5.5-guidance.md`: GPT-5.5-specific prompt-shaping rules from OpenAI guidance.
- `references/output-template.md`: Final prompt template and missing-context question format.

## Operating Procedure

1. Classify the input as raw context, structured prompt, or blocked by missing context.
   - Raw context includes bugs, issues, repo notes, scattered requirements, logs, or code snippets.
   - Structured prompts already contain goal, context, constraints, and output requirements.
   - Blocked requests lack the target task, audience, source material, or success criteria.
   **STOP. Read `references/output-template.md` in full before deciding whether to ask questions or produce the final prompt.** The bullets above are tripwires, not the output contract.

2. For raw context, first apply `to-prompt` behavior without force-loading it: gather problem, current state, requirements, constraints, evidence, files, logs, tests, and success criteria. Do not add implementation advice unless the user explicitly asks the receiving model to propose an implementation.

3. Refine for GPT-5.5.
   - Make the prompt outcome-first.
   - Remove process-heavy scaffolding that does not change behavior.
   - Add validation, grounding, retrieval, tool, or runtime instructions only when relevant to the target task.
   **STOP. Read `references/gpt-5.5-guidance.md` in full before writing the final GPT-5.5 prompt.** These bullets are tripwires, not the source of truth.

4. Produce only the final artifact.
   - If context is sufficient, output the prompt and no commentary.
   - If context is insufficient, output concise questions and no speculative prompt.
   - Preserve the user's language unless the user asks for another language.
   **STOP. Read `references/output-template.md` in full before formatting the final answer.** The template file is the contract.

## Error Handling

- If the user asks for Claude, Opus, Anthropic, or XML-first prompting, stop and use `to-prompt-opus` instead.
- If the request only asks for neutral context packaging, use `to-prompt` instead.
- If official model guidance is needed and may have changed, verify the current OpenAI documentation before relying on cached rules.
