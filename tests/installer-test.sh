#!/usr/bin/env bash
# Exercise scripts/fetch-theme.sh against throwaway fixture projects.
#
# Usage:
#   ./tests/installer-test.sh
#
# Requirements: python3, tar, mkdocs (with mkdocs-material).  No network
# access: the release path is driven by a stub `gh` on PATH.
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

write_config() {
  # write_config <project> <template> <version>
  mkdir -p "$1/docs"
  printf '[theme]\nrepo = "aicers/docs-theme"\ntemplate = "%s"\nversion = "%s"\n' \
    "$2" "$3" > "$1/docs/theme.toml"
}

new_project() {
  # new_project <project> [template] [version]
  local project="$1"
  write_config "$project" "${2:-manual}" "${3:-0.1.0}"
  cat > "$project/mkdocs.yml" <<'EOF'
site_name: Fixture Project
extra_css:
  - theme/styles/lists.css
  - theme/styles/base.css
EOF
  printf '# Fixture\n\nFixture page.\n' > "$project/docs/index.md"
}

install_into() {
  # install_into <project> [extra args...]
  local project="$1"
  shift
  (cd "$project" && "$FETCH" "$@")
}

meta_value() {
  # meta_value <project> <key>
  sed -n "s/^$2 = \"\(.*\)\"\$/\1/p" "$1/docs/theme/.meta"
}

expect_failure() {
  # expect_failure <project> <expected substring> <description> [args...]
  local project="$1" needle="$2" description="$3"
  shift 3
  local output
  if output="$(cd "$project" && "$FETCH" "$@" 2>&1)"; then
    die "$description: expected a non-zero exit, got:\n$output"
  fi
  case "$output" in
    *"$needle"*) ok "$description" ;;
    *) die "$description: message did not mention '$needle':\n$output" ;;
  esac
}

command -v mkdocs >/dev/null || die "mkdocs is required to run this test"

# --- a fresh install lays down the whole install set ------------------

project="$WORK/alpha"
new_project "$project"
install_into "$project" --source "$REPO_ROOT" > "$WORK/install.log"
grep -q "^Installed docs-theme 0.1.0 (manual, local)" "$WORK/install.log" \
  || die "first install did not report what it installed"

for entry in \
  styles/lists.css \
  styles/pdf.css \
  styles/base.css \
  pdf/cover.html.j2 \
  pdf/styles.scss \
  mkdocs-base.yml \
  fonts/Roboto-Regular.woff2 \
  fonts/Pretendard-Regular.woff2 \
  brand.svg \
  build-docs-pdf.sh \
  .meta
do
  [ -f "$project/docs/theme/$entry" ] || die "install is missing $entry"
done
ok "installs every entry of the install set into docs/theme/"

[ -x "$project/docs/theme/build-docs-pdf.sh" ] \
  || die "build-docs-pdf.sh was installed without the executable bit"
ok "build-docs-pdf.sh is installed executable"

for key in repo version template digest source; do
  [ -n "$(meta_value "$project" "$key")" ] || die ".meta has no $key"
done
[ "$(meta_value "$project" repo)" = "aicers/docs-theme" ] || die "wrong repo"
[ "$(meta_value "$project" version)" = "0.1.0" ] || die "wrong version"
[ "$(meta_value "$project" template)" = "manual" ] || die "wrong template"
[ "$(meta_value "$project" source)" = "local" ] || die "--source is not local"
ok ".meta records repo, version, template, digest, and source"

# --- the installed styles survive the MkDocs build --------------------
# This is the regression check for the dot-directory bug: MkDocs drops
# every dot-prefixed path from the build, so nothing installed under a
# dot-prefixed directory ever reached site/.

(cd "$project" && mkdocs build) > "$WORK/mkdocs.log" 2>&1 \
  || { cat "$WORK/mkdocs.log"; die "mkdocs build failed"; }
[ -f "$project/site/theme/styles/lists.css" ] \
  || die "theme/styles/lists.css is missing from the built site"
[ -f "$project/site/theme/styles/base.css" ] \
  || die "theme/styles/base.css is missing from the built site"
ok "installed stylesheets appear in the built site"

if [ -f "$project/site/theme/.meta" ]; then
  die ".meta leaked into the built site"
fi
ok ".meta stays out of the built site"

# --- an unchanged tree is left alone ----------------------------------

install_into "$project" --source "$REPO_ROOT" > "$WORK/skip.log"
grep -q "skipping" "$WORK/skip.log" || die "second run did not skip"
ok "a second run against an unchanged tree skips the install"

# --- any change to the tree forces a reinstall ------------------------

digest_before="$(meta_value "$project" digest)"

echo "/* hand edit */" >> "$project/docs/theme/styles/lists.css"
install_into "$project" --source "$REPO_ROOT" > "$WORK/edit.log"
grep -q "^Installed" "$WORK/edit.log" || die "an edited file did not reinstall"
if grep -q "hand edit" "$project/docs/theme/styles/lists.css"; then
  die "the reinstall did not restore the edited file"
fi
ok "an edited file triggers a reinstall"

printf 'stray\n' > "$project/docs/theme/styles/stray.css"
install_into "$project" --source "$REPO_ROOT" > "$WORK/add.log"
grep -q "^Installed" "$WORK/add.log" || die "an added file did not reinstall"
if [ -f "$project/docs/theme/styles/stray.css" ]; then
  die "the reinstall did not remove the added file"
fi
ok "an added file triggers a reinstall"

rm "$project/docs/theme/styles/pdf.css"
install_into "$project" --source "$REPO_ROOT" > "$WORK/delete.log"
grep -q "^Installed" "$WORK/delete.log" \
  || die "a deleted file did not reinstall"
[ -f "$project/docs/theme/styles/pdf.css" ] \
  || die "the reinstall did not restore the deleted file"
ok "a deleted file triggers a reinstall"

chmod -x "$project/docs/theme/build-docs-pdf.sh"
install_into "$project" --source "$REPO_ROOT" > "$WORK/mode.log"
grep -q "^Installed" "$WORK/mode.log" \
  || die "a cleared executable bit did not reinstall"
[ -x "$project/docs/theme/build-docs-pdf.sh" ] \
  || die "the reinstall did not restore the executable bit"
ok "a cleared executable bit triggers a reinstall and is restored"

[ "$(meta_value "$project" digest)" = "$digest_before" ] \
  || die "reinstalling the same source changed the digest"
ok "reinstalling the same source reproduces the digest"

# --- theme.toml drives version and template ---------------------------

write_config "$project" api-reference 0.1.0
install_into "$project" --source "$REPO_ROOT" > "$WORK/template.log"
grep -q "^Installed" "$WORK/template.log" \
  || die "a template change did not reinstall"
[ -f "$project/docs/theme/styles/api.css" ] \
  || die "the api-reference template was not installed"
[ "$(meta_value "$project" template)" = "api-reference" ] \
  || die ".meta did not record the new template"
ok "changing template in docs/theme.toml reinstalls"

write_config "$project" api-reference 9.9.9
install_into "$project" --source "$REPO_ROOT" > "$WORK/version.log"
grep -q "^Installed" "$WORK/version.log" \
  || die "a version change did not reinstall"
[ "$(meta_value "$project" version)" = "9.9.9" ] \
  || die ".meta did not record the new version"
ok "changing version in docs/theme.toml reinstalls"

# --- the digest does not depend on where the project lives ------------

mkdir -p "$WORK/one" "$WORK/two/deeper/still"
new_project "$WORK/one/beta"
new_project "$WORK/two/deeper/still/gamma"
install_into "$WORK/one/beta" --source "$REPO_ROOT" > /dev/null
install_into "$WORK/two/deeper/still/gamma" --source "$REPO_ROOT" > /dev/null
[ "$(meta_value "$WORK/one/beta" digest)" \
  = "$(meta_value "$WORK/two/deeper/still/gamma" digest)" ] \
  || die "the same source produced different digests in two projects"
ok "the digest is identical across projects at different paths"

# --- configuration errors are actionable ------------------------------

mkdir -p "$WORK/no-config"
expect_failure "$WORK/no-config" "docs/theme.toml" \
  "a missing docs/theme.toml names the file" --source "$REPO_ROOT"

mkdir -p "$WORK/no-key/docs"
printf '[theme]\nrepo = "aicers/docs-theme"\nversion = "0.1.0"\n' \
  > "$WORK/no-key/docs/theme.toml"
expect_failure "$WORK/no-key" "theme.template" \
  "a missing key names the key" --source "$REPO_ROOT"

mkdir -p "$WORK/no-table/docs"
printf 'repo = "aicers/docs-theme"\n' > "$WORK/no-table/docs/theme.toml"
expect_failure "$WORK/no-table" "[theme]" \
  "a missing [theme] table is reported" --source "$REPO_ROOT"

new_project "$WORK/bad-template" nonexistent
expect_failure "$WORK/bad-template" "nonexistent" \
  "an unknown template is reported" --source "$REPO_ROOT"

new_project "$WORK/bad-args"
expect_failure "$WORK/bad-args" "Usage:" \
  "an unknown option prints usage" --version 1.0.0

# --- the release path, driven by a stub gh ----------------------------
# The archive's top-level directory is deliberately not "docs-theme-*":
# a fork or renamed repository must still install.

top="renamed-theme-9.9.9"
mkdir -p "$WORK/archive/$top"
tar -cf - --exclude='*/.git' --exclude='*/site' --exclude='*/site-ci' \
  -C "$REPO_ROOT" . | tar -xf - -C "$WORK/archive/$top"
tar -czf "$WORK/release.tar.gz" -C "$WORK/archive" "$top"

mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<EOF
#!/usr/bin/env bash
# Stub for: gh release download <version> --repo R --archive tar.gz --dir D
set -euo pipefail
dir=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    --dir) dir="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "\$dir" ] || exit 1
cp "$WORK/release.tar.gz" "\$dir/source.tar.gz"
EOF
chmod +x "$WORK/bin/gh"

new_project "$WORK/delta"
(cd "$WORK/delta" && PATH="$WORK/bin:$PATH" "$FETCH") > "$WORK/release.log"
grep -q "^Installed docs-theme 0.1.0 (manual, release)" "$WORK/release.log" \
  || die "the release path did not install"
[ "$(meta_value "$WORK/delta" source)" = "release" ] \
  || die "a downloaded install did not record source = \"release\""
[ -x "$WORK/delta/docs/theme/build-docs-pdf.sh" ] \
  || die "the release install lost the executable bit"
ok "a downloaded install works with an arbitrary archive top-level directory"

[ "$(meta_value "$WORK/delta" digest)" = "$(meta_value "$WORK/one/beta" digest)" ] \
  || die "the release install and the local install disagree on the digest"
ok "the release and local installs of the same tree share a digest"

(cd "$WORK/delta" && PATH="$WORK/bin:$PATH" "$FETCH") > "$WORK/release2.log"
grep -q "skipping" "$WORK/release2.log" \
  || die "the second release run did not skip"
ok "a second release run skips without downloading"

# A local install must not be mistaken for a released one.
install_into "$WORK/delta" --source "$REPO_ROOT" > "$WORK/relocal.log"
grep -q "^Installed" "$WORK/relocal.log" \
  || die "--source over a release install did not reinstall"
[ "$(meta_value "$WORK/delta" source)" = "local" ] \
  || die "--source did not overwrite source = \"release\""
ok "--source over a released install rewrites source in .meta"

echo "All installer checks passed."
