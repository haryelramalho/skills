# Claude Opus 4.8 Prompt Guidance

Sources:

- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices#general-principles
- https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-8

## Contents

- Core pattern
- Literal scope and structure
- Tool, subagent, and runtime rules
- Frontend and design rules
- Code review, coding, and long-context rules
- Avoid

## Core Pattern

Claude Opus 4.8 is strong on long-horizon agentic work, coding, complex reasoning, knowledge work, vision, and memory. It performs well on existing prior-Opus prompts, but its behavior is more literal and its runtime controls matter more.

When API/runtime details are relevant, the API model ID is `claude-opus-4-8`.

Prompts should state the task scope, output contract, and applicability of instructions directly. If a rule applies globally, say so.

Use XML tags when they clarify boundaries:

```text
<goal>...</goal>
<context>...</context>
<documents>...</documents>
<constraints>...</constraints>
<success_criteria>...</success_criteria>
<output_format>...</output_format>
```

Do not use XML mechanically for tiny prompts. Use it when there are multiple artifacts, long context, examples, tool rules, or format-sensitive outputs.

## Literal Scope and Structure

- Say exactly where each instruction applies. If a formatting or review rule applies everywhere, state that it applies to every section or every file, not only the first example.
- Control verbosity directly when the product needs a specific length or tone.
- Add tone guidance when needed; Opus 4.8 can be direct and opinionated by default.
- Prefer positive examples over long negative lists when steering writing style.
- For long-context prompts, mark sources, document boundaries, and the job each source should perform.
- For complex multi-document inputs, put long documents and data before the query and instructions; put the actual query near the end.

## Tool, Subagent, and Runtime Rules

Include runtime notes only when the user asks for API, agent, tool, or managed-runtime guidance.

- Claude Opus 4.8 defaults to `high` effort. For coding and agentic work, prefer `xhigh` when runtime guidance is requested and quality matters.
- `thinking: {"type": "adaptive"}` is the only supported thinking-on mode; thinking is off unless explicitly enabled.
- If shallow reasoning appears on complex work, raise effort before trying to prompt around it.
- If the prompt needs more tool use, explicitly describe when and how tools should be used. Higher effort can increase useful tool usage.
- Claude Opus 4.8 tends to spawn fewer subagents by default; state when to work directly and when to fan out.
- Do not force progress-update scaffolding unless the product needs a specific update style.
- Do not generate full API payloads unless the user asks for payloads.
- Do not use non-default `temperature`, `top_p`, or `top_k`; use prompting to guide behavior instead.

## Frontend and Design Rules

Add design guidance only for frontend, presentation, visual, or product-surface tasks.

- State the domain, audience, and product context.
- Claude Opus 4.8 has a persistent warm editorial default: cream/off-white backgrounds, serif display type, italic accents, and terracotta/amber accents. Specify a concrete alternative when that style is wrong.
- For dashboards, dev tools, fintech, healthcare, and enterprise apps, explicitly require utilitarian information density, restrained styling, predictable controls, and scan-friendly layouts.
- For creative visual tasks, ask for distinct visual directions first when the user has not chosen one.
- For frontend variety, ask for multiple visual directions before implementation when the user has not chosen a direction.

## Code Review, Coding, and Long-Context Rules

- For code review harnesses, define whether the model should optimize for coverage or only high-severity findings. If coverage matters, tell it to report uncertain and low-severity findings for downstream filtering.
- For interactive coding products, ask for well-specified first-turn task descriptions, constraints, and validation expectations to reduce follow-up token churn.
- For long agentic traces, mention compaction recovery expectations when continuity matters.
- For large output budgets at `xhigh` or `max` effort, include enough max output headroom when runtime guidance is requested.

## Avoid

- Do not assume Opus 4.8 will generalize one example to all sections unless the prompt says so.
- Do not overuse XML for simple one-shot prompts.
- Do not use temperature/top-p/top-k style guidance for Opus 4.8 runtime prompts.
- Do not add hidden chain-of-thought requests.
- Do not invent missing facts, files, metrics, owners, or source claims.
