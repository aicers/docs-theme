#!/usr/bin/env bash
# Guard against cutting a release that consumers cannot fetch anything from.
#
# The "release surface" is exactly what fetch-theme.sh installs into a
# consumer, plus fetch-theme.sh itself, which a consumer copies. A tag
# whose surface is byte-identical to the previous tag's produces an
# empty-diff version-bump pull request in every consumer, so this guard
# rejects it. samples/, .github/, README.md, CHANGELOG.md, and lint
# configuration are repo-internal and are not part of the surface.
#
# Usage:
#   ./scripts/check-release-surface.sh <new-tag>
#
# The previous tag is resolved by MAJOR.MINOR.PATCH ordering over the
# repo's release tags (the release.yml pattern [0-9]+.[0-9]+.[0-9]+).
# When no predecessor exists -- the first tag ever, or a tag that sorts
# below every existing one -- the guard passes without comparing.
#
# Requires the repository history and tags to be present: run after an
# actions/checkout with fetch-depth: 0 and fetch-tags: true, otherwise
# the previous tag cannot resolve or be read.
set -euo pipefail

NEW_TAG="${1:?usage: check-release-surface.sh <new-tag>}"

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

# All release tags in ascending MAJOR.MINOR.PATCH order.
tags="$(git tag --list | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V || true)"

# The predecessor is the tag immediately before NEW_TAG in that order.
# grep -B1 prints the line before the match together with the match; the
# first line of that is the predecessor. If NEW_TAG is the first (or the
# only) release tag, that first line is NEW_TAG itself -- no predecessor.
prev_tag="$(printf '%s\n' "$tags" | grep -B1 -Fx "$NEW_TAG" | head -n1 || true)"

if [ -z "$prev_tag" ] || [ "$prev_tag" = "$NEW_TAG" ]; then
  echo "No predecessor tag for $NEW_TAG; skipping release-surface comparison."
  exit 0
fi

echo "Comparing release surface: $prev_tag -> $NEW_TAG"

if git diff --quiet "$prev_tag" "$NEW_TAG" -- "${SURFACE_PATHS[@]}"; then
  cat >&2 <<EOF
Release surface is byte-identical between $prev_tag and $NEW_TAG.

There is nothing for consumers to fetch: fetch-theme.sh would install the
same tree it installed for $prev_tag, so cutting $NEW_TAG only produces an
empty-diff version-bump pull request in every consumer. This tag should
not have been cut.

Compared paths:
$(printf '  %s\n' "${SURFACE_PATHS[@]}")
EOF
  exit 1
fi

echo "Release surface differs between $prev_tag and $NEW_TAG; proceeding."
