#!/usr/bin/env python3
"""Multipart ingest via curl (avoids hand-rolled multipart); build Cromwell inputs JSON."""
from __future__ import annotations

import json
import subprocess
import sys
import urllib.request
from pathlib import Path


def post_multipart_curl(gateway: str, path: Path, name: str) -> str:
    url = f"{gateway.rstrip('/')}/ga4gh/drs/v1/ingest/file"
    out = subprocess.check_output(
        [
            "curl",
            "-fsS",
            "-F",
            f"file=@{path}",
            "-F",
            f"name={name}",
            url,
        ],
        text=True,
    )
    return json.loads(out)["id"]


def drs_stream_http_url(_gateway: str, object_id: str) -> str:
    """Plain GET returns bytes (not /access JSON). WDL symlinks localized files to *.fa / *.bam."""
    return f"http://ferrum-gateway:8080/ga4gh/drs/v1/objects/{object_id}/stream"


def main() -> None:
    if len(sys.argv) < 5:
        print(
            "usage: ingest_and_inputs.py <gateway_base> <data_dir> <mapping_out> <inputs_out> [interval]",
            file=sys.stderr,
        )
        sys.exit(2)
    gateway = sys.argv[1]
    data = Path(sys.argv[2])
    mapping_out = Path(sys.argv[3])
    inputs_out = Path(sys.argv[4])
    interval = sys.argv[5] if len(sys.argv) > 5 else "22:16050000-16080000"

    files = {
        "input_bam": data / "na12878_slice.bam",
        "input_bam_index": data / "na12878_slice.bam.bai",
        "ref_fasta": data / "ref_slice.fa",
        "ref_fasta_index": data / "ref_slice.fa.fai",
        "truth_vcf": data / "truth_slice.vcf.gz",
        "truth_vcf_index": data / "truth_slice.vcf.gz.tbi",
    }
    for k, p in files.items():
        if not p.is_file():
            raise SystemExit(f"missing {k}: {p}")

    ids: dict[str, str] = {}
    for logical, path in files.items():
        oid = post_multipart_curl(gateway, path, path.name)
        ids[logical] = oid

    mapping = {
        "note": "DRS URIs use the gateway hostname Cromwell containers resolve on the compose network.",
        "objects": {
            k: {
                "drs_uri": f"drs://ferrum-gateway:8080/{v}",
                "object_id": v,
            }
            for k, v in ids.items()
        },
    }
    mapping_out.parent.mkdir(parents=True, exist_ok=True)
    mapping_out.write_text(json.dumps(mapping, indent=2))

    inputs = {
        "TinyGermlineHC.input_bam": drs_stream_http_url(gateway, ids["input_bam"]),
        "TinyGermlineHC.input_bam_index": drs_stream_http_url(
            gateway, ids["input_bam_index"]
        ),
        "TinyGermlineHC.ref_fasta": drs_stream_http_url(gateway, ids["ref_fasta"]),
        "TinyGermlineHC.ref_fasta_index": drs_stream_http_url(
            gateway, ids["ref_fasta_index"]
        ),
        "TinyGermlineHC.truth_vcf": drs_stream_http_url(gateway, ids["truth_vcf"]),
        "TinyGermlineHC.truth_vcf_index": drs_stream_http_url(
            gateway, ids["truth_vcf_index"]
        ),
        "TinyGermlineHC.interval": interval,
    }
    inputs_out.write_text(json.dumps(inputs, indent=2))
    print(json.dumps({"ok": True, "object_ids": ids}))


if __name__ == "__main__":
    main()
