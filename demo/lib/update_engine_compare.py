#!/usr/bin/env python3
"""Merge latest pipeline timing into results/engine_compare.json for Cromwell vs Nextflow tables."""
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: update_engine_compare.py <repo_root>", file=sys.stderr)
        sys.exit(2)
    root = Path(sys.argv[1]).resolve()
    metrics_path = root / "results" / "metrics.json"
    if not metrics_path.is_file():
        print(json.dumps({"ok": False, "skip": "no metrics.json"}))
        return
    m = json.loads(metrics_path.read_text(encoding="utf-8"))
    eng = (m.get("wes_engine") or "wdl").strip().lower()
    if eng not in ("wdl", "nextflow"):
        eng = "wdl"
    key = "cromwell_wdl" if eng == "wdl" else "nextflow"
    out_path = root / "results" / "engine_compare.json"
    data: dict = {}
    if out_path.is_file():
        data = json.loads(out_path.read_text(encoding="utf-8"))
    data[key] = {
        "wes_engine": eng,
        "pipeline_elapsed_seconds": m.get("pipeline_elapsed_seconds"),
        "wes_run_id": m.get("wes_run_id"),
        "recorded_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(json.dumps({"ok": True, "wrote": str(out_path), "key": key}))


if __name__ == "__main__":
    main()
