#!/usr/bin/env bash
# Copy selected results/*.json into docs/paper/<stamp>/ for version-controlled paper artefacts.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="${1:-$(date -u +%Y%m%dT%H%MZ)}"
DEST="$ROOT/docs/paper/$STAMP"
mkdir -p "$DEST"
for f in \
  metrics.json \
  benchmark.json \
  drs_micro.json \
  engine_compare.json \
  dataset_profile.json \
  phase2_pass_primary.json \
  phase2_pass_plain.json \
  phase2_pass_crypt4gh.json \
  benchmark.phase2_plain.json \
  benchmark.phase2_crypt4gh.json \
  wes_request.json \
  interval.txt \
  drs_mapping_phase_plain.json; do
  if [[ -f "$ROOT/results/$f" ]]; then
    cp -f "$ROOT/results/$f" "$DEST/$f"
  fi
done
echo "$DEST"
