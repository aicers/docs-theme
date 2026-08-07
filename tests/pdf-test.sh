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

echo "All PDF script checks passed."
