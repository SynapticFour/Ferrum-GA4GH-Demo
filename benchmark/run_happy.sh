#!/usr/bin/env bash
# hap.py vs GIAB truth (image built from benchmark/Dockerfile.happy).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${HAPPY_IMAGE:-ferrum-ga4gh-happy:latest}"
# Image is linux/amd64 (Bioconda); required on arm64 hosts.
HAPPY_PLATFORM="${HAPPY_PLATFORM:-linux/amd64}"
TRUTH="${TRUTH_VCF:-$ROOT/data/truth_slice.vcf.gz}"
QUERY="${QUERY_VCF:-$ROOT/results/query.vcf.gz}"
REF="${REF_FASTA:-$ROOT/data/ref_slice.fa}"
BED="${BENCH_BED:-$ROOT/data/bench_slice.bed}"
JSON_OUT="${BENCHMARK_JSON:-$ROOT/results/benchmark.json}"

mkdir -p "$ROOT/results"

for f in "$TRUTH" "$QUERY" "$REF" "$BED"; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "[happy] building $IMAGE (first run may take several minutes)..."
  docker build --platform "$HAPPY_PLATFORM" -t "$IMAGE" -f "$ROOT/benchmark/Dockerfile.happy" "$ROOT/benchmark"
fi

echo "[happy] running hap.py (vcfeval)..."

docker run --rm --platform "$HAPPY_PLATFORM" \
  -v "$ROOT:/work" \
  "$IMAGE" \
  hap.py /work/data/truth_slice.vcf.gz /work/results/query.vcf.gz \
    -r /work/data/ref_slice.fa \
    -f /work/data/bench_slice.bed \
    -o /work/results/happy \
    --engine=vcfeval \
    --threads=2

SUMMARY="$ROOT/results/happy.metrics.json.gz"
LEGACY="$ROOT/results/happy.summary.json"
if [[ ! -f "$SUMMARY" ]]; then
  SUMMARY="$LEGACY"
fi
[[ -f "$SUMMARY" ]] || { echo "missing hap.py output (expected $ROOT/results/happy.metrics.json.gz)" >&2; exit 1; }

python3 - "$SUMMARY" "$JSON_OUT" <<'PY'
import gzip, json, math, sys
from pathlib import Path

src = Path(sys.argv[1])
out_json = Path(sys.argv[2])

if str(src).endswith(".gz"):
    data = json.loads(gzip.open(src, "rt").read())
else:
    data = json.loads(src.read_text())

precision = recall = f1 = None

blocks = data.get("metrics") or []
if blocks and isinstance(blocks[0], dict):
    cols = {r["id"]: r.get("values") for r in blocks[0].get("data", []) if r.get("id")}
    def col(name, i=0):
        v = cols.get(name)
        return v[i] if v and len(v) > i else None

    recall = col("METRIC.Recall", 0)
    precision = col("METRIC.Precision", 0)
    f1 = col("METRIC.F1_Score", 0)

if precision is None:
    def walk(o):
        global precision, recall, f1
        if isinstance(o, dict):
            if "precision" in o and "recall" in o and precision is None:
                precision, recall = o["precision"], o["recall"]
                f1 = o.get("f1_score") or o.get("f1")
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)

    walk(data)

def num(x):
    if x is None:
        return None
    if isinstance(x, float) and math.isnan(x):
        return None
    try:
        return float(x)
    except (TypeError, ValueError):
        return None

p, r, f = num(precision), num(recall), num(f1)
if f is None and p is not None and r is not None:
    f = 0.0 if (p + r) == 0 else 2 * p * r / (p + r)

out = {
    "precision": p,
    "recall": r,
    "f1_score": f,
    "summary_source": str(src),
}
out_json.write_text(json.dumps(out, indent=2))
print(out_json.read_text())
PY
