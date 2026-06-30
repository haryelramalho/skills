# GPT-5.5 Output Template

## Contents

- Sufficient context
- Missing context
- Final checks

## Sufficient Context

Return only the rewritten prompt. Use this structure unless the user's target format is more specific:

```text
Role: [model role and domain context]

# Goal
[The concrete user-visible outcome.]

# Context
[Only provided or clearly labeled context. Include files, logs, constraints, examples, or source material when relevant.]

# Success criteria
- [Observable requirement]
- [Observable requirement]

# Constraints
- [Evidence, safety, compatibility, style, or side-effect limit]
- [Non-goal when useful]

# Validation
[Checks to run, evidence to verify, or what to report if validation is impossible.]

# Output
[Required structure, language, length, tone, and whether to include assumptions or open questions.]

# Stop rules
[When to ask, abstain, retry, or stop instead of guessing.]
```

## Missing Context

If the request lacks critical context, return only concise questions:

```text
I need these details before I can produce a GPT-5.5-ready prompt:

1. [Question that changes the prompt materially]
2. [Question that changes the prompt materially]
3. [Question that changes the prompt materially]
```

Ask at most five questions. Do not ask for information that can be inferred safely from the user's request.

## Final Checks

- The output is a prompt or missing-context questions, not an explanation of the rewrite.
- The prompt is optimized for GPT-5.5, not Claude.
- Raw context was first normalized with `to-prompt` behavior.
- Runtime/API notes appear only when the user asked for API, agent, tools, or Responses workflow behavior.
