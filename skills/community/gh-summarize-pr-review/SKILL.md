---
name: gh-summarize-pr-review
description: Fetch and summarize review feedback from the open GitHub pull request for the current branch, producing one section per review point with quoted text, code snippet context, links, and referenced images. Use when asked to review PR comments/reviews, build a digest of reviewer concerns, or support decision-making from PR feedback, including prompts like "resumir review do PR atual", "summarize current PR review", and "listar pontos do code review".
---

# PR Review Brief

Create a high-signal summary of PR review feedback with evidence attached to every point.

## Workflow

1. Confirm prerequisites.
- Ensure `gh` is installed and authenticated (`gh auth status`).
- Ensure the current directory is a git repository with an open PR for the active branch.

2. Generate the evidence file.
- Run `scripts/build_pr_review_summary.py` from the skill folder while in the target repository.
- Use defaults first:  
  `python3 /Users/haryelramalho/.agents/skills/gh-summarize-pr-review/scripts/build_pr_review_summary.py`
- Add options only when needed:
  - `--pr <number>` to force a specific PR
  - `--output <path>` to choose markdown output path
  - `--json-output <path>` to export structured data
  - `--context-lines <n>` to change snippet size
  - `--no-include-issue-comments` to focus on review threads only
  - `--include-automation-comments` to include generated bot comments (disabled by default)
  - `--print-markdown` to dump the full markdown report to stdout

3. Deliver the user-facing summary.
- Default response mode: inline in chat.
- Read the generated markdown and return it in chat by default. Do not answer with only file paths.
- If content is long, return in ordered chunks (for example, 10 points per message) and keep markdown headings.
- Only send a summarized version instead of full markdown when the user explicitly asks for summary.
- Present each point with:
  - one concise interpretation of the reviewer concern
  - one direct quote from the original comment/review text
  - code evidence (snippet or diff context)
  - automatic decision impact classification (`Blocker`, `Important`, `Optional`)
  - image/link evidence when present
- Keep the final response organized as numbered points to support decision-making.

4. Handle edge cases explicitly.
- If no open PR is found for the branch, rerun with `--pr`.
- If auth fails, ask the user to run `gh auth login` and retry.
- If a file snippet cannot be loaded, keep the point and use available diff/comment evidence.

## Output Expectations

Ensure each review point includes:
- `Reviewer`, `Date`, `Source link`
- `Summary` (single concise sentence)
- `Decision impact` (`Blocker`, `Important`, or `Optional`) and rationale
- `Quote` from the original feedback
- `Code context` (line-numbered snippet when available)
- `Referenced images` when present in markdown/HTML comments

Read `references/summary-rubric.md` when you need stricter phrasing and decision framing.

Prefer `gh` as the canonical source for review data.
