#!/usr/bin/env bash
# Exercise scripts/build-docs-pdf.sh against throwaway fixture projects.
#
# Usage:
#   ./tests/pdf-test.sh
#
# Requirements: python3, mkdocs (with mkdocs-material and mkdocs-with-pdf),
# and pdftotext/pdfinfo (poppler-utils) to read the rendered pages back.
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
command -v pdfinfo >/dev/null \
  || die "pdfinfo (poppler-utils) is required to run this test"

new_project() {
  # new_project <project>
  local project="$1"
  mkdir -p "$project/docs"
  printf '[theme]\nrepo = "aicers/docs-theme"\ntemplate = "manual"\nversion = "1.2.3"\n' \
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

# Build with DOCS_PDF_DEBUG=1 and echo the path of the generated config
# the script kept, so a test can inspect what was handed to MkDocs.  The
# name is unique per run, so it has to be read back rather than assumed.
debug_build_pdf() {
  # debug_build_pdf <project> <locale> [config]
  local project="$1"
  shift
  local log="$WORK/debug-build.log" generated
  (cd "$project" && DOCS_PDF_DEBUG=1 ./docs/theme/build-docs-pdf.sh "$@") \
    > /dev/null 2> "$log"
  generated="$(sed -n 's/^Generated config: //p' "$log" | tail -n 1)"
  [ -n "$generated" ] || die "the debug build reported no generated config"
  printf '%s\n' "$project/$generated"
}

# Read a PDF back as text with every space removed, so an assertion does
# not depend on where the renderer broke a line.
pdf_text() {
  pdftotext "$1" - | tr -d '[:space:]'
}

# Read one page of a PDF back the same way, and find the page a marker
# landed on.  An assertion about what shares a page with what cannot be
# made against the whole document at once.
page_text() {
  # page_text <pdf> <page>
  pdftotext -f "$2" -l "$2" "$1" - | tr -d '[:space:]'
}

# Read a PDF back with its line breaks left in, so an assertion can be
# made about where the renderer broke a word.  Every other reader here
# strips whitespace, which puts a word the renderer split back together.
pdf_lines() {
  pdftotext "$1" -
}

# Read a PDF back in content order rather than reading order.  A word the
# renderer split inside a table cell is reunited by this and by nothing
# else: the default order walks the whole row between the two halves, so
# stripping whitespace leaves them columns apart.
pdf_raw_text() {
  pdftotext -raw "$1" - | tr -d '[:space:]'
}

page_count() {
  pdfinfo "$1" | sed -n 's/^Pages:[[:space:]]*//p'
}

page_of() {
  # page_of <pdf> <needle> -- first page whose text contains needle.
  local pdf="$1" needle page total
  needle="$(printf '%s' "$2" | tr -d '[:space:]')"
  total="$(page_count "$pdf")"
  for ((page = 1; page <= total; page++)); do
    case "$(page_text "$pdf" "$page")" in
      *"$needle"*) printf '%s\n' "$page"; return 0 ;;
    esac
  done
  return 1
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

contains_either() {
  # contains_either <haystack file> <needle> <needle> <description>
  local first second
  first="$(printf '%s' "$2" | tr -d '[:space:]')"
  second="$(printf '%s' "$3" | tr -d '[:space:]')"
  case "$(cat "$1")" in
    *"$first"*|*"$second"*) ;;
    *) die "$4: neither '$2' nor '$3' is present" ;;
  esac
}

build_date() {
  # build_date <en|ko> -- the author line the script falls back to.
  if [ "$1" = en ]; then
    python3 -c 'import datetime
print(datetime.datetime.now().strftime("%B %-d, %Y"))'
  else
    python3 -c 'import datetime
print(datetime.datetime.now().strftime("%Y년 %-m월 %-d일"))'
  fi
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
    author:
      en: Fixture Author EN
      ko: Fixture Author KO
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

for setting in Title Subtitle Tagline Contents Author; do
  contains "$WORK/en.txt" "Fixture $setting EN" "en cover"
  excludes "$WORK/en.txt" "Fixture $setting KO" "en cover"
  contains "$WORK/ko.txt" "Fixture $setting KO" "ko cover"
  excludes "$WORK/ko.txt" "Fixture $setting EN" "ko cover"
done
ok "cover_title, cover_subtitle, cover_tagline, toc_title, and author resolve per locale"
ok "cover_tagline reaches the cover template through extra"

# A locale-mapped author replaces the build date the cover would
# otherwise carry.
excludes "$WORK/en.txt" "$(build_date en)" "en cover"

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

# The build date the author line falls back to is read either side of
# the build, so a run that straddles midnight matches one of the two
# instead of failing.
en_before="$(build_date en)"
build_pdf "$plain" en
en_after="$(build_date en)"
[ -f "$plain/site/pdf/plain-fixture.en.pdf" ] \
  || die "the output path did not fall back to the site_name slug"
pdf_text "$plain/site/pdf/plain-fixture.en.pdf" > "$WORK/plain.txt"
contains "$WORK/plain.txt" "Plain Fixture" "fallback cover"
contains "$WORK/plain.txt" "Table of contents" "fallback cover"
contains "$WORK/plain.txt" "Copyright 2026 Fallback Owner" "fallback cover"
ok "without extra.pdf the cover, toc heading, and output path fall back"

ko_before="$(build_date ko)"
build_pdf "$plain" ko
ko_after="$(build_date ko)"
pdf_text "$plain/site/pdf/plain-fixture.ko.pdf" > "$WORK/plain.ko.txt"
contains_either "$WORK/plain.txt" "$en_before" "$en_after" "en fallback cover"
contains_either "$WORK/plain.ko.txt" "$ko_before" "$ko_after" "ko fallback cover"
ok "an unset author falls back to the build date formatted for the locale"

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

generated="$(debug_build_pdf "$full" en mkdocs.tags.yml)"
[ -f "$full/site/pdf/fixture-tags.en.pdf" ] \
  || die "the build with an unknown YAML tag produced no PDF"
grep -q "python/object/apply:pymdownx.slugs.slugify" "$generated" \
  || die "the unknown YAML tag was dropped from the generated config"
rm -f "$generated"
rm -rf "$full/.pdf-tmp"
ok "an unknown YAML tag survives into the generated config"

# --- the consumer's own plugins survive -------------------------------
# MkDocs accepts `plugins` as a list or as a mapping of name to options.
# Dropping either form would silently build the PDF without the
# consumer's plugins -- without i18n, or without whatever generates the
# content -- which is exactly the kind of quiet regression the script
# must not introduce.

cat > "$full/mkdocs.plugin-map.yml" <<'EOF'
site_name: Fixture Plugin Map
plugins:
  search: {}
extra:
  pdf:
    output_basename: fixture-plugin-map
EOF

generated="$(debug_build_pdf "$full" en mkdocs.plugin-map.yml)"
[ -f "$full/site/pdf/fixture-plugin-map.en.pdf" ] \
  || die "the mapping plugins form produced no PDF"
grep -q "^  search:" "$generated" \
  || die "the mapping plugins form dropped the consumer's plugins"
grep -q "with-pdf:" "$generated" \
  || die "with-pdf was not added to the mapping plugins form"
rm -f "$generated"
rm -rf "$full/.pdf-tmp"

cat > "$full/mkdocs.plugin-list.yml" <<'EOF'
site_name: Fixture Plugin List
plugins:
  - search
extra:
  pdf:
    output_basename: fixture-plugin-list
EOF

generated="$(debug_build_pdf "$full" en mkdocs.plugin-list.yml)"
[ -f "$full/site/pdf/fixture-plugin-list.en.pdf" ] \
  || die "the list plugins form produced no PDF"
grep -q "^- search$" "$generated" \
  || die "the list plugins form dropped the consumer's plugins"
grep -q "with-pdf:" "$generated" \
  || die "with-pdf was not added to the list plugins form"
rm -f "$generated"
rm -rf "$full/.pdf-tmp"
ok "the consumer's plugins survive in both the list and mapping forms"

# --- the generated config never clobbers a caller's file --------------
# The config path is caller-selectable, so the scratch config the script
# writes must not be able to land on a file the project already has --
# least of all the config it was handed, which it would read, overwrite
# and then delete on exit.

cat > "$full/mkdocs.tmp.yml" <<'EOF'
site_name: Fixture Collision
extra:
  pdf:
    output_basename: fixture-collision
EOF
cp "$full/mkdocs.tmp.yml" "$WORK/collision-config.yml"

build_pdf "$full" en mkdocs.tmp.yml
[ -f "$full/site/pdf/fixture-collision.en.pdf" ] \
  || die "a config named mkdocs.tmp.yml produced no PDF"
[ -f "$full/mkdocs.tmp.yml" ] \
  || die "the caller's mkdocs.tmp.yml was deleted by the build"
cmp -s "$full/mkdocs.tmp.yml" "$WORK/collision-config.yml" \
  || die "the caller's mkdocs.tmp.yml was overwritten by the build"

# The scratch config is still cleaned up when it is not the caller's.
scratch_left="$(find "$full" -maxdepth 1 -name 'mkdocs.tmp.*.yml' | wc -l)"
[ "$scratch_left" -eq 0 ] \
  || die "the generated config was left behind without DOCS_PDF_DEBUG"
rm -f "$full/mkdocs.tmp.yml"
ok "the generated config never overwrites a file the caller owns"

# --- a stale top-level extra.cover_tagline is cleared -----------------
# cover_tagline reaches the cover through `extra`, which the plugin
# never overwrites, so an unresolved tagline has to be removed rather
# than left alone -- otherwise a value the consumer still carries at the
# top level renders on a cover the contract says has none.

cat > "$full/mkdocs.stale-tagline.yml" <<'EOF'
site_name: Fixture Stale Tagline
extra:
  cover_tagline: Stale Tagline Text
  pdf:
    output_basename: fixture-stale-tagline
EOF

generated="$(debug_build_pdf "$full" en mkdocs.stale-tagline.yml)"
! grep -q "cover_tagline" "$generated" \
  || die "the generated config kept a stale extra.cover_tagline"
rm -f "$generated"
rm -rf "$full/.pdf-tmp"
pdf_text "$full/site/pdf/fixture-stale-tagline.en.pdf" > "$WORK/stale.txt"
excludes "$WORK/stale.txt" "Stale Tagline Text" "stale tagline cover"
ok "an unset cover_tagline clears a top-level extra.cover_tagline"

# The same holds when cover_tagline is locale-mapped but carries no
# entry for the locale being built.
cat > "$full/mkdocs.partial-tagline.yml" <<'EOF'
site_name: Fixture Partial Tagline
extra:
  cover_tagline: Stale Tagline Text
  pdf:
    cover_tagline:
      en: Fresh Tagline EN
    output_basename: fixture-partial-tagline
EOF

build_pdf "$full" en mkdocs.partial-tagline.yml
build_pdf "$full" ko mkdocs.partial-tagline.yml
pdf_text "$full/site/pdf/fixture-partial-tagline.en.pdf" > "$WORK/partial-en.txt"
pdf_text "$full/site/pdf/fixture-partial-tagline.ko.pdf" > "$WORK/partial-ko.txt"
contains "$WORK/partial-en.txt" "Fresh Tagline EN" "en tagline cover"
excludes "$WORK/partial-en.txt" "Stale Tagline Text" "en tagline cover"
excludes "$WORK/partial-ko.txt" "Fresh Tagline EN" "ko tagline cover"
excludes "$WORK/partial-ko.txt" "Stale Tagline Text" "ko tagline cover"
ok "a locale-mapped cover_tagline with no entry for the locale renders none"

# --- output_basename is never a locale map ----------------------------

cat > "$full/mkdocs.badbasename.yml" <<'EOF'
site_name: Fixture Bad Basename
extra:
  pdf:
    output_basename:
      en: fixture-en
      ko: fixture-ko
EOF

if (cd "$full" && ./docs/theme/build-docs-pdf.sh en mkdocs.badbasename.yml) \
  > "$WORK/basename.log" 2>&1
then
  die "a locale-mapped output_basename should be rejected"
fi
grep -q "output_basename" "$WORK/basename.log" \
  || die "the message does not name output_basename"
ok "a locale-mapped output_basename is rejected"

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

# --- an incomplete install is reported, not crashed on ------------------

partial="$WORK/partial"
new_project "$partial"
printf 'site_name: Partial Fixture\n' > "$partial/mkdocs.yml"
rm -f "$partial/docs/theme/pdf/styles.scss"
if (cd "$partial" && ./docs/theme/build-docs-pdf.sh en) > "$WORK/partial.log" 2>&1
then
  die "a missing styles.scss should be an error"
fi
grep -q "styles.scss" "$WORK/partial.log" \
  || die "the message does not name the missing styles.scss"

rm -rf "$partial/docs/theme/pdf"
if (cd "$partial" && ./docs/theme/build-docs-pdf.sh en) > "$WORK/nopdf.log" 2>&1
then
  die "a missing docs/theme/pdf/ should be an error"
fi
grep -q "docs/theme/pdf/" "$WORK/nopdf.log" \
  || die "the message does not name docs/theme/pdf/"
ok "an incomplete install exits with an actionable message"

# --- within-chapter pagination ----------------------------------------
# A nav section whose children are separate pages is rendered as one
# article of stacked `section` elements.  Forcing a page break before
# each of those sections dropped everything after the section's first
# paragraph out of the render, so `mkdocs build` exiting 0 is not
# evidence the chapter is in the PDF -- the markers have to be read back.
# The blocks below are each taller than the space left on the page they
# start on, which is the case that used to lose them.

paging="$WORK/paging"
new_project "$paging"
cat > "$paging/mkdocs.yml" <<'EOF'
site_name: Fixture Paging
nav:
  - Home: index.md
  - Guide:
      - Overview: guide/overview.md
      - Reference: guide/reference.md
extra:
  pdf:
    output_basename: fixture-paging
markdown_extensions:
  - admonition
  - tables
EOF

mkdir -p "$paging/docs/guide"
cat > "$paging/docs/guide/overview.md" <<'EOF'
# Overview

A subsection short enough to leave most of its page empty when it is
padded out to a full one.
EOF

{
  echo '# Reference'
  echo
  echo 'The first paragraph of the chapter. Everything below it is what a'
  echo 'forced break used to drop.'
  echo
  echo '## Endpoints'
  echo
  echo '| Name | Description |'
  echo '| --- | --- |'
  for i in $(seq 1 21); do
    echo "| field-$i | Description of field number $i. |"
  done
  echo '| field-omega | The last row of the table. |'
  echo
  echo '## Parameters'
  echo
  echo '**Key inputs**'
  echo
  echo '- first input, which must not be split off from its label.'
  echo '- second input, which must not be split off either.'
  for i in $(seq 3 13); do
    echo "- input number $i, padding the list past the end of the page."
  done
  echo '- option-omega, the last item of the list.'
  echo
  echo '!!! note'
  echo '    admonition-omega. A note tall enough to be worth keeping whole:'
  echo '    line two, line three, line four, and line five of the body.'
} > "$paging/docs/guide/reference.md"

build_pdf "$paging" en
paging_pdf="$paging/site/pdf/fixture-paging.en.pdf"
[ -f "$paging_pdf" ] || die "the nav-grouped fixture produced no PDF"

pdf_text "$paging_pdf" > "$WORK/paging.txt"
contains "$WORK/paging.txt" "field-omega" "a subsection's table"
contains "$WORK/paging.txt" "option-omega" "a subsection's list"
contains "$WORK/paging.txt" "admonition-omega" "a subsection's admonition"
ok "a chapter's tables, lists, and admonitions survive into the PDF"

# A top-level chapter still starts on a page of its own.
home_page="$(page_of "$paging_pdf" "Fixture body text")" \
  || die "the first chapter is not in the PDF"
guide_page="$(page_of "$paging_pdf" "A subsection short enough")" \
  || die "the Guide chapter is not in the PDF"
[ "$guide_page" -gt "$home_page" ] \
  || die "the Guide chapter did not start after the first chapter"
ok "a top-level chapter still starts on a new page"

# A subsection flows on instead of being padded out to a full page: the
# two children of Guide have to share a page somewhere, or the chapter
# has been padded again.
reference_page="$(page_of "$paging_pdf" "The first paragraph of the chapter")" \
  || die "the Reference subsection is not in the PDF"
[ "$reference_page" -eq "$guide_page" ] \
  || die "a subsection was padded onto a page of its own"
ok "a subsection flows on rather than opening a padded page"

# A bold-only label is a heading for the block under it, so the break
# must not land between them.  This is the "short label almost alone on
# a page" case: the label keeps at least the first two items with it.
label_page="$(page_of "$paging_pdf" "Key inputs")" \
  || die "the bold label is not in the PDF"
page_text "$paging_pdf" "$label_page" > "$WORK/paging-label.txt"
contains "$WORK/paging-label.txt" "first input" "the label's page"
contains "$WORK/paging-label.txt" "second input" "the label's page"
ok "a bold-only label keeps the first items of its list with it"

# A split table leaves no lone row behind either.
first_row_page="$(page_of "$paging_pdf" "Description of field number 1.")" \
  || die "the table's first row is not in the PDF"
page_text "$paging_pdf" "$first_row_page" > "$WORK/paging-table.txt"
contains "$WORK/paging-table.txt" "Description of field number 2." \
  "the page the table starts on"
ok "a split table keeps at least two rows on the page it starts on"

# --- table readability -------------------------------------------------
# Material draws its table grid with a custom property that only a
# browser's colour scheme defines, so in the PDF the border resolves to
# nothing and the rules that redraw it live in `pdf/styles.scss`.  Those
# same rules decide where a cell wraps, and the wrap points have to be
# read back rather than assumed: a cell told to break `anywhere` collapses
# its column to a single character, which chops a `Default` heading into
# `Defau` / `lt` -- and costs minutes of layout time on a cell holding a
# page of prose.  Every other reader here strips whitespace, which hides
# exactly that by gluing a split word back together.

tables="$WORK/tables"
new_project "$tables"
cat > "$tables/mkdocs.yml" <<'EOF'
site_name: Fixture Tables
extra:
  pdf:
    output_basename: fixture-tables
markdown_extensions:
  - tables
EOF

long_setting='ingest.stream.retention_policy_duration_seconds'
{
  echo '# Tables'
  echo
  echo '| Setting | Default | Description |'
  echo '| --- | --- | --- |'
  echo "| \`$long_setting\` | \`604800\` | How long a raw stream record is kept. |"
  echo
  # Rows tall enough that a page break has to fall between two of them.
  echo '| Key | Value |'
  echo '| --- | --- |'
  for i in $(seq 1 12); do
    printf '| rowkey-%s | ' "$i"
    for s in $(seq 1 14); do
      printf 'Sentence %s of row %s, padding the row past a few lines. ' "$s" "$i"
    done
    printf 'rowend-%s |\n' "$i"
  done
  echo
  # A row too tall for a page of its own has to split rather than be
  # dropped, and what follows it has to survive.
  echo '| Key | Value |'
  echo '| --- | --- |'
  printf '| overlong | '
  for s in $(seq 1 320); do
    printf 'Sentence %s of a row taller than one whole page. ' "$s"
  done
  printf 'overlong-end |\n'
  echo '| after | after-overlong |'
} > "$tables/docs/index.md"

build_pdf "$tables" en
tables_pdf="$tables/site/pdf/fixture-tables.en.pdf"
[ -f "$tables_pdf" ] || die "the table fixture produced no PDF"

pdf_text "$tables_pdf" > "$WORK/tables.txt"
pdf_lines "$tables_pdf" > "$WORK/tables-lines.txt"
pdf_raw_text "$tables_pdf" > "$WORK/tables-raw.txt"

# A long setting name has no break opportunity of its own.  Left
# unbreakable it sets its column's minimum width and squeezes the rest of
# the row into a ribbon, so it has to wrap -- and still arrive whole.
contains "$WORK/tables-raw.txt" "$long_setting" "a long setting name"
if grep -qF "$long_setting" "$WORK/tables-lines.txt"; then
  die "a long setting name did not wrap inside its cell"
fi
ok "a long inline-code value wraps inside its cell and survives whole"

# ...but nothing else in a cell may be broken mid-word.
grep -qF "Default" "$WORK/tables-lines.txt" \
  || die "the Default heading was broken mid-word"
grep -qF "604800" "$WORK/tables-lines.txt" \
  || die "the 604800 cell value was broken mid-number"
ok "a heading and a short code value in a cell are not broken mid-word"

# A row that splits leaves its cells misaligned either side of the break,
# so each row's first and last marker have to share a page.  The rows are
# tall enough that a page break falls between two of them.
tables_pages="$(page_count "$tables_pdf")"
[ "$tables_pages" -ge 4 ] \
  || die "the table fixture is too short to break a page between rows"
for i in $(seq 1 12); do
  key_page="$(page_of "$tables_pdf" "rowkey-$i")" \
    || die "row $i is not in the PDF"
  end_page="$(page_of "$tables_pdf" "rowend-$i")" \
    || die "row $i's last cell is not in the PDF"
  [ "$key_page" = "$end_page" ] \
    || die "row $i was split across a page boundary"
done
ok "a table row is never split across a page boundary"

# A row taller than a page is the one case where it has to split anyway.
contains "$WORK/tables.txt" "overlong-end" "a row taller than a page"
contains "$WORK/tables.txt" "after-overlong" "the row after an overlong one"
ok "a row taller than a page splits rather than losing its content"

# --- the cover logo -----------------------------------------------------

# The cover sits on white paper, so it must carry the black-lettering
# brand-print.svg.  theme/brand.svg is the white-lettering variant the
# site header uses; rendering that on the cover produces an invisible
# logo, which is exactly the kind of silent asset loss nothing else here
# would catch.
generated="$(debug_build_pdf "$full" en)"
grep -q 'cover_logo:.*brand-print\.svg' "$generated" \
  || die "the cover did not default to brand-print.svg"
grep -q 'cover_logo:.*brand\.svg' "$generated" \
  && die "the cover used the white-lettering header logo"
ok "the cover logo defaults to the print variant, not the header one"

# A consumer documenting a product with its own mark overrides it.  The
# fixture carries a <text> element so the substitution is observable in
# the rendered page rather than only in the generated config.
override="$WORK/override"
new_project "$override"
cat > "$override/docs/product-logo.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 260 40"><text x="0" y="30" font-size="26">PRODUCTLOGOMARK</text></svg>
SVG
cat > "$override/mkdocs.yml" <<'EOF'
site_name: Override Fixture
extra:
  pdf:
    cover_logo: product-logo.svg
EOF
build_pdf "$override" en
pdf_text "$override/site/pdf/override-fixture.en.pdf" > "$WORK/override.txt"
contains "$WORK/override.txt" "PRODUCTLOGOMARK" "the overridden cover logo"
ok "extra.pdf.cover_logo puts a consumer's own mark on the cover"

# A path that does not resolve is an error.  Falling back to the theme
# logo would hand a consumer a cover branded with the wrong company.
cat > "$override/mkdocs.missing.yml" <<'EOF'
site_name: Missing Logo Fixture
extra:
  pdf:
    cover_logo: does-not-exist.svg
EOF
if (cd "$override" && ./docs/theme/build-docs-pdf.sh en mkdocs.missing.yml) \
  > "$WORK/missing-logo.log" 2>&1
then
  die "a cover_logo that does not exist should be an error"
fi
grep -q "extra.pdf.cover_logo" "$WORK/missing-logo.log" \
  || die "the error does not name extra.pdf.cover_logo"
ok "a cover_logo that does not resolve fails instead of falling back"

# An incomplete install is an error for the same reason.  This needs a
# config without an override, or the override would satisfy the cover and
# the missing asset would go unnoticed.
cat > "$override/mkdocs.default.yml" <<'EOF'
site_name: Default Logo Fixture
EOF
rm -f "$override/docs/theme/brand-print.svg"
if (cd "$override" && ./docs/theme/build-docs-pdf.sh en mkdocs.default.yml) \
  > "$WORK/no-print-logo.log" 2>&1
then
  die "a missing brand-print.svg should be an error"
fi
grep -q "brand-print.svg" "$WORK/no-print-logo.log" \
  || die "the error does not name the missing asset"
ok "a missing brand-print.svg fails instead of rendering a logo-less cover"

echo "All PDF script checks passed."
