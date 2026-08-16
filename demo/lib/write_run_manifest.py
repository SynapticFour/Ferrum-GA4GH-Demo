#!/usr/bin/env python3
"""Write results/RUN_MANIFEST.json — the artefact a reviewer should read first."""
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def _load(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: write_run_manifest.py <repo_root>", file=sys.stderr)
        sys.exit(2)
    root = Path(sys.argv[1]).resolve()
    out_dir = root / "results"
    bench = _load(out_dir / "benchmark.json")
    metrics = _load(out_dir / "metrics.json")
    prof = _load(out_dir / "dataset_profile.json")
    africa = _load(out_dir / "africa_results.json")
    co = _load(out_dir / "co_deploy_results.json")
    trs = _load(out_dir / "trs_fetch.json")
    synthetic = bool(prof.get("synthetic_subset")) or (root / "data" / "synthetic_manifest.txt").is_file()
    bam = (prof.get("files") or {}).get("input_bam") or {}
    africa_sum = africa.get("summary") or {}
    co_sum = co.get("summary") or {}
    pin = ""
    pin_path = root / "PINNED_VERSIONS.txt"
    if pin_path.is_file():
        for line in pin_path.read_text(encoding="utf-8").splitlines():
            if line.startswith("Ferrum-git="):
                pin = line.split("=", 1)[1].strip()
                break
    hap_blind = bench.get("caller_uses_truth_alleles") is False
    manifest = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "ferrum_git_pin": pin or None,
        "what_this_run_is": (
            "Local GA4GH *pipeline smoke*: DRS ingest + WES→TES (Cromwell or Nextflow) "
            "+ nested GATK HaplotypeCaller + hap.py on a tiny slice. "
            "Optional DRS /stream micro-timing and Crypt4GH-at-rest ingest."
        ),
        "what_this_run_is_not": [
            "A GIAB / Platinum publication-grade variant-calling benchmark",
            "Clinical or regulatory validation",
            "Proof that the Dockstore GATK germline WDL was executed (TRS fetch is descriptor-only)",
            "GA4GH conformance (that is HelixTest)",
            "A two-node Raspberry Pi / rural-WiFi field deployment",
            "Africa/field feature proof unless africa.verdict is passed and scenarios ran",
        ],
        "dataset": {
            "kind": "synthetic_giab_style" if synthetic else "public_giab_platinum_slice",
            "interval": prof.get("interval") or "see results/interval.txt",
            "bam_bytes": bam.get("bytes"),
            "bam_human": bam.get("human"),
            "synthetic_manifest": (root / "data" / "synthetic_manifest.txt").is_file(),
        },
        "caller": {
            "uses_truth_alleles": bench.get("caller_uses_truth_alleles"),
            "workflow": metrics.get("wes_workflow_url"),
            "engine": metrics.get("wes_engine"),
            "wes_run_id": metrics.get("wes_run_id"),
        },
        "hap_py": {
            "precision": bench.get("precision"),
            "recall": bench.get("recall"),
            "f1_score": bench.get("f1_score"),
            "claim_scope": bench.get("claim_scope") or "pipeline_smoke",
            "caller_uses_truth_alleles": bench.get("caller_uses_truth_alleles"),
            "cite": hap_blind,
            "note": (
                "hap.py vs local truth on this slice only. "
                "cite=true only when this run recorded caller_uses_truth_alleles=false. "
                "Still not a GIAB publication result."
            ),
        },
        "trs": {
            **trs,
            "descriptor_fetched": bool(trs),
            "descriptor_executed_as_wes": False,
            "executed": False,
        },
        "africa": {
            "verdict": africa_sum.get("verdict", "not_evaluated"),
            "all_passed": africa_sum.get("all_passed", False),
            "ran": africa_sum.get("ran", 0),
            "skipped": africa_sum.get("skipped", 0),
            "errors": africa_sum.get("errors", 0),
        },
        "co_deploy": {
            "verdict": co_sum.get("verdict", "not_evaluated"),
            "all_passed": co_sum.get("all_passed", False),
            "ran": co_sum.get("ran", 0),
            "skipped": co_sum.get("skipped", 0),
            "errors": co_sum.get("errors", 0),
        },
        "overlay": {
            "applied": False,
            "paths": [],
            "note": (
                "Pin is Ferrum v0.3.1. TES poll and residency hash live upstream. "
                "No vendor/ferrum-overlay rsync."
            ),
        },
        "security_demo_only": [
            "Gateway mounts docker.sock for nested Cromwell/GATK (laptop TES, not a production posture).",
            "Crypt4GH node.sec is a committed non-production fixture.",
            "Static HTTP serves workflows/ only, for TES to fetch the WDL/NF.",
        ],
    }
    path = out_dir / "RUN_MANIFEST.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": True, "wrote": str(path)}))


if __name__ == "__main__":
    main()
