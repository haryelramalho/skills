# GPT-5.5 Prompt Guidance

Source: https://developers.openai.com/api/docs/guides/prompt-guidance

## Contents

- Core pattern
- Prompt shape
- Tool, retrieval, and validation rules
- Runtime notes
- Avoid

## Core Pattern

Prefer concise, outcome-first prompts. GPT-5.5 usually performs better when the prompt defines the target result, relevant evidence, constraints, and final answer shape while leaving room for the model to choose the efficient solution path.

Use this order when it fits the task:

1. Role: the model's job in one or two sentences.
2. Goal: the user-visible outcome.
3. Context: provided facts, artifacts, files, code, logs, or links.
4. Success criteria: what must be true before finalizing.
5. Constraints: safety, evidence, business, style, side effects, or compatibility limits.
6. Validation: checks the receiving model should run or describe.
7. Output: required sections, length, tone, and stop rules.

## Prompt Shape

- Keep each section short; add detail only when it changes behavior.
- Preserve the user's requested artifact, length, structure, and genre before polishing.
- Define personality and collaboration style for customer-facing assistants.
- For grounded answers, specify which claims require source support and how to behave when evidence is missing.
- For creative drafting, separate source-backed facts from creative wording and require placeholders for unsupported specifics.
- For frontend work, include product context, design-system constraints, first-screen expectations, interaction states, responsive behavior, and visual defaults to avoid.

## Tool, Retrieval, and Validation Rules

- Add a retrieval budget when the prompt involves search or evidence gathering: what to search first, when to search again, and when to stop.
- Add tool-use guidance only when the receiving environment has tools or the user asked for an agent workflow.
- For coding agents, request the most relevant validation available: targeted tests, type/lint checks, builds, or a smoke test.
- If validation cannot run, require the model to explain why and name the next best check.
- For visual artifacts, require rendering and inspection before finalizing when the target environment supports it.
- For implementation plans, require traceability: requirements, affected resources, data flow or state transitions when relevant, validation, failure behavior, privacy/security considerations, and material open questions.

## Runtime Notes

Include runtime notes only when the user asks for API, agent, or Responses workflow guidance.

- Re-evaluate low or medium reasoning effort before escalating; do not reflexively request maximum effort.
- For tool-heavy Responses workflows, preserve assistant-item phase values when replaying assistant items.
- Use preambles when the product needs user-visible progress around tool work.
- Do not generate full API payloads unless the user asks for payloads.

## Avoid

- Do not carry over old process-heavy prompt stacks by default.
- Do not add chain-of-thought or hidden reasoning requests.
- Do not add unsupported product, customer, metric, roadmap, or capability claims.
- Do not over-specify the implementation path unless the user explicitly wants a plan or exact procedure.
