---
name: to-prompt-opus
description: Use when preparing or rewriting prompts for Claude Opus 4.8, Anthropic API agents, XML-structured prompts, long-context document work, coding agents, research synthesis, frontend/design tasks, or model-specific prompt optimization. Do not use for GPT/OpenAI prompts or raw context packaging without Opus-specific tuning.
---

# To Prompt Opus

Transform a user request, rough context, or existing prompt into a Claude Opus 4.8-ready prompt.

## Required Reading Router

Match the task to every applicable row. Read the listed files **in full before** producing output. They are load-bearing; inline guidance is only a router.

| Task | MUST read |
| --- | --- |
| Any Claude Opus 4.8 prompt rewrite | `references/opus-4.8-guidance.md` + `references/output-template.md` |
| Raw, incomplete, or issue-like context | Apply `to-prompt` behavior first, then read `references/opus-4.8-guidance.md` + `references/output-template.md` |
| XML, long-context, coding, frontend/design, tool, subagent, or runtime prompt | `references/opus-4.8-guidance.md` |
| Missing critical context | `references/output-template.md` |

## Reference Index

- `references/opus-4.8-guidance.md`: Claude Opus 4.8-specific prompt-shaping rules from Anthropic guidance.
- `references/output-template.md`: Final prompt template and missing-context question format.

## Operating Procedure

1. Classify the input as raw context, structured prompt, or blocked by missing context.
   - Raw context includes bugs, issues, repo notes, scattered requirements, logs, or code snippets.
   - Structured prompts already contain goal, context, constraints, and output requirements.
   - Blocked requests lack the target task, audience, source material, or success criteria.
   **STOP. Read `references/output-template.md` in full before deciding whether to ask questions or produce the final prompt.** The bullets above are tripwires, not the output contract.

2. For raw context, first apply `to-prompt` behavior without force-loading it: gather problem, current state, requirements, constraints, evidence, files, logs, tests, and success criteria. Do not add implementation advice unless the user explicitly asks the receiving model to propose an implementation.

3. Refine for Claude Opus 4.8.
   - State scope literally and explicitly.
   - Use XML tags for complex context, documents, examples, or output contracts when helpful.
   - Add tool, subagent, frontend/design, effort, adaptive-thinking, or long-context guidance only when relevant to the target task.
   **STOP. Read `references/opus-4.8-guidance.md` in full before writing the final Opus prompt.** These bullets are tripwires, not the source of truth.

4. Produce only the final artifact.
   - If context is sufficient, output the prompt and no commentary.
   - If context is insufficient, output concise questions and no speculative prompt.
   - Preserve the user's language unless the user asks for another language.
   **STOP. Read `references/output-template.md` in full before formatting the final answer.** The template file is the contract.

## Error Handling

- If the user asks for GPT, OpenAI, Responses, or GPT-specific prompting, stop and use `to-prompt-gpt` instead.
- If the request only asks for neutral context packaging, use `to-prompt` instead.
- If official model guidance is needed and may have changed, verify the current Anthropic documentation before relying on cached rules.
