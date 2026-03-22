#!/usr/bin/env python3
"""Measure on-disk sizes of ingest inputs; write results/dataset_profile.json for docs."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def human(n: int) -> str:
    if n < 1024:
        return f"{n} B"
    x = float(n) / 1024.0
    for unit in ("KiB", "MiB", "GiB"):
        if x < 1024 or unit == "GiB":
            return f"{x:.2f} {unit}"
        x /= 1024.0
    return f"{n} B"


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: dataset_profile.py <repo_root>", file=sys.stderr)
        sys.exit(2)
    root = Path(sys.argv[1]).resolve()
    data = root / "data"
    interval = (root / "results" / "interval.txt").read_text().strip() if (root / "results" / "interval.txt").is_file() else "n/a"
    keys = {
        "input_bam": data / "na12878_slice.bam",
        "input_bam_index": data / "na12878_slice.bam.bai",
        "ref_fasta": data / "ref_slice.fa",
        "ref_fasta_index": data / "ref_slice.fa.fai",
        "truth_vcf": data / "truth_slice.vcf.gz",
        "truth_vcf_index": data / "truth_slice.vcf.gz.tbi",
    }
    files: dict[str, dict[str, object]] = {}
    total = 0
    for name, path in keys.items():
        if path.is_file():
            sz = path.stat().st_size
            total += sz
            files[name] = {
                "path": str(path.relative_to(root)),
                "bytes": sz,
                "human": human(sz),
            }
        else:
            files[name] = {"path": str(path.relative_to(root)), "bytes": 0, "human": "missing"}
    synthetic = (data / "synthetic_manifest.txt").is_file()
    out = {
        "interval": interval,
        "synthetic_subset": synthetic,
        "files": files,
        "ingest_total_bytes": total,
        "ingest_total_human": human(total) if total else "0 B",
        "note": "Sizes are local files before DRS ingest; BAM is the slice used by HaplotypeCaller.",
    }
    out_path = root / "results" / "dataset_profile.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(out, indent=2), encoding="utf-8")
    print(json.dumps({"ok": True, "wrote": str(out_path)}))


if __name__ == "__main__":
    main()
