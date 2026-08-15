#!/usr/bin/env bash
# Village Network Demo — two Ferrum containers on one laptop.
# This is a compose simulation, not two Raspberry Pis and not a rural-WiFi proof.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
COMPOSE_FILE="$ROOT/demo/scenarios/village-network/docker-compose.village.yml"
GATEWAY_A="http://127.0.0.1:18081"
GATEWAY_B="http://127.0.0.1:18082"

echo "Village Network simulation: two Ferrum containers (Kisumu + Nouna labels)."
echo "Not a hardware, WAN, or GA4GH-conformance proof. See docs/CLAIMS.md."

: "${FERRUM_IMAGE:?set FERRUM_IMAGE to a version tag or digest}"
case "$FERRUM_IMAGE" in
  *:latest|*:latest-arm64|*:latest-amd64)
    echo "Refuse :latest. Pin FERRUM_IMAGE (tag or digest)." >&2
    exit 3
    ;;
esac
export FERRUM_IMAGE

docker compose -f "$COMPOSE_FILE" up -d --wait

echo "[demo] Waiting for Beacon v2 on both nodes..."
for gw in "$GATEWAY_A" "$GATEWAY_B"; do
  for i in $(seq 1 30); do
    if curl -fsS "$gw/ga4gh/beacon/v2/info" > /dev/null 2>&1; then
      echo "[demo] $gw up"
      break
    fi
    if [[ $i -eq 30 ]]; then
      echo "[demo] $gw did not respond — set FERRUM_IMAGE to a digest that includes Beacon." >&2
      exit 1
    fi
    sleep 2
  done
done

python3 "$ROOT/demo/lib/africa_scenarios.py" \
  --gateway "$GATEWAY_A" --scenario ont_ingestion --organism Plasmodium_falciparum

python3 "$ROOT/demo/lib/africa_scenarios.py" \
  --gateway "$GATEWAY_B" --scenario ont_ingestion --organism Mycobacterium_tuberculosis

RESULT=$(curl -fsS "$GATEWAY_A/ga4gh/beacon/v2/g_variants?federate=true" || echo '{}')
python3 - "$RESULT" <<'PY'
import json, sys
d = json.loads(sys.argv[1] or "{}")
peers = (d.get("meta") or {}).get("federation", {}).get("peers_queried") or []
count = (d.get("responseSummary") or {}).get("numTotalResults", 0)
print(f"Federated query: results={count} peers_queried={peers}")
if not peers:
    print("No federation.peers_queried in response — stock Ferrum ignores FERRUM_FEDERATION__* until implemented.")
PY

echo "Taking Nouna container down (process stop, not a WAN outage)..."
docker compose -f "$COMPOSE_FILE" stop ferrum-nouna
RESULT2=$(curl -fsS "$GATEWAY_A/ga4gh/beacon/v2/g_variants?federate=true" || echo '{}')
python3 - "$RESULT2" <<'PY'
import json, sys
d = json.loads(sys.argv[1] or "{}")
warnings = (d.get("meta") or {}).get("warnings") or []
print(f"After Nouna stop: warnings={warnings}")
PY

docker compose -f "$COMPOSE_FILE" start ferrum-nouna
sleep 5
AUDIT=$(curl -fsS "$GATEWAY_B/api/v1/audit/residency/verify" 2>/dev/null || echo '{"chain_valid": null}')

python3 - "$ROOT" "$GATEWAY_A" "$GATEWAY_B" "$RESULT" "$RESULT2" "$AUDIT" <<'PY'
import json, sys
from pathlib import Path
root, ga, gb, r1, r2, audit = sys.argv[1:7]
d1 = json.loads(r1 or "{}")
d2 = json.loads(r2 or "{}")
av = json.loads(audit or "{}")
peers = (d1.get("meta") or {}).get("federation", {}).get("peers_queried") or []
chain = av.get("chain_valid")
result = {
    "demo": "village-network",
    "simulation": True,
    "hardware": "two Docker containers on one host",
    "claims": {
        "two_physical_raspberry_pis": False,
        "rural_wifi_traffic_shaped": False,
        "ga4gh_conformance_suite_ran": False,
        "federation_peers_queried": bool(peers),
        "audit_chain_valid": chain is True,
    },
    "nodes": [
        {"label": "Kisumu-Lab-Kenya", "gateway": ga},
        {"label": "Nouna-Lab-Burkina-Faso", "gateway": gb},
    ],
    "federated_query": {
        "peers_queried": peers,
        "numTotalResults": (d1.get("responseSummary") or {}).get("numTotalResults"),
    },
    "after_nouna_stop": {
        "warnings": (d2.get("meta") or {}).get("warnings") or [],
    },
    "audit_verify": {"chain_valid": chain, "entry_count": av.get("entry_count")},
    "ga4gh_compliant": False,
    "note": "ga4gh_compliant is never set true by this script. Use HelixTest for conformance.",
}
out = Path(root) / "results"
out.mkdir(exist_ok=True)
(out / "village-network-demo.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"ok": True, "wrote": str(out / "village-network-demo.json"), "claims": result["claims"]}))
if chain is False:
    raise SystemExit("audit chain_valid is false")
PY

echo "Village simulation finished. See results/village-network-demo.json (not a conformance certificate)."
