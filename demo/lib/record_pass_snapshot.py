#!/usr/bin/env python3
"""Write results/phase2_pass_<label>.json after ingest + WES + hap.py for one pipeline pass."""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 7:
        print(
            "usage: record_pass_snapshot.py <label> <elapsed_sec> <run_id> <wf_url> <mem> <repo_root>",
            file=sys.stderr,
        )
        sys.exit(2)
    label, elapsed, run_id, wf_url, mem, root_s = sys.argv[1:7]
    root = Path(root_s).resolve()
    enc = os.environ.get("FERRUM_GA4GH_ENCRYPT_INGEST", "0").lower() in (
        "1",
        "true",
        "yes",
    )
    data: dict = {
        "label": label,
        "pipeline_elapsed_seconds": int(elapsed),
        "wes_run_id": run_id,
        "wes_workflow_url": wf_url,
        "wes_engine": os.environ.get("FERRUM_GA4GH_ENGINE", "wdl"),
        "encrypt_at_ingest": enc,
        "docker_stats_gateway_sample": mem,
    }
    micro = root / "results" / "drs_micro.json"
    if micro.is_file():
        data["drs_micro"] = json.loads(micro.read_text(encoding="utf-8"))
    bench = root / "results" / "benchmark.json"
    if bench.is_file():
        b = json.loads(bench.read_text(encoding="utf-8"))
        data["hap_py"] = {
            "precision": b.get("precision"),
            "recall": b.get("recall"),
            "f1_score": b.get("f1_score"),
        }
    out = root / "results" / f"phase2_pass_{label}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(json.dumps({"ok": True, "wrote": str(out)}))


if __name__ == "__main__":
    main()
