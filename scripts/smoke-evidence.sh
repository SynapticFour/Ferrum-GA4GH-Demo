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

need=(benchmark.json metrics.json drs_micro.json query.vcf.gz RUN_MANIFEST.json)
for f in "${need[@]}"; do
  [[ -f "$OUT/$f" ]] || fail "missing $OUT/$f"
done
ok "core artefacts present"

python3 - "$OUT" "$STRICT" "$ROOT" <<'PY'
import json, sys
from pathlib import Path

out = Path(sys.argv[1])
strict = sys.argv[2] == "1"
root = Path(sys.argv[3])
sys.path.insert(0, str(root / "demo" / "lib"))
from evidence_contract import residency_ok

b = json.loads((out / "benchmark.json").read_text())
for k in ("precision", "recall", "f1_score"):
    if k not in b:
        raise SystemExit(f"benchmark missing {k}: {b}")
    if not isinstance(b[k], (int, float)) and b[k] is not None:
        raise SystemExit(f"benchmark {k} not numeric: {b[k]}")
if b.get("caller_uses_truth_alleles") is True:
    raise SystemExit("benchmark.caller_uses_truth_alleles must not be true")
print(f"OK: hap.py F1={b['f1_score']} precision={b['precision']} recall={b['recall']}")

m = json.loads((out / "metrics.json").read_text())
rid = m.get("wes_run_id") or m.get("wes_id")
if not rid:
    raise SystemExit(f"metrics missing wes_run_id: keys={sorted(m)}")
print(f"OK: WES run {rid} engine={m.get('wes_engine')}")

d = json.loads((out / "drs_micro.json").read_text())
plain = d.get("plain")
if not isinstance(plain, dict):
    raise SystemExit(f"drs_micro.plain missing/invalid: {d}")
print("OK: DRS micro plain present")

manifest = json.loads((out / "RUN_MANIFEST.json").read_text())
if manifest.get("trs", {}).get("descriptor_executed_as_wes") is True:
    raise SystemExit("RUN_MANIFEST must not claim TRS descriptor was executed as WES")
if "what_this_run_is_not" not in manifest:
    raise SystemExit("RUN_MANIFEST missing what_this_run_is_not")
if manifest.get("hap_py", {}).get("cite") is True and manifest.get("caller", {}).get("uses_truth_alleles") is not False:
    raise SystemExit("RUN_MANIFEST hap_py.cite true but caller used truth alleles")
print("OK: RUN_MANIFEST honesty block present")

if (out / "africa_results.json").exists():
    a = json.loads((out / "africa_results.json").read_text())
    s = a.get("summary") or {}
    if s.get("verdict") == "failed" or (s.get("errors") or 0) > 0:
        raise SystemExit(f"africa verdict failed: {s}")
    if s.get("all_passed") is True and (s.get("ran") or 0) == 0:
        raise SystemExit(f"africa all_passed true with ran=0 (skip is not a pass): {s}")
    for name, sc in (a.get("scenarios") or {}).items():
        if sc.get("skipped"):
            continue
        if "chain_valid" in sc and not residency_ok(sc.get("chain_valid")):
            raise SystemExit(f"africa {name}: chain_valid not true: {sc}")
    print(f"OK: africa summary {s}")

if (out / "co_deploy_results.json").exists():
    c = json.loads((out / "co_deploy_results.json").read_text())
    s = c.get("summary") or {}
    if s.get("verdict") == "failed" or (s.get("errors") or 0) > 0:
        raise SystemExit(f"co_deploy verdict failed: {s}")
    if s.get("all_passed") is True and (s.get("ran") or 0) == 0:
        raise SystemExit(f"co_deploy all_passed true with ran=0: {s}")
    print(f"OK: co_deploy summary {s}")

if strict:
    at = d.get("crypt4gh_at_rest")
    if not isinstance(at, dict):
        raise SystemExit(
            "STRICT: crypt4gh_at_rest missing — re-run: ./run --macro"
        )
    print("OK: Crypt4GH at-rest micro present (strict)")

print("PASS smoke-evidence" + ("-strict" if strict else ""))
PY
