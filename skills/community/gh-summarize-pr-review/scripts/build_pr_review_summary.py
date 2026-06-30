#!/usr/bin/env python3
"""Build an evidence-rich summary of review points for a GitHub pull request."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

CODE_FENCE_RE = re.compile(r"```.*?```", re.DOTALL)
INLINE_CODE_RE = re.compile(r"`([^`]+)`")
LINK_RE = re.compile(r"\[([^\]]+)\]\([^)]+\)")
HTML_TAG_RE = re.compile(r"<[^>]+>")
MULTI_SPACE_RE = re.compile(r"\s+")
IMAGE_MARKDOWN_RE = re.compile(r"!\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
IMAGE_HTML_RE = re.compile(r"<img[^>]+src=[\"']([^\"']+)[\"']", re.IGNORECASE)
HEADING_RE = re.compile(r"^(#{3,6})\s+(.+?)\s*$")
NUMBERED_ITEM_RE = re.compile(r"^\s*(\d+)[\.\)]\s+(.+?)\s*$")

EXTENSION_TO_LANGUAGE = {
    ".c": "c",
    ".cpp": "cpp",
    ".cs": "csharp",
    ".css": "css",
    ".go": "go",
    ".html": "html",
    ".java": "java",
    ".js": "javascript",
    ".json": "json",
    ".kt": "kotlin",
    ".md": "markdown",
    ".php": "php",
    ".py": "python",
    ".rb": "ruby",
    ".rs": "rust",
    ".scala": "scala",
    ".sh": "bash",
    ".sql": "sql",
    ".swift": "swift",
    ".ts": "typescript",
    ".tsx": "tsx",
    ".vue": "vue",
    ".xml": "xml",
    ".yaml": "yaml",
    ".yml": "yaml",
}

GENERIC_SECTION_TITLES = {
    "issues",
    "issue list",
    "observations",
    "summary",
    "critical",
    "architecture issues",
    "minor observations",
    "bugs",
    "bugs/correctness",
    "bugs / correctness",
    "bugs / correctness issues",
}

AUTOMATION_BODY_MARKERS = (
    "python-coverage-comment-action",
    "coverage report",
    "<!-- this comment was produced by",
    "all checks have passed",
    "codecov",
    "danger report",
)

BLOCKER_RULES: list[tuple[re.Pattern[str], str]] = [
    (
        re.compile(r"\b(blocker|critical)\b|\[(high|critical)\]", re.IGNORECASE),
        "Contains an explicit high-severity marker.",
    ),
    (
        re.compile(
            r"\b(bug|regression|data corruption|silent data|security|vulnerability)\b",
            re.IGNORECASE,
        ),
        "Describes a correctness or safety risk.",
    ),
    (
        re.compile(
            r"\b(crash|exception|traceback|attributeerror|typeerror|runtime error)\b",
            re.IGNORECASE,
        ),
        "Mentions a runtime failure risk.",
    ),
    (
        re.compile(r"\bbefore merg\w*|\bcannot merg\w*|\bmust fix\b", re.IGNORECASE),
        "Indicates merge should wait for a fix.",
    ),
]

IMPORTANT_RULES: list[tuple[re.Pattern[str], str]] = [
    (
        re.compile(
            r"\b(important|should|needs|missing test|coverage|architecture|design|maintainability)\b",
            re.IGNORECASE,
        ),
        "Requests a meaningful change in behavior, quality, or design.",
    ),
    (
        re.compile(
            r"\b(dead code|breaking change|dependency injection|untestable|performance)\b",
            re.IGNORECASE,
        ),
        "Highlights a structural or maintainability concern.",
    ),
]

OPTIONAL_RULES: list[tuple[re.Pattern[str], str]] = [
    (
        re.compile(r"\b(minor|nit|style|wording|docs|documentation)\b", re.IGNORECASE),
        "Describes a minor or stylistic improvement.",
    ),
    (
        re.compile(r"\b(optional|nice to have|consider|could)\b", re.IGNORECASE),
        "Suggests an improvement that can be deferred.",
    ),
]


class CommandError(RuntimeError):
    """Represent a failed external command."""


@dataclass
class ReviewPoint:
    """Represent one actionable review point."""

    point_id: str
    category: str
    reviewer: str
    created_at: str
    source_url: str
    summary: str
    quote: str
    decision_impact: str = "Important"
    decision_rationale: str = "Requires a meaningful change before merge."
    title: str | None = None
    path: str | None = None
    line: int | None = None
    review_state: str | None = None
    images: list[str] = field(default_factory=list)
    snippet: str | None = None
    snippet_start: int | None = None
    snippet_end: int | None = None
    diff_hunk: str | None = None


def run_command(args: list[str], cwd: Path | None = None) -> str:
    """Run a command and return stdout, raising on failure."""

    completed = subprocess.run(
        args,
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        stderr = completed.stderr.strip()
        joined = " ".join(args)
        raise CommandError(f"Command failed ({joined}): {stderr}")
    return completed.stdout.strip()


def run_json_command(args: list[str], cwd: Path | None = None) -> Any:
    """Run a command returning JSON output."""

    stdout = run_command(args, cwd=cwd)
    if not stdout:
        return []
    try:
        return json.loads(stdout)
    except json.JSONDecodeError as exc:
        joined = " ".join(args)
        raise CommandError(f"Invalid JSON output from command ({joined})") from exc


def get_repo_root() -> Path:
    """Return the repository root path."""

    return Path(run_command(["git", "rev-parse", "--show-toplevel"])).resolve()


def get_current_branch(repo_root: Path) -> str:
    """Return the current branch name."""

    return run_command(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=repo_root)


def resolve_pr_number(repo_root: Path, explicit_number: int | None) -> int:
    """Resolve PR number from the current branch when not explicitly provided."""

    if explicit_number is not None:
        return explicit_number

    branch = get_current_branch(repo_root)
    prs = run_json_command(
        [
            "gh",
            "pr",
            "list",
            "--head",
            branch,
            "--state",
            "open",
            "--limit",
            "20",
            "--json",
            "number",
        ],
        cwd=repo_root,
    )
    if not prs:
        raise CommandError(
            f"No open pull request found for branch '{branch}'. "
            "Pass --pr <number> to select a PR explicitly."
        )
    return int(prs[0]["number"])


def fetch_api_pages(repo_root: Path, endpoint: str, max_pages: int) -> list[dict[str, Any]]:
    """Fetch paginated JSON arrays from gh api."""

    items: list[dict[str, Any]] = []
    for page in range(1, max_pages + 1):
        separator = "&" if "?" in endpoint else "?"
        page_endpoint = f"{endpoint}{separator}per_page=100&page={page}"
        payload = run_json_command(["gh", "api", page_endpoint], cwd=repo_root)
        if not isinstance(payload, list):
            raise CommandError(f"Expected list response for endpoint '{endpoint}'")
        if not payload:
            break
        items.extend(payload)
        if len(payload) < 100:
            break
    return items


def strip_markdown(text: str) -> str:
    """Produce plain text from markdown-rich comments."""

    value = CODE_FENCE_RE.sub(" ", text)
    value = INLINE_CODE_RE.sub(r"\1", value)
    value = LINK_RE.sub(r"\1", value)
    value = value.replace("#", " ")
    value = HTML_TAG_RE.sub(" ", value)
    value = value.replace("\r", " ").replace("\n", " ")
    value = MULTI_SPACE_RE.sub(" ", value)
    return value.strip()


def summarize_text(text: str, max_length: int = 220) -> str:
    """Generate a short summary sentence from the original review text."""

    plain = strip_markdown(text)
    if not plain:
        return "No textual feedback provided."

    first_sentence = re.split(r"(?<=[.!?])\s+", plain, maxsplit=1)[0]
    summary = first_sentence if len(first_sentence) >= 24 else plain
    if len(summary) > max_length:
        return summary[: max_length - 1].rstrip() + "..."
    return summary


def extract_images(text: str) -> list[str]:
    """Extract image URLs from markdown and HTML comments."""

    urls: list[str] = []
    seen: set[str] = set()
    for pattern in (IMAGE_MARKDOWN_RE, IMAGE_HTML_RE):
        for match in pattern.findall(text):
            url = match.strip()
            if url and url not in seen:
                seen.add(url)
                urls.append(url)
    return urls


def format_quote(text: str, max_chars: int = 1200) -> str:
    """Render text as a blockquote."""

    body = text.strip()
    if not body:
        return "> (no quote available)"
    if len(body) > max_chars:
        body = body[: max_chars - 1].rstrip() + "..."
    return "\n".join("> " + line if line else ">" for line in body.splitlines())


def normalize_title(raw_title: str) -> str:
    """Normalize markdown heading/list titles into plain labels."""

    title = INLINE_CODE_RE.sub(r"\1", raw_title)
    title = re.sub(r"^\s*\d+[\.\)]\s*", "", title)
    title = title.strip().strip("*`")
    title = MULTI_SPACE_RE.sub(" ", title)
    return title


def split_text_into_points(text: str) -> list[tuple[str | None, str]]:
    """Split a large review comment into multiple actionable point blocks."""

    lines = text.splitlines()
    heading_matches: list[tuple[int, int, str]] = []
    for index, line in enumerate(lines):
        match = HEADING_RE.match(line.strip())
        if match:
            heading_matches.append((index, len(match.group(1)), normalize_title(match.group(2))))

    for level in (6, 5, 4, 3):
        level_matches = [item for item in heading_matches if item[1] == level]
        if len(level_matches) < 2:
            continue
        sections: list[tuple[str | None, str]] = []
        for start_index, _, title in level_matches:
            next_index = len(lines)
            for boundary_index, boundary_level, _ in heading_matches:
                if boundary_index <= start_index:
                    continue
                if boundary_level <= level:
                    next_index = boundary_index
                    break
            body = "\n".join(lines[start_index + 1 : next_index]).strip()
            if not body:
                continue
            if title.lower() in GENERIC_SECTION_TITLES:
                continue
            sections.append((title, body))
        if sections:
            return sections

    numbered_matches: list[tuple[int, str]] = []
    for index, line in enumerate(lines):
        match = NUMBERED_ITEM_RE.match(line.strip())
        if match:
            numbered_matches.append((index, normalize_title(match.group(2))))
    if len(numbered_matches) >= 2:
        sections = []
        for position, (start_index, title) in enumerate(numbered_matches):
            next_index = (
                numbered_matches[position + 1][0]
                if position + 1 < len(numbered_matches)
                else len(lines)
            )
            body = "\n".join(lines[start_index + 1 : next_index]).strip()
            if body:
                sections.append((title, body))
        if sections:
            return sections

    fallback = text.strip()
    if not fallback:
        return []
    return [(None, fallback)]


def is_automation_comment(reviewer: str, body: str) -> bool:
    """Detect generated bot comments that are typically noisy for human review summaries."""

    reviewer_lower = reviewer.lower()
    body_lower = body.lower()
    if any(marker in body_lower for marker in AUTOMATION_BODY_MARKERS):
        return True
    if reviewer_lower.endswith("[bot]") and "coverage" in body_lower and "img.shields.io" in body_lower:
        return True
    return False


def format_image_links(images: list[str], max_images: int = 8) -> str:
    """Format image links while avoiding unbounded output."""

    if not images:
        return ""
    selected = images[:max_images]
    links = ", ".join(
        f"[image {index}]({url})" for index, url in enumerate(selected, start=1)
    )
    remaining = len(images) - len(selected)
    if remaining > 0:
        return f"{links}, +{remaining} more"
    return links


def match_first_rule(
    text: str, rules: list[tuple[re.Pattern[str], str]]
) -> str | None:
    """Return the first matching rule reason for the given text."""

    for pattern, reason in rules:
        if pattern.search(text):
            return reason
    return None


def classify_decision_impact(point: ReviewPoint) -> tuple[str, str]:
    """Classify one review point into Blocker, Important, or Optional."""

    state = (point.review_state or "").upper().strip()
    if state == "CHANGES_REQUESTED":
        return "Blocker", "Review state is CHANGES_REQUESTED."

    analysis_text = " ".join(
        filter(
            None,
            [
                point.title or "",
                point.summary,
                strip_markdown(point.quote)[:3200],
            ],
        )
    )

    blocker_reason = match_first_rule(analysis_text, BLOCKER_RULES)
    if blocker_reason:
        return "Blocker", blocker_reason

    important_reason = match_first_rule(analysis_text, IMPORTANT_RULES)
    optional_reason = match_first_rule(analysis_text, OPTIONAL_RULES)

    if important_reason:
        return "Important", important_reason
    if optional_reason:
        return "Optional", optional_reason

    if point.category == "inline_comment":
        return "Important", "Inline review feedback usually requires an explicit decision."

    return "Important", "Requires a meaningful change or explicit acceptance decision."


def detect_language(path: str | None) -> str:
    """Infer markdown code fence language from file extension."""

    if not path:
        return "text"
    extension = Path(path).suffix.lower()
    return EXTENSION_TO_LANGUAGE.get(extension, "text")


def read_snippet(
    repo_root: Path,
    relative_path: str,
    line_number: int,
    context_lines: int,
) -> tuple[str | None, int | None, int | None]:
    """Read line-numbered code context around a comment location."""

    target_path = (repo_root / relative_path).resolve()
    try:
        target_path.relative_to(repo_root)
    except ValueError:
        return None, None, None

    if not target_path.is_file():
        return None, None, None

    try:
        lines = target_path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        lines = target_path.read_text(encoding="utf-8", errors="replace").splitlines()

    if not lines:
        return None, None, None

    safe_line = min(max(line_number, 1), len(lines))
    start = max(1, safe_line - context_lines)
    end = min(len(lines), safe_line + context_lines)
    snippet_lines = [f"{index:>4} | {lines[index - 1]}" for index in range(start, end + 1)]
    return "\n".join(snippet_lines), start, end


def build_review_points(
    repo_root: Path,
    pr_info: dict[str, Any],
    reviews: list[dict[str, Any]],
    inline_comments: list[dict[str, Any]],
    issue_comments: list[dict[str, Any]],
    context_lines: int,
    include_issue_comments: bool,
    include_author_comments: bool,
    include_automation_comments: bool,
) -> list[ReviewPoint]:
    """Create normalized review points from GitHub API payloads."""

    review_state_by_id: dict[int, str] = {
        int(review["id"]): str(review.get("state", "")).strip()
        for review in reviews
        if review.get("id") is not None
    }

    points: list[ReviewPoint] = []
    for comment in inline_comments:
        body = str(comment.get("body", "")).strip()
        reviewer = str(comment.get("user", {}).get("login", "unknown"))
        if not body:
            continue
        if not include_automation_comments and is_automation_comment(reviewer, body):
            continue

        path = comment.get("path")
        line_value = (
            comment.get("line")
            or comment.get("original_line")
            or comment.get("start_line")
            or comment.get("original_start_line")
        )
        line = int(line_value) if isinstance(line_value, int) else None

        snippet = None
        snippet_start = None
        snippet_end = None
        if path and line:
            snippet, snippet_start, snippet_end = read_snippet(
                repo_root=repo_root,
                relative_path=path,
                line_number=line,
                context_lines=context_lines,
            )

        review_id = comment.get("pull_request_review_id")
        review_state = None
        if isinstance(review_id, int):
            review_state = review_state_by_id.get(review_id)

        points.append(
            ReviewPoint(
                point_id=f"inline-{comment.get('id', 'unknown')}",
                category="inline_comment",
                reviewer=reviewer,
                created_at=str(comment.get("created_at", "")),
                source_url=str(comment.get("html_url", pr_info["url"])),
                summary=summarize_text(body),
                quote=body,
                path=path,
                line=line,
                review_state=review_state,
                images=extract_images(body),
                snippet=snippet,
                snippet_start=snippet_start,
                snippet_end=snippet_end,
                diff_hunk=comment.get("diff_hunk"),
            )
        )

    for review in reviews:
        body = str(review.get("body", "")).strip()
        reviewer = str(review.get("user", {}).get("login", "unknown"))
        if not body:
            continue
        if not include_automation_comments and is_automation_comment(reviewer, body):
            continue

        sections = split_text_into_points(body)
        for section_index, (section_title, section_body) in enumerate(sections, start=1):
            summary_input = (
                f"{section_title}. {section_body}" if section_title else section_body
            )
            quote_text = (
                f"#### {section_title}\n\n{section_body}" if section_title else section_body
            )
            points.append(
                ReviewPoint(
                    point_id=f"review-{review.get('id', 'unknown')}-{section_index}",
                    category="review_summary",
                    reviewer=reviewer,
                    created_at=str(
                        review.get("submitted_at") or review.get("created_at") or ""
                    ),
                    source_url=str(review.get("html_url", pr_info["url"])),
                    summary=summarize_text(summary_input),
                    quote=quote_text,
                    title=section_title,
                    review_state=str(review.get("state", "")).strip() or None,
                    images=extract_images(quote_text),
                )
            )

    if include_issue_comments:
        pr_author = str(pr_info.get("author", {}).get("login", ""))
        for comment in issue_comments:
            body = str(comment.get("body", "")).strip()
            reviewer = str(comment.get("user", {}).get("login", "unknown"))
            if not body:
                continue
            if not include_author_comments and pr_author and reviewer == pr_author:
                continue
            if not include_automation_comments and is_automation_comment(reviewer, body):
                continue

            sections = split_text_into_points(body)
            for section_index, (section_title, section_body) in enumerate(
                sections, start=1
            ):
                summary_input = (
                    f"{section_title}. {section_body}" if section_title else section_body
                )
                quote_text = (
                    f"#### {section_title}\n\n{section_body}"
                    if section_title
                    else section_body
                )
                points.append(
                    ReviewPoint(
                        point_id=f"issue-{comment.get('id', 'unknown')}-{section_index}",
                        category="issue_comment",
                        reviewer=reviewer,
                        created_at=str(comment.get("created_at", "")),
                        source_url=str(comment.get("html_url", pr_info["url"])),
                        summary=summarize_text(summary_input),
                        quote=quote_text,
                        title=section_title,
                        images=extract_images(quote_text),
                    )
                )

    for point in points:
        impact, rationale = classify_decision_impact(point)
        point.decision_impact = impact
        point.decision_rationale = rationale

    points.sort(key=lambda point: point.created_at)
    return points


def render_markdown(pr_info: dict[str, Any], points: list[ReviewPoint]) -> str:
    """Render markdown report with one section per review point."""

    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    counts = {
        "inline_comment": 0,
        "review_summary": 0,
        "issue_comment": 0,
    }
    impact_counts = {"Blocker": 0, "Important": 0, "Optional": 0}
    for point in points:
        counts[point.category] = counts.get(point.category, 0) + 1
        impact_counts[point.decision_impact] = impact_counts.get(point.decision_impact, 0) + 1

    lines: list[str] = [
        "# PR Review Summary",
        "",
        f"- Generated at: `{generated_at}`",
        f"- Repository: `{pr_info['name_with_owner']}`",
        f"- PR: [#{pr_info['number']} {pr_info['title']}]({pr_info['url']})",
        f"- Branches: `{pr_info['head_ref']}` -> `{pr_info['base_ref']}`",
        f"- Total review points: **{len(points)}**",
        (
            "- Breakdown: "
            f"inline `{counts['inline_comment']}`, "
            f"review summaries `{counts['review_summary']}`, "
            f"issue comments `{counts['issue_comment']}`"
        ),
        (
            "- Decision impact: "
            f"Blocker `{impact_counts['Blocker']}`, "
            f"Important `{impact_counts['Important']}`, "
            f"Optional `{impact_counts['Optional']}`"
        ),
    ]

    if not points:
        lines.extend(["", "No review points were found for this pull request.", ""])
        return "\n".join(lines)

    lines.extend(["", "## Review Points"])
    for index, point in enumerate(points, start=1):
        pretty_category = point.category.replace("_", " ")
        title = f"### {index}. {pretty_category.title()}"
        if point.title:
            title += f" - {point.title}"
        if point.path and point.line:
            title += f" (`{point.path}:{point.line}`)"
        lines.extend(
            [
                "",
                title,
                f"- Reviewer: `{point.reviewer}`",
                f"- Date: `{point.created_at}`",
                f"- Source: [Open in GitHub]({point.source_url})",
            ]
        )
        if point.review_state:
            lines.append(f"- Review state: `{point.review_state}`")
        lines.append(f"- Summary: {point.summary}")
        lines.append(f"- Decision impact: `{point.decision_impact}`")
        lines.append(f"- Impact rationale: {point.decision_rationale}")

        if point.images:
            lines.append(f"- Referenced images: {format_image_links(point.images)}")

        lines.extend(["- Quote:", format_quote(point.quote)])

        if point.snippet and point.path and point.snippet_start and point.snippet_end:
            lines.extend(
                [
                    f"- Code context: `{point.path}:{point.snippet_start}-{point.snippet_end}`",
                    f"```{detect_language(point.path)}",
                    point.snippet,
                    "```",
                ]
            )
        elif point.diff_hunk:
            lines.extend(
                [
                    "- Diff context:",
                    "```diff",
                    point.diff_hunk.strip(),
                    "```",
                ]
            )

    lines.append("")
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""

    parser = argparse.ArgumentParser(
        description="Generate a per-point summary for the current PR review."
    )
    parser.add_argument(
        "--pr",
        type=int,
        default=None,
        help="Pull request number. Resolve from the current branch when omitted.",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Markdown output path. Defaults to ./pr-<number>-review-summary.md",
    )
    parser.add_argument(
        "--json-output",
        default=None,
        help="Optional JSON output path with normalized review points.",
    )
    parser.add_argument(
        "--context-lines",
        type=int,
        default=4,
        help="Number of lines before/after inline comment locations.",
    )
    parser.add_argument(
        "--max-pages",
        type=int,
        default=20,
        help="Maximum pages fetched per GitHub API endpoint.",
    )
    parser.add_argument(
        "--include-issue-comments",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Include issue comments in the review summary.",
    )
    parser.add_argument(
        "--include-author-comments",
        action="store_true",
        help="Include issue comments authored by the PR author.",
    )
    parser.add_argument(
        "--include-automation-comments",
        action="store_true",
        help="Include generated automation comments (coverage/check bots).",
    )
    parser.add_argument(
        "--print-markdown",
        action=argparse.BooleanOptionalAction,
        default=False,
        help="Print full markdown report to stdout after writing files.",
    )
    return parser.parse_args()


def main() -> int:
    """Entry point."""

    args = parse_args()
    try:
        repo_root = get_repo_root()
        repo_info = run_json_command(
            ["gh", "repo", "view", "--json", "nameWithOwner,url"], cwd=repo_root
        )
        name_with_owner = str(repo_info.get("nameWithOwner", "")).strip()
        if "/" not in name_with_owner:
            raise CommandError("Could not resolve repository owner/name via gh.")
        owner, repo_name = name_with_owner.split("/", maxsplit=1)

        pr_number = resolve_pr_number(repo_root, args.pr)
        pr_data = run_json_command(
            [
                "gh",
                "pr",
                "view",
                str(pr_number),
                "--json",
                "number,title,url,author,headRefName,baseRefName",
            ],
            cwd=repo_root,
        )

        endpoint_prefix = f"repos/{owner}/{repo_name}"
        reviews = fetch_api_pages(
            repo_root=repo_root,
            endpoint=f"{endpoint_prefix}/pulls/{pr_number}/reviews",
            max_pages=args.max_pages,
        )
        inline_comments = fetch_api_pages(
            repo_root=repo_root,
            endpoint=f"{endpoint_prefix}/pulls/{pr_number}/comments",
            max_pages=args.max_pages,
        )
        issue_comments = fetch_api_pages(
            repo_root=repo_root,
            endpoint=f"{endpoint_prefix}/issues/{pr_number}/comments",
            max_pages=args.max_pages,
        )

        pr_info = {
            "number": pr_data.get("number", pr_number),
            "title": pr_data.get("title", ""),
            "url": pr_data.get("url", ""),
            "author": pr_data.get("author", {}),
            "head_ref": pr_data.get("headRefName", ""),
            "base_ref": pr_data.get("baseRefName", ""),
            "name_with_owner": name_with_owner,
        }

        points = build_review_points(
            repo_root=repo_root,
            pr_info=pr_info,
            reviews=reviews,
            inline_comments=inline_comments,
            issue_comments=issue_comments,
            context_lines=max(args.context_lines, 0),
            include_issue_comments=args.include_issue_comments,
            include_author_comments=args.include_author_comments,
            include_automation_comments=args.include_automation_comments,
        )

        markdown = render_markdown(pr_info=pr_info, points=points)
        output_path = (
            Path(args.output).expanduser().resolve()
            if args.output
            else (repo_root / f"pr-{pr_number}-review-summary.md")
        )
        output_path.write_text(markdown, encoding="utf-8")

        if args.json_output:
            json_path = Path(args.json_output).expanduser().resolve()
            json_payload = {
                "repository": name_with_owner,
                "pr_number": pr_number,
                "pr_url": pr_info["url"],
                "generated_at": datetime.now(timezone.utc).isoformat(),
                "points": [asdict(point) for point in points],
            }
            json_path.write_text(
                json.dumps(json_payload, indent=2, ensure_ascii=False),
                encoding="utf-8",
            )
            print(f"Wrote JSON summary to {json_path}")

        if args.print_markdown:
            print("----- BEGIN PR REVIEW SUMMARY MARKDOWN -----")
            print(markdown)
            print("----- END PR REVIEW SUMMARY MARKDOWN -----")

        print(f"Wrote markdown summary to {output_path}")
        print(f"Collected {len(points)} review points from PR #{pr_number}.")
        return 0
    except CommandError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
