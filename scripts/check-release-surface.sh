#!/usr/bin/env bash
# Guard against releasing a version consumers cannot fetch anything from.
#
# The "release surface" is exactly what fetch-theme.sh installs into a
# consumer, plus fetch-theme.sh itself, which a consumer copies. A release
# whose surface is byte-identical to the previous release's produces an
# empty-diff version-bump pull request in every consumer, so this guard
# rejects it. samples/, .github/, README.md, CHANGELOG.md, version.txt,
# and lint configuration are repo-internal and are not part of the
# surface.
#
# Usage:
#   ./scripts/check-release-surface.sh
#
# Compares the surface at HEAD with the surface at the last version tag:
# the newest plain MAJOR.MINOR.PATCH tag (no `v`, no suffix) by version
# order. CI runs it on the release pull request right before it is
# merged, so HEAD is the commit that would be tagged. When no plain
# version tag exists there is nothing to compare against, and the guard
# passes.
#
# Requires the repository history and tags to be present: run after an
# actions/checkout with fetch-depth: 0 and fetch-tags: true. A shallow
# clone is refused outright rather than allowed to pass by comparing
# against a tag it cannot read.
set -euo pipefail

if [ "$#" -ne 0 ]; then
  echo "usage: check-release-surface.sh (takes no arguments)" >&2
  exit 2
fi

# Paths fetch-theme.sh installs into a consumer, plus fetch-theme.sh
# itself. templates/ is compared whole so all four templates are covered
# by byte-diff, even the ones no sample exercises.
SURFACE_PATHS=(
  templates
  shared/styles/base.css
  shared/fonts
  shared/brand.svg
  shared/brand-print.svg
  shared/brand-symbol.svg
  scripts/build-docs-pdf.sh
  scripts/fetch-theme.sh
)

if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
  echo "This clone is shallow, so the last version tag may be unreadable." >&2
  echo "Check out the full history and the tags (fetch-depth: 0)." >&2
  exit 2
fi

# The newest plain version tag, by MAJOR.MINOR.PATCH order.
last_tag="$(git tag --list | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1 || true)"

if [ -z "$last_tag" ]; then
  echo "No plain version tag exists; skipping release-surface comparison."
  exit 0
fi

git rev-parse --verify --quiet "$last_tag^{commit}" > /dev/null || {
  echo "Cannot read the commit of $last_tag." >&2
  exit 2
}

echo "Comparing release surface: $last_tag -> HEAD"

# 0 is identical, 1 differs; anything else is an error, which must not
# be mistaken for a difference.
status=0
git diff --quiet "$last_tag" HEAD -- "${SURFACE_PATHS[@]}" || status=$?

case "$status" in
  0)
    cat >&2 <<EOF
Release surface is byte-identical between $last_tag and HEAD.

There is nothing for consumers to fetch: fetch-theme.sh would install the
same tree it installed for $last_tag, so releasing HEAD only produces an
empty-diff version-bump pull request in every consumer. Leave the release
pull request open until a change to the surface lands.

Compared paths:
$(printf '  %s\n' "${SURFACE_PATHS[@]}")
EOF
    exit 1
    ;;
  1)
    echo "Release surface differs between $last_tag and HEAD; proceeding."
    ;;
  *)
    echo "git diff failed comparing $last_tag with HEAD (exit $status)." >&2
    exit 2
    ;;
esac
