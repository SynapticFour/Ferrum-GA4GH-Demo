#!/usr/bin/env bash
# GA4GH TRS (Dockstore): fetch a descriptor to prove the TRS client path.
# This descriptor is NOT executed. WES runs workflows/tiny_hc.wdl (or .nf).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/workflows/cached}"
TOOL_ID='#workflow/github.com/alexanderhsieh/gatk4-germline-snps-indels/gatk4-germline-snps-indels-AH'
VERSION="${DOCKSTORE_VERSION:-master}"
mkdir -p "$OUT" "$ROOT/results"

ENC_TOOL=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TOOL_ID', safe=''))")
URL="https://dockstore.org/api/ga4gh/trs/v2/tools/${ENC_TOOL}/versions/${VERSION}/WDL/descriptor"

echo "[trs] GET $URL (descriptor fetch only — not submitted to WES)"
curl -fsSL "$URL" | python3 -c "import json,sys; d=json.load(sys.stdin); open(sys.argv[1],'w').write(d['content'])" "$OUT/gatk4-germline-snps-indels.cached.wdl"
BYTES=$(wc -c < "$OUT/gatk4-germline-snps-indels.cached.wdl" | tr -d ' ')
echo "[trs] Cached -> $OUT/gatk4-germline-snps-indels.cached.wdl ($BYTES bytes)"
python3 - "$ROOT/results/trs_fetch.json" "$TOOL_ID" "$VERSION" "$URL" "$BYTES" <<'PY'
import json, sys
from pathlib import Path
Path(sys.argv[1]).write_text(json.dumps({
    "tool_id": sys.argv[2],
    "version": sys.argv[3],
    "url": sys.argv[4],
    "bytes": int(sys.argv[5]),
    "executed": False,
    "wes_workflow": "in-repo workflows/tiny_hc.wdl or tiny_hc.nf",
}, indent=2) + "\n", encoding="utf-8")
PY
