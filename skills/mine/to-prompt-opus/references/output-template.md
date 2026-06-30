# Claude Opus 4.8 Output Template

## Contents

- Sufficient context
- Missing context
- Final checks

## Sufficient Context

Return only the rewritten prompt. Use XML when it clarifies boundaries; otherwise use short Markdown sections.

```text
You are [role and domain context].

<goal>
[The concrete user-visible outcome.]
</goal>

<context>
[Only provided or clearly labeled context. Include files, logs, constraints, examples, source material, or document summaries when relevant.]
</context>

<success_criteria>
- [Observable requirement]
- [Observable requirement]
</success_criteria>

<constraints>
- [Evidence, safety, compatibility, style, side-effect, or scope limit]
- [Non-goal when useful]
</constraints>

<tool_guidance>
[When to use tools, when not to, and validation expectations. Omit this block when tools are irrelevant.]
</tool_guidance>

<output_format>
[Required structure, language, length, tone, and handling of assumptions or open questions.]
</output_format>
```

## Missing Context

If the request lacks critical context, return only concise questions:

```text
I need these details before I can produce a Claude Opus 4.8-ready prompt:

1. [Question that changes the prompt materially]
2. [Question that changes the prompt materially]
3. [Question that changes the prompt materially]
```

Ask at most five questions. Do not ask for information that can be inferred safely from the user's request.

## Final Checks

- The output is a prompt or missing-context questions, not an explanation of the rewrite.
- The prompt is optimized for Claude Opus 4.8, not GPT.
- Raw context was first normalized with `to-prompt` behavior.
- XML tags are used because they improve boundaries, not because every Opus prompt needs XML.
- Runtime/API notes appear only when the user asked for API, agent, tools, effort, adaptive-thinking, or long-context behavior.
