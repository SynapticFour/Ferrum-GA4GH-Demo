#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
echo "ci-check: compileall"
python3 -m compileall -q demo/lib scripts
echo "ci-check: bash -n key scripts"
bash -n demo/scenarios/village-network/run-village-demo.sh
bash -n demo/scenarios/raspberry-pi/install-ferrum-edge.sh
echo "ci-check: OK (core CI smoke; compose/import jobs remain in CI)"
