#!/usr/bin/env bash
# Fetch a specific version and template from docs-theme and install it
# into the consuming project's docs/.theme/ directory.
#
# Usage:
#   ./scripts/fetch-theme.sh --version 1.0.0 --template manual
#
# Requirements: gh (GitHub CLI), tar
set -euo pipefail

REPO="aicers/docs-theme"
VERSION=""
TEMPLATE=""
DEST="docs/.theme"

usage() {
  echo "Usage: $0 --version <version> --template <template>" >&2
  echo "  --version   Release tag (e.g. 1.0.0)" >&2
  echo "  --template  Template name (e.g. manual, api-reference)" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)  VERSION="$2"; shift 2 ;;
    --template) TEMPLATE="$2"; shift 2 ;;
    *) usage ;;
  esac
done

if [[ -z "$VERSION" || -z "$TEMPLATE" ]]; then
  usage
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Fetching docs-theme $VERSION (template: $TEMPLATE)..."
gh release download "$VERSION" \
  --repo "$REPO" \
  --archive tar.gz \
  --dir "$WORK_DIR"

ARCHIVE="$(ls "$WORK_DIR"/*.tar.gz)"
tar -xzf "$ARCHIVE" -C "$WORK_DIR"

EXTRACTED="$(ls -d "$WORK_DIR"/docs-theme-*/)"

TEMPLATE_DIR="$EXTRACTED/templates/$TEMPLATE"
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "Error: template '$TEMPLATE' not found in release $VERSION" >&2
  exit 1
fi

SHARED_DIR="$EXTRACTED/shared"

rm -rf "$DEST"
mkdir -p "$DEST"

cp -r "$TEMPLATE_DIR"/styles "$DEST"/
if [[ -d "$TEMPLATE_DIR/pdf" ]]; then
  cp -r "$TEMPLATE_DIR"/pdf "$DEST"/
fi

if [[ -d "$SHARED_DIR/fonts" ]]; then
  mkdir -p "$DEST/fonts"
  cp -r "$SHARED_DIR"/fonts/* "$DEST"/fonts/
fi

if [[ -f "$SHARED_DIR/brand.svg" ]]; then
  cp "$SHARED_DIR/brand.svg" "$DEST"/
fi

echo "$VERSION" > "$DEST/.version"
echo "Installed docs-theme $VERSION ($TEMPLATE) into $DEST"
