#!/usr/bin/env bash
# Validate tangible evidence artefacts from a prior ./run (no stack required).
# STRICT=1 or argv --strict also requires Crypt4GH-at-rest micro (./run --macro).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/results"
STRICT="${FERRUM_GA4GH_EVIDENCE_STRICT:-0}"
for a in "$@"; do
  case "$a" in
    --strict) STRICT=1 ;;
  esac
done

fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "OK: $*"; }

[[ -d "$OUT" ]] || fail "no results/ — run: ./run"

need=(benchmark.json metrics.json drs_micro.json query.vcf.gz)
for f in "${need[@]}"; do
  [[ -f "$OUT/$f" ]] || fail "missing $OUT/$f"
done
ok "core artefacts present"

python3 - "$OUT" "$STRICT" <<'PY'
import json, sys
from pathlib import Path
out = Path(sys.argv[1])
strict = sys.argv[2] == "1"

b = json.loads((out / "benchmark.json").read_text())
for k in ("precision", "recall", "f1_score"):
    if k not in b:
        raise SystemExit(f"benchmark missing {k}: {b}")
    if not isinstance(b[k], (int, float)):
        raise SystemExit(f"benchmark {k} not numeric: {b[k]}")
print(f"OK: hap.py F1={b['f1_score']} precision={b['precision']} recall={b['recall']}")

m = json.loads((out / "metrics.json").read_text())
rid = m.get("wes_run_id") or m.get("wes_id")
if not rid:
    raise SystemExit(f"metrics missing wes_run_id: keys={sorted(m)}")
print(f"OK: WES run {rid} engine={m.get('wes_engine')}")

d = json.loads((out / "drs_micro.json").read_text())
plain = d.get("plain")
if not isinstance(plain, dict) or "wall_seconds" not in plain and "samples" not in plain:
    # accept either wall_seconds or samples list
    if not isinstance(plain, dict):
        raise SystemExit(f"drs_micro.plain missing/invalid: {d}")
print("OK: DRS micro plain present")

if (out / "africa_results.json").exists():
    a = json.loads((out / "africa_results.json").read_text())
    s = a.get("summary") or {}
    if s.get("all_passed") is not True:
        raise SystemExit(f"africa all_passed expected true: {s}")
    print(f"OK: africa summary {s}")

if strict:
    at = d.get("crypt4gh_at_rest")
    if not isinstance(at, dict):
        raise SystemExit(
            "STRICT: crypt4gh_at_rest missing — re-run: ./run --macro"
        )
    print("OK: Crypt4GH at-rest micro present (strict)")

print("PASS smoke-evidence" + ("-strict" if strict else ""))
PY
