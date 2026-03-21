#!/usr/bin/env bash
# GA4GH TRS (Dockstore): download primary WDL descriptor JSON and write cached .wdl (Broad GATK germline bundle).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/workflows/cached}"
TOOL_ID='#workflow/github.com/alexanderhsieh/gatk4-germline-snps-indels/gatk4-germline-snps-indels-AH'
VERSION="${DOCKSTORE_VERSION:-master}"
mkdir -p "$OUT"

ENC_TOOL=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TOOL_ID', safe=''))")
URL="https://dockstore.org/api/ga4gh/trs/v2/tools/${ENC_TOOL}/versions/${VERSION}/WDL/descriptor"

echo "[trs] GET $URL"
curl -fsSL "$URL" | python3 -c "import json,sys; d=json.load(sys.stdin); open(sys.argv[1],'w').write(d['content'])" "$OUT/gatk4-germline-snps-indels.cached.wdl"
echo "[trs] Cached -> $OUT/gatk4-germline-snps-indels.cached.wdl ($(wc -c < "$OUT/gatk4-germline-snps-indels.cached.wdl") bytes)"
