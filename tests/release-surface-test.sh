#!/usr/bin/env bash
# Exercise scripts/check-release-surface.sh against throwaway repositories.
#
# Usage:
#   ./tests/release-surface-test.sh
#
# Requirements: git. No network access.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$REPO_ROOT/scripts/check-release-surface.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Commits in the fixtures must not depend on the caller's git identity or
# configuration.
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.com
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

ok() { echo "ok - $1"; }

die() {
  echo "not ok - $1" >&2
  exit 1
}

# A repository with one file on every surface path and a few that are not
# on it, committed once. Prints its path.
new_repo() {
  local repo="$WORK/$1"
  git init -q -b main "$repo"
  (
    cd "$repo"
    mkdir -p templates/manual/styles shared/styles shared/fonts scripts \
      samples/manual .github/workflows
    echo "body {}" > templates/manual/styles/lists.css
    echo "body {}" > shared/styles/base.css
    echo "font" > shared/fonts/Roboto.woff2
    echo "<svg/>" > shared/brand.svg
    echo "<svg/>" > shared/brand-print.svg
    echo "<svg/>" > shared/brand-symbol.svg
    echo "#!/bin/sh" > scripts/build-docs-pdf.sh
    echo "#!/bin/sh" > scripts/fetch-theme.sh
    echo "#!/bin/sh" > scripts/install-samples.sh
    echo "# Readme" > README.md
    echo "# Changelog" > CHANGELOG.md
    echo "0.1.0" > version.txt
    echo "# Sample" > samples/manual/index.md
    echo "name: CI" > .github/workflows/ci.yml
    echo "shared notes" > shared/notes.txt
    git add -A
    git commit -q -m "Initial"
  )
  echo "$repo"
}

# change <repo> <path>...: append a line to each path and commit.
change() {
  local repo="$1"
  shift
  local path
  for path in "$@"; do
    mkdir -p "$repo/$(dirname "$path")"
    echo "changed" >> "$repo/$path"
  done
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "Change $*"
}

# expect_fail <repo> <description> [needle...]: the guard exits non-zero
# and its output names every needle.
expect_fail() {
  local repo="$1" description="$2"
  shift 2
  local output needle
  if output="$(cd "$repo" && "$GUARD" 2>&1)"; then
    die "$description: expected a non-zero exit, got:"$'\n'"$output"
  fi
  for needle in "$@"; do
    case "$output" in
      *"$needle"*) ;;
      *) die "$description: output did not mention '$needle':"$'\n'"$output" ;;
    esac
  done
  ok "$description"
}

# expect_pass <repo> <description> [needle...]
expect_pass() {
  local repo="$1" description="$2"
  shift 2
  local output needle
  if ! output="$(cd "$repo" && "$GUARD" 2>&1)"; then
    die "$description: expected a zero exit, got:"$'\n'"$output"
  fi
  for needle in "$@"; do
    case "$output" in
      *"$needle"*) ;;
      *) die "$description: output did not mention '$needle':"$'\n'"$output" ;;
    esac
  done
  ok "$description"
}

# --- nothing changed since the last version tag ------------------------

repo="$(new_repo unchanged)"
git -C "$repo" tag 0.1.0
expect_fail "$repo" "fails when HEAD is the last version tag" \
  "byte-identical between 0.1.0 and HEAD" "templates" "shared/fonts" \
  "scripts/fetch-theme.sh"

# An empty commit on top changes nothing either.
git -C "$repo" commit -q --allow-empty -m "Empty"
expect_fail "$repo" "fails when nothing changed since the last version tag" \
  "byte-identical"

# --- only paths outside the surface changed ----------------------------

repo="$(new_repo outside)"
git -C "$repo" tag 0.1.0
change "$repo" README.md samples/manual/index.md .github/workflows/ci.yml \
  CHANGELOG.md version.txt shared/notes.txt scripts/install-samples.sh \
  .release-please-manifest.json
expect_fail "$repo" "fails when only paths outside the surface changed" \
  "byte-identical"

# --- a surface path changed --------------------------------------------

for path in \
  templates/manual/styles/lists.css \
  templates/api-reference/styles/api.css \
  shared/styles/base.css \
  shared/fonts/Roboto.woff2 \
  shared/brand.svg \
  shared/brand-print.svg \
  shared/brand-symbol.svg \
  scripts/build-docs-pdf.sh \
  scripts/fetch-theme.sh; do
  repo="$(new_repo "surface-${path//\//-}")"
  git -C "$repo" tag 0.1.0
  change "$repo" README.md "$path"
  expect_pass "$repo" "passes when $path changed" \
    "differs between 0.1.0 and HEAD"
done

# A surface file removed is a change too.
repo="$(new_repo surface-removed)"
git -C "$repo" tag 0.1.0
git -C "$repo" rm -q shared/brand-symbol.svg
git -C "$repo" commit -q -m "Remove the symbol"
expect_pass "$repo" "passes when a surface file was removed" "differs"

# --- no plain version tag ----------------------------------------------

repo="$(new_repo untagged)"
expect_pass "$repo" "passes when no tag exists" "No plain version tag"

git -C "$repo" tag v0.1.0
git -C "$repo" tag 0.1.0-rc.1
git -C "$repo" tag release-0.1.0
expect_pass "$repo" "passes when only tags that are not plain versions exist" \
  "No plain version tag"

# --- several version tags ----------------------------------------------

# 0.9.0 and 0.10.0 have different surfaces; HEAD has 0.10.0's. Version
# order puts 0.10.0 last, where a plain string sort would pick 0.9.0. A
# `v`-prefixed tag above both is not a plain version and is ignored.
repo="$(new_repo several)"
git -C "$repo" tag 0.2.0
change "$repo" templates/manual/styles/lists.css
git -C "$repo" tag 0.9.0
change "$repo" shared/styles/base.css
git -C "$repo" tag 0.10.0
change "$repo" README.md
git -C "$repo" tag v9.9.9
expect_fail "$repo" "compares against the newest plain version tag" \
  "byte-identical between 0.10.0 and HEAD"

change "$repo" scripts/fetch-theme.sh
expect_pass "$repo" "passes once the surface differs from the newest tag" \
  "differs between 0.10.0 and HEAD"

# The newest tag by version, even when it is not the most recent commit:
# HEAD's surface equals 0.3.0's, which was tagged on an older commit.
repo="$(new_repo out-of-order)"
git -C "$repo" tag 0.3.0
change "$repo" templates/manual/styles/lists.css
git -C "$repo" tag 0.2.5
git -C "$repo" reset -q --hard 0.3.0
change "$repo" README.md
expect_fail "$repo" "uses version order, not commit order" \
  "byte-identical between 0.3.0 and HEAD"

# --- refusals ----------------------------------------------------------

repo="$(new_repo arguments)"
git -C "$repo" tag 0.1.0
change "$repo" scripts/fetch-theme.sh
output="$(cd "$repo" && "$GUARD" 0.2.0 2>&1)" && die "accepted an argument"
case "$output" in
  *usage*) ok "refuses an argument with a usage message" ;;
  *) die "argument refusal did not print usage:"$'\n'"$output" ;;
esac

# A shallow clone cannot be trusted to hold the tag's tree.
source_repo="$(new_repo shallow-source)"
git -C "$source_repo" tag 0.1.0
change "$source_repo" scripts/fetch-theme.sh
git clone -q --depth 1 "file://$source_repo" "$WORK/shallow" 2> /dev/null
expect_fail "$WORK/shallow" "refuses a shallow clone" "shallow"

echo "All release-surface checks passed."
