#!/usr/bin/env python3
"""Synthetic Africa field-lab scenarios (ONT ingestion, pathogen metadata)."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ORGANISM_SEQUENCES = {
    "Plasmodium_falciparum": (
        ">Pf3D7_01_v3 synthetic demo slice\n"
        "ATGCATGCATGCATGCATGCATGCATGCATGCATGCATGCATGC\n"
    ),
    "Mycobacterium_tuberculosis": (
        ">Mtb_H37Rv synthetic demo slice\n"
        "GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA\n"
    ),
}


def synthetic_fasta(organism: str) -> Path:
    seq = ORGANISM_SEQUENCES.get(
        organism,
        f">{organism} synthetic demo\n" + "ACGT" * 12 + "\n",
    )
    tmp = tempfile.NamedTemporaryFile(
        mode="w", suffix=f"_{organism}.fa", delete=False, encoding="utf-8"
    )
    tmp.write(seq)
    tmp.close()
    return Path(tmp.name)


def ingest_file(gateway: str, path: Path, name: str) -> str:
    url = f"{gateway.rstrip('/')}/ga4gh/drs/v1/ingest/file"
    cmd = [
        "curl",
        "-fsS",
        "-F",
        f"file=@{path}",
        "-F",
        f"name={name}",
        "-F",
        f"description=Africa demo synthetic {name}",
        url,
    ]
    out = subprocess.check_output(cmd, text=True)
    return json.loads(out)["id"]


def register_url(gateway: str, organism: str) -> None:
    """Fallback when multipart ingest is unavailable."""
    url = f"{gateway.rstrip('/')}/api/v1/ingest/register"
    body = {
        "client_request_id": f"africa-demo-{organism}",
        "items": [
            {
                "type": "url",
                "url": f"https://example.invalid/africa-demo/{organism}.fa",
                "name": f"{organism}_synthetic",
            }
        ],
    }
    cmd = [
        "curl",
        "-fsS",
        "-X",
        "POST",
        "-H",
        "Content-Type: application/json",
        "-d",
        json.dumps(body),
        url,
    ]
    subprocess.run(cmd, check=False, capture_output=True, text=True)


def scenario_ont_ingestion(gateway: str, organism: str) -> None:
    fasta = synthetic_fasta(organism)
    try:
        oid = ingest_file(gateway, fasta, f"{organism}_ont_demo.fa")
        print(f"[africa] ingested {organism} → DRS object {oid}")
    except subprocess.CalledProcessError:
        print(
            f"[africa] DRS ingest unavailable for {organism}; trying register API...",
            file=sys.stderr,
        )
        register_url(gateway, organism)
        print(f"[africa] register request sent for {organism} (may require upstream ingest)")
    finally:
        fasta.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gateway", required=True)
    parser.add_argument(
        "--scenario",
        required=True,
        choices=("ont_ingestion",),
    )
    parser.add_argument(
        "--organism",
        default="Plasmodium_falciparum",
        help="Pathogen / organism label for synthetic data",
    )
    args = parser.parse_args()

    if args.scenario == "ont_ingestion":
        scenario_ont_ingestion(args.gateway, args.organism)
    else:
        raise SystemExit(f"unknown scenario: {args.scenario}")


if __name__ == "__main__":
    main()
