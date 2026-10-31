#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/mdbook/src"
ASSETS_SRC="$ROOT/docs/assets"

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command '$1' not found" >&2
    exit 1
  fi
}

require pandoc

rm -rf "$SRC"
mkdir -p "$SRC/assets"

pandoc "$ROOT/index.org" \
  --from=org \
  --to=gfm \
  --wrap=none \
  --markdown-headings=atx \
  --output="$SRC/index.md"

if [[ -d "$ASSETS_SRC" ]]; then
  cp -R "$ASSETS_SRC/." "$SRC/assets/"
fi

mapfile -t chapter_files < <(
  find "$ROOT" -maxdepth 1 -type f -name 'chapter*.org' -print | sort -V
)

{
  printf '# Summary\n\n'
  printf '[Introduction](index.md)\n\n'
  printf '# Chapters\n\n'
} > "$SRC/SUMMARY.md"

for org in "${chapter_files[@]}"; do
  base="$(basename "$org" .org)"
  num="${base#chapter}"

  pandoc "$org" \
    --from=org \
    --to=gfm \
    --wrap=none \
    --markdown-headings=atx \
    --output="$SRC/$base.md"

  # Prefer the chapter label from index.org; fall back to the first heading.
  title="$(sed -nE "s/.*\[\[file:${base}\.org\]\[(.*)\]\]/\1/p" "$ROOT/index.org" | head -n 1)"
  if [[ -z "$title" ]]; then
    heading="$(sed -n 's/^\* //p' "$org" | head -n 1)"
    title="Chapter $num: $heading"
  fi

  printf -- '- [%s](%s.md)\n' "$title" "$base" >> "$SRC/SUMMARY.md"
done

# Rewrite local org links to their generated Markdown pages. External URLs are
# left untouched, including external domains that happen to end in ".org".
while IFS= read -r -d '' md; do
  sed -E -i \
    -e 's~\]\(file:(index|chapter[0-9]+)\.org(#[^)]*)?\)~](\1.md\2)~g' \
    -e 's~\]\((index|chapter[0-9]+)\.org(#[^)]*)?\)~](\1.md\2)~g' \
    -e 's#\]\(file:#](#g' \
    "$md"
done < <(find "$SRC" -maxdepth 1 -type f -name '*.md' -print0)

echo "Generated mdBook sources in $SRC"
