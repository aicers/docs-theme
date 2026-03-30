#!/usr/bin/env bash
# Serve all sample sites simultaneously on different ports.
#
# Usage:
#   ./scripts/serve-samples.sh          # start all samples
#   ./scripts/serve-samples.sh manual   # start only "manual"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SAMPLES_DIR="$REPO_ROOT/samples"
BASE_PORT=8000

if [[ ! -d "$SAMPLES_DIR" ]]; then
  echo "No samples/ directory found" >&2
  exit 1
fi

PIDS=()

cleanup() {
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

port=$BASE_PORT

filter="${1:-}"

echo "Starting sample servers..."
echo ""

for sample_dir in "$SAMPLES_DIR"/*/; do
  name="$(basename "$sample_dir")"

  if [[ -n "$filter" && "$name" != "$filter" ]]; then
    continue
  fi

  if [[ ! -f "$sample_dir/mkdocs.yml" ]]; then
    continue
  fi

  (cd "$sample_dir" && mkdocs serve --dev-addr "127.0.0.1:$port" --quiet) &
  PIDS+=($!)

  printf "  %-20s http://127.0.0.1:%d\n" "$name" "$port"
  port=$((port + 1))
done

if [[ ${#PIDS[@]} -eq 0 ]]; then
  echo "No samples found to serve." >&2
  exit 1
fi

echo ""
echo "Press Ctrl+C to stop all servers."
wait
