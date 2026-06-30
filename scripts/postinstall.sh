#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/skills"
TARGET_DIR="$ROOT_DIR/.agents/skills"

CATEGORIES=(
  "community"
  "curated"
  "mine"
)

if [ ! -d "$SOURCE_DIR" ]; then
  echo "No skills directory found at $SOURCE_DIR, skipping symlinks."
  exit 0
fi

mkdir -p "$TARGET_DIR"

removed_stale=0
for link in "$TARGET_DIR"/*; do
  [ -L "$link" ] || continue
  if [ ! -e "$link" ]; then
    rm "$link"
    removed_stale=$((removed_stale + 1))
  fi
done

linked=0
for category in "${CATEGORIES[@]}"; do
  category_dir="$SOURCE_DIR/$category"
  [ -d "$category_dir" ] || continue

  for skill in "$category_dir"/*/; do
    [ -d "$skill" ] || continue
    skill_name="$(basename "$skill")"
    target="$TARGET_DIR/$skill_name"

    if [ -L "$target" ] || [ -e "$target" ]; then
      rm -rf "$target"
    fi

    ln -s "../../skills/$category/$skill_name" "$target"
    linked=$((linked + 1))
  done
done

echo "Linked $linked skills to .agents/skills (removed $removed_stale stale link(s))."
