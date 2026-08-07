#!/usr/bin/env bash
# Exercise scripts/build-docs-pdf.sh against throwaway fixture projects.
#
# Usage:
#   ./tests/pdf-test.sh
#
# Requirements: python3, mkdocs (with mkdocs-material and mkdocs-with-pdf),
# and pdftotext (poppler-utils) to read the rendered covers back.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FETCH="$REPO_ROOT/scripts/fetch-theme.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ok() { echo "ok - $1"; }

die() {
  echo "not ok - $1" >&2
  exit 1
}

command -v mkdocs >/dev/null || die "mkdocs is required to run this test"
command -v pdftotext >/dev/null \
  || die "pdftotext (poppler-utils) is required to run this test"

new_project() {
  # new_project <project>
  local project="$1"
  mkdir -p "$project/docs"
  printf '[theme]\nrepo = "aicers/docs-theme"\ntemplate = "manual"\nversion = "0.1.0"\n' \
    > "$project/docs/theme.toml"
  cat > "$project/docs/index.md" <<'EOF'
# Fixture Chapter

Fixture body text.

## Fixture Section

More fixture body text.
EOF
  (cd "$project" && "$FETCH" --source "$REPO_ROOT") > /dev/null
}

build_pdf() {
  # build_pdf <project> <locale> [config]
  local project="$1"
  shift
  (cd "$project" && ./docs/theme/build-docs-pdf.sh "$@") > /dev/null
}

# Read a PDF back as text with every space removed, so an assertion does
# not depend on where the renderer broke a line.
pdf_text() {
  pdftotext "$1" - | tr -d '[:space:]'
}

contains() {
  # contains <haystack file> <needle> <description>
  local needle
  needle="$(printf '%s' "$2" | tr -d '[:space:]')"
  case "$(cat "$1")" in
    *"$needle"*) ;;
    *) die "$3: '$2' is missing" ;;
  esac
}

excludes() {
  # excludes <haystack file> <needle> <description>
  local needle
  needle="$(printf '%s' "$2" | tr -d '[:space:]')"
  case "$(cat "$1")" in
    *"$needle"*) die "$3: '$2' should not be present" ;;
  esac
}

# --- a config carrying the full extra.pdf block -----------------------

full="$WORK/full"
new_project "$full"
cat > "$full/mkdocs.yml" <<'EOF'
site_name: Fixture Manual
copyright: Top level copyright that must not win

extra:
  pdf:
    cover_title:
      en: Fixture Title EN
      ko: Fixture Title KO
    cover_subtitle:
      en: Fixture Subtitle EN
      ko: Fixture Subtitle KO
    cover_tagline:
      en: Fixture Tagline EN
      ko: Fixture Tagline KO
    toc_title:
      en: Fixture Contents EN
      ko: Fixture Contents KO
    copyright: Copyright 2026 ClumL Inc.
    output_basename: fixture-doc
EOF

build_pdf "$full" en
build_pdf "$full" ko

[ -f "$full/site/pdf/fixture-doc.en.pdf" ] \
  || die "the en PDF did not follow output_basename"
[ -f "$full/site/pdf/fixture-doc.ko.pdf" ] \
  || die "the ko PDF did not follow output_basename"
ok "the output filename follows extra.pdf.output_basename"

pdf_text "$full/site/pdf/fixture-doc.en.pdf" > "$WORK/en.txt"
pdf_text "$full/site/pdf/fixture-doc.ko.pdf" > "$WORK/ko.txt"

for setting in Title Subtitle Tagline Contents; do
  contains "$WORK/en.txt" "Fixture $setting EN" "en cover"
  excludes "$WORK/en.txt" "Fixture $setting KO" "en cover"
  contains "$WORK/ko.txt" "Fixture $setting KO" "ko cover"
  excludes "$WORK/ko.txt" "Fixture $setting EN" "ko cover"
done
ok "cover_title, cover_subtitle, cover_tagline, and toc_title resolve per locale"
ok "cover_tagline reaches the cover template through extra"

pdftotext "$full/site/pdf/fixture-doc.en.pdf" - | grep -F "Copyright" \
  > "$WORK/en.copyright"
pdftotext "$full/site/pdf/fixture-doc.ko.pdf" - | grep -F "Copyright" \
  > "$WORK/ko.copyright"
[ -s "$WORK/en.copyright" ] || die "no copyright line was rendered"
cmp -s "$WORK/en.copyright" "$WORK/ko.copyright" \
  || die "a plain-string copyright differed between the two covers"
grep -qF "Copyright 2026 ClumL Inc." "$WORK/en.copyright" \
  || die "extra.pdf.copyright is not the rendered copyright"
excludes "$WORK/en.txt" "Top level copyright" "en cover"
ok "a plain-string copyright renders identically in both locales"

# --- a config with no extra.pdf block at all --------------------------

plain="$WORK/plain"
new_project "$plain"
cat > "$plain/mkdocs.yml" <<'EOF'
site_name: Plain Fixture
copyright: Copyright 2026 Fallback Owner
EOF

build_pdf "$plain" en
[ -f "$plain/site/pdf/plain-fixture.en.pdf" ] \
  || die "the output path did not fall back to the site_name slug"
pdf_text "$plain/site/pdf/plain-fixture.en.pdf" > "$WORK/plain.txt"
contains "$WORK/plain.txt" "Plain Fixture" "fallback cover"
contains "$WORK/plain.txt" "Table of contents" "fallback cover"
contains "$WORK/plain.txt" "Copyright 2026 Fallback Owner" "fallback cover"
ok "without extra.pdf the cover, toc heading, and output path fall back"

# --- argument handling ------------------------------------------------

cat > "$full/mkdocs.general.yml" <<'EOF'
site_name: Fixture General
extra:
  pdf:
    output_basename: fixture-general
EOF

build_pdf "$full" en mkdocs.general.yml
[ -f "$full/site/pdf/fixture-general.en.pdf" ] \
  || die "an explicit config argument was not honored"
ok "a second argument selects the config to build from"

if (cd "$full" && ./docs/theme/build-docs-pdf.sh) > "$WORK/noargs.log" 2>&1
then
  die "no arguments should be a usage error"
fi
grep -q "Usage:" "$WORK/noargs.log" || die "no arguments printed no usage"

if (cd "$full" && ./docs/theme/build-docs-pdf.sh fr) > "$WORK/locale.log" 2>&1
then
  die "an unsupported locale should be a usage error"
fi
grep -q "Usage:" "$WORK/locale.log" || die "a bad locale printed no usage"

if (cd "$full" && ./docs/theme/build-docs-pdf.sh en a.yml b.yml) \
  > "$WORK/extra.log" 2>&1
then
  die "a third argument should be a usage error"
fi
grep -q "Usage:" "$WORK/extra.log" || die "a third argument printed no usage"
ok "any other argument shape exits with a usage message"

# --- unknown YAML tags survive the round trip -------------------------

cat > "$full/mkdocs.tags.yml" <<'EOF'
site_name: Fixture Tags
extra:
  pdf:
    output_basename: fixture-tags
markdown_extensions:
  - toc:
      slugify: !!python/object/apply:pymdownx.slugs.slugify
        kwds:
          case: lower
      permalink: true
EOF

DOCS_PDF_DEBUG=1 build_pdf "$full" en mkdocs.tags.yml
[ -f "$full/site/pdf/fixture-tags.en.pdf" ] \
  || die "the build with an unknown YAML tag produced no PDF"
grep -q "python/object/apply:pymdownx.slugs.slugify" "$full/mkdocs.tmp.yml" \
  || die "the unknown YAML tag was dropped from the generated config"
rm -f "$full/mkdocs.tmp.yml"
rm -rf "$full/.pdf-tmp"
ok "an unknown YAML tag survives into the generated config"

# --- the removed extra.pdf_copyright key is called out ----------------

cat > "$full/mkdocs.legacy.yml" <<'EOF'
site_name: Fixture Legacy
extra:
  pdf_copyright: Copyright 2026 ClumL Inc.
EOF

if (cd "$full" && ./docs/theme/build-docs-pdf.sh en mkdocs.legacy.yml) \
  > "$WORK/legacy.log" 2>&1
then
  die "extra.pdf_copyright should be rejected"
fi
grep -q "extra.pdf.copyright" "$WORK/legacy.log" \
  || die "the migration message does not name extra.pdf.copyright"
ok "extra.pdf_copyright fails with the replacement named"

# --- the theme must be installed --------------------------------------

bare="$WORK/bare"
mkdir -p "$bare/docs"
cp "$full/docs/theme/build-docs-pdf.sh" "$bare/build-docs-pdf.sh"
printf 'site_name: Bare Fixture\n' > "$bare/mkdocs.yml"
printf '# Bare\n' > "$bare/docs/index.md"
if (cd "$bare" && ./build-docs-pdf.sh en) > "$WORK/bare.log" 2>&1; then
  die "a missing docs/theme/ should be an error"
fi
grep -q "docs/theme/" "$WORK/bare.log" \
  || die "the missing-theme message does not name docs/theme/"
ok "a missing docs/theme/ exits with an actionable message"

echo "All PDF script checks passed."
