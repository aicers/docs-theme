#!/usr/bin/env bash
# Install this checkout's theme into each sample from local source.
#
# Usage:
#   ./scripts/install-samples.sh          # install into all samples
#   ./scripts/install-samples.sh manual   # install into "manual" only
#
# The docs/theme/ tree inside a sample is generated, not committed, so
# every harness that builds or serves a sample (CI, serve-samples.sh)
# must lay it down first for the sample's
# `INHERIT: docs/theme/mkdocs-base.yml` to resolve. The install is driven
# by the sample's committed docs/theme.toml and reaches no network.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SAMPLES_DIR="$REPO_ROOT/samples"
FETCH="$SCRIPT_DIR/fetch-theme.sh"

filter="${1:-}"

if [[ ! -d "$SAMPLES_DIR" ]]; then
  echo "No samples/ directory found" >&2
  exit 1
fi

for sample_dir in "$SAMPLES_DIR"/*/; do
  name="$(basename "$sample_dir")"

  if [[ -n "$filter" && "$name" != "$filter" ]]; then
    continue
  fi

  if [[ ! -f "$sample_dir/mkdocs.yml" ]]; then
    continue
  fi

  echo "Installing theme into sample: $name"
  (cd "$sample_dir" && "$FETCH" --source "$REPO_ROOT")
done
