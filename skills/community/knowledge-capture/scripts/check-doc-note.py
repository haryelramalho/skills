#!/usr/bin/env python3
"""Validate a knowledge-capture project note without modifying files."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


NOTE_SECTIONS = {
    "concepts": ["Context", "Explanation", "Use when", "Related notes"],
    "decisions": [
        "Context",
        "Decision",
        "Alternatives considered",
        "Consequences",
        "Related notes",
    ],
    "gotchas": ["Context", "Symptom", "Cause", "Avoidance", "Related notes"],
    "research": ["Question", "Findings", "Sources", "Conclusion", "Related notes"],
    "conventions": ["Context", "Convention", "Rationale", "Examples", "Related notes"],
}

INDEX_SECTIONS = ["Concepts", "Decisions", "Gotchas", "Research", "Conventions"]
PLACEHOLDER_RE = re.compile(r"<[^>\n]+>|\b(?:TODO|TBD|FIXME)\b", re.IGNORECASE)


def docs_relative_parts(path: Path) -> list[str] | None:
    parts = list(path.as_posix().split("/"))
    if "docs" not in parts:
        return None
    index = len(parts) - 1 - parts[::-1].index("docs")
    return parts[index:]


def heading_exists(text: str, heading: str) -> bool:
    pattern = re.compile(rf"^##\s+{re.escape(heading)}\s*$", re.MULTILINE)
    return bool(pattern.search(text))


def validate(path: Path) -> list[str]:
    errors: list[str] = []

    if not path.exists():
        return [f"file does not exist: {path}"]
    if path.suffix != ".md":
        errors.append("file must use .md extension")

    text = path.read_text(encoding="utf-8")
    docs_parts = docs_relative_parts(path)

    if docs_parts is None:
        errors.append("path must be under docs/")
        return errors

    if "sessions" in docs_parts:
        errors.append("canonical docs must not live under docs/sessions/")

    if docs_parts == ["docs", "index.md"]:
        for section in INDEX_SECTIONS:
            if not heading_exists(text, section):
                errors.append(f"missing index section: ## {section}")
    elif len(docs_parts) >= 3:
        category = docs_parts[1]
        filename = docs_parts[-1]
        if category not in NOTE_SECTIONS:
            allowed = ", ".join(sorted(NOTE_SECTIONS))
            errors.append(f"unknown docs category '{category}'; expected one of: {allowed}")
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*\.md", filename):
            errors.append("filename must be a lowercase hyphenated slug")
        for section in NOTE_SECTIONS.get(category, []):
            if not heading_exists(text, section):
                errors.append(f"missing section: ## {section}")
    else:
        errors.append("note path must be docs/index.md or docs/<category>/<topic>.md")

    placeholders = sorted(set(match.group(0) for match in PLACEHOLDER_RE.finditer(text)))
    if placeholders:
        errors.append("unresolved placeholders found: " + ", ".join(placeholders[:10]))

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate a knowledge-capture Markdown note path and required sections."
    )
    parser.add_argument("path", help="Path to a docs note or docs/index.md")
    args = parser.parse_args()

    path = Path(args.path)
    errors = validate(path)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"PASS: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
