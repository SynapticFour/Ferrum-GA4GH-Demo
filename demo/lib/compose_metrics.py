#!/usr/bin/env python3
"""Build results/metrics.json from per-pass snapshots (single run or Phase 2 macro)."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def load_pass(root: Path, label: str) -> dict:
    p = root / "results" / f"phase2_pass_{label}.json"
    return json.loads(p.read_text(encoding="utf-8"))


def main() -> None:
    if len(sys.argv) != 3:
        print(
            "usage: compose_metrics.py <single|macro> <repo_root>",
            file=sys.stderr,
        )
        sys.exit(2)
    mode, root_s = sys.argv[1:3]
    root = Path(root_s).resolve()

    if mode == "macro":
        plain = load_pass(root, "plain")
        crypt = load_pass(root, "crypt4gh")
        merged_micro_path = root / "results" / "drs_micro.json"
        drs_micro = crypt.get("drs_micro")
        if merged_micro_path.is_file():
            try:
                merged = json.loads(merged_micro_path.read_text(encoding="utf-8"))
                ar = merged.get("crypt4gh_at_rest")
                if isinstance(ar, dict) and not ar.get("skipped") and "wall_seconds" in ar:
                    drs_micro = merged
            except (OSError, json.JSONDecodeError):
                pass
        # Primary table = latest (crypt) for backwards compatibility with update_docs defaults
        out = {
            "phase2_macro": {
                "plain": plain,
                "crypt4gh_at_rest": crypt,
            },
            "pipeline_elapsed_seconds": crypt.get("pipeline_elapsed_seconds"),
            "wes_run_id": crypt.get("wes_run_id"),
            "wes_workflow_url": crypt.get("wes_workflow_url"),
            "wes_engine": crypt.get("wes_engine", "wdl"),
            "encrypt_at_ingest": True,
            "query_vcf": "results/query.vcf.gz",
            "docker_stats_gateway_sample": crypt.get("docker_stats_gateway_sample"),
            "drs_micro": drs_micro,
        }
    else:
        snap = load_pass(root, "primary")
        out = {
            "pipeline_elapsed_seconds": snap.get("pipeline_elapsed_seconds"),
            "wes_run_id": snap.get("wes_run_id"),
            "wes_workflow_url": snap.get("wes_workflow_url"),
            "wes_engine": snap.get("wes_engine", "wdl"),
            "encrypt_at_ingest": bool(snap.get("encrypt_at_ingest")),
            "query_vcf": "results/query.vcf.gz",
            "docker_stats_gateway_sample": snap.get("docker_stats_gateway_sample"),
            "drs_micro": snap.get("drs_micro"),
        }
    (root / "results" / "metrics.json").write_text(
        json.dumps(out, indent=2),
        encoding="utf-8",
    )
    print(json.dumps({"ok": True, "wrote": str(root / "results" / "metrics.json")}))


if __name__ == "__main__":
    main()
