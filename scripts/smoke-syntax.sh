#!/usr/bin/env bash
# Static checks matching .github/workflows/ci.yml (no Docker stack).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash -n run
bash -n demo/run.sh
while IFS= read -r -d '' f; do
  bash -n "$f"
done < <(find scripts benchmark demo -type f -name '*.sh' -print0 2>/dev/null | sort -z)

python3 -m compileall -q demo/lib scripts

bash -n demo/scenarios/village-network/run-village-demo.sh
bash -n demo/scenarios/raspberry-pi/install-ferrum-edge.sh
docker compose -f demo/scenarios/village-network/docker-compose.village.yml config >/dev/null

python3 -c "
from pathlib import Path
import sys
sys.path.insert(0, 'demo/lib')
import africa_feature_detect, africa_scenarios, infra_feature_detect, co_deploy_scenarios
fs = africa_feature_detect.detect('http://127.0.0.1:1')
assert not fs.any_available()
ifs = infra_feature_detect.detect(
    broker='http://127.0.0.1:1',
    visa_registry='http://127.0.0.1:1',
    service_registry='http://127.0.0.1:1',
    ads='http://127.0.0.1:1',
)
assert not ifs.any_available()
print('OK: imports + graceful degrade')
"

test -f docs/COVERAGE.md
test -f PINNED_VERSIONS.txt
grep -q 'smoke-evidence' Makefile
echo "PASS smoke-syntax"
