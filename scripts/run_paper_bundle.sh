#!/usr/bin/env bash
# Full paper matrix: WDL plain, Nextflow plain, WDL macro (plain + Crypt4GH at-rest DRS ingest).
# Preserves engine_compare Cromwell/Nextflow wall times from the first two runs (macro overwrites metrics).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PAPER_ROOT="$ROOT"
export FERRUM_GA4GH_CRYPT4GH_PUBKEY="$ROOT/demo/fixtures/crypt4gh-node/node.pub"

echo "[paper] 1/3 WDL + DRS micro (plain + Crypt4GH header)..."
./run

echo "[paper] 2/3 Nextflow + DRS micro..."
./run --nextflow

cp -f "$ROOT/results/engine_compare.json" "$ROOT/results/_engine_compare_pre_macro.json"

echo "[paper] 3/3 WDL macro (plaintext vs Crypt4GH-at-rest ingest)..."
./run --macro

python3 <<'PY'
import json
import os
from pathlib import Path
root = Path(os.environ["PAPER_ROOT"])
pre = json.loads((root / "results/_engine_compare_pre_macro.json").read_text(encoding="utf-8"))
curp = root / "results/engine_compare.json"
cur = json.loads(curp.read_text(encoding="utf-8")) if curp.is_file() else {}
for k in ("cromwell_wdl", "nextflow"):
    if k in pre:
        cur[k] = pre[k]
curp.write_text(json.dumps(cur, indent=2), encoding="utf-8")
print(json.dumps({"ok": True, "merged_engine_compare": str(curp)}))
PY

echo "[paper] refresh benchmark.md + README table..."
python3 "$ROOT/scripts/update_docs.py" \
  --repo-root "$ROOT" \
  --metrics "$ROOT/results/metrics.json" \
  --benchmark "$ROOT/results/benchmark.json" \
  --readme "$ROOT/README.md" \
  --bench-md "$ROOT/docs/benchmark.md"

chmod +x "$ROOT/scripts/paper_bundle_snapshot.sh"
STAMP="$(date -u +%Y%m%dT%H%MZ)"
export PAPER_STAMP="$STAMP"
DEST="$(bash "$ROOT/scripts/paper_bundle_snapshot.sh" "$STAMP")"
echo "[paper] snapshot -> $DEST"

python3 <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(os.environ["PAPER_ROOT"])
stamp = os.environ.get("PAPER_STAMP", "unknown")
ferrum = root / ".cache" / "ferrum"
lines = []
lines.append("# Reproducibility (paper bundle)\n")
lines.append(f"Generated (UTC): `{datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%SZ')}`\n")

def sh(cmd: list[str]) -> str:
    try:
        return subprocess.check_output(cmd, cwd=root, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception as e:
        return f"(unavailable: {e})"

lines.append("## Ferrum-GA4GH-Demo\n")
lines.append(
    "- **Git commit (this snapshot):** run `git log -1 --format=%H -- docs/paper/"
    + stamp
    + "` from the repo root after checkout (stable pointer to the tree that contains this folder).\n"
)
lines.append(f"- **Branch:** `{sh(['git', 'rev-parse', '--abbrev-ref', 'HEAD'])}`\n")

lines.append("\n## Upstream Ferrum (clone)\n")
if (ferrum / ".git").is_dir():
    lines.append("- **Path:** `.cache/ferrum`\n")
    lines.append(
        f"- **Commit:** `{subprocess.check_output(['git', '-C', str(ferrum), 'rev-parse', 'HEAD'], text=True).strip()}`\n"
    )
    lines.append(
        f"- **Short:** `{subprocess.check_output(['git', '-C', str(ferrum), 'rev-parse', '--short', 'HEAD'], text=True).strip()}`\n"
    )
else:
    lines.append("- *(clone created on first `./run`)*\n")

lines.append("\n## Host\n")
lines.append(f"- **uname:** `{sh(['uname', '-a'])}`\n")
lines.append(f"- **Python:** `{sys.version.split()[0]}`\n")
lines.append(f"- **Docker:** `{sh(['docker', '--version'])}`\n")
lines.append(f"- **Docker Compose:** `{sh(['docker', 'compose', 'version'])}`\n")
cli_ver = root / ".cache" / "docker-cli-static" / "docker-cli.version"
if cli_ver.is_file():
    lines.append(
        "- **Linux docker CLI (bind-mount into TES / Cromwell):** `"
        + cli_ver.read_text(encoding="utf-8").strip()
        + "` (`scripts/ensure_docker_cli_static.sh`, file `.cache/docker-cli-static/docker-cli.version`)\n"
    )

lines.append("\n## Pinned workflow / executor images (demo)\n")
lines.append(
    "- **Cromwell (WES→TES bash mode):** `broadinstitute/cromwell:93-0232cbd` "
    "(see `vendor/ferrum-overlay/crates/ferrum-wes/src/executors/tes.rs`)\n"
)
lines.append("- **Nextflow (WES→TES):** `nextflow/nextflow:24.10.3`\n")
lines.append("- **GATK (nested):** `broadinstitute/gatk:4.4.0.0` (WDL/NF in-repo workflows)\n")
lines.append("- **hap.py image:** `benchmark/Dockerfile.happy` (micromamba-based)\n")

lines.append("\n## Crypt4GH\n")
lines.append(
    "- **Node keys (demo):** `demo/fixtures/crypt4gh-node/` "
    "(`node.pub` → `FERRUM_GA4GH_CRYPT4GH_PUBKEY`)\n"
)

lines.append("\n## Paper JSON snapshot\n")
lines.append(f"- **Directory:** `docs/paper/{stamp}/`\n")
lines.append("- **Orchestrator:** `bash scripts/run_paper_bundle.sh`\n")

out = root / "docs" / "paper" / stamp / "REPRODUCIBILITY.md"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("".join(lines), encoding="utf-8")
print(out)
PY

echo "[paper] done."
