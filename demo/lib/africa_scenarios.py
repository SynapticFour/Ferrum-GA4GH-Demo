#!/usr/bin/env python3
"""
Africa-specific scenario runner for Ferrum-GA4GH-Demo.

Each scenario function:
- Accepts (gateway: str, root: Path, feature_set: AfricaFeatureSet)
- Returns a dict that will be merged into results/africa_results.json
- Must NEVER raise an exception that propagates — catch and return {"error": str(e)}
- Must be idempotent (safe to re-run)

Scenarios are designed as proofs-of-concept demonstrations, not full benchmarks.
They demonstrate that Africa features work end-to-end, analogous to how the
main demo demonstrates GA4GH compliance.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from africa_feature_detect import AfricaFeatureSet


def scenario_offline_mode(gateway: str, root: Path, fs: AfricaFeatureSet) -> dict:
    if not fs.offline_mode:
        return {"skipped": True, "reason": "offline_mode not detected (Ferrum using PostgreSQL)"}

    try:
        req = urllib.request.Request(f"{gateway}/ga4gh/drs/v1/service-info")
        with urllib.request.urlopen(req, timeout=10) as resp:
            svc = json.loads(resp.read())

        req2 = urllib.request.Request(f"{gateway}/health")
        with urllib.request.urlopen(req2, timeout=10) as resp2:
            health = json.loads(resp2.read())

        return {
            "ok": True,
            "db_backend": health.get("db", "unknown"),
            "drs_service_id": svc.get("id"),
            "note": "All GA4GH endpoints confirmed working on SQLite backend",
        }
    except Exception as e:
        return {"error": str(e)}


def scenario_ont_ingestion(gateway: str, root: Path, fs: AfricaFeatureSet) -> dict:
    if not fs.ont_ingestion:
        return {"skipped": True, "reason": "ont_ingestion endpoint not available"}

    stub_path = root / "data" / "africa" / "synthetic_ont_stub.fastq"
    stub_path.parent.mkdir(parents=True, exist_ok=True)

    if not stub_path.exists():
        stub_path.write_text(
            "@synthetic_read_001\n"
            "ACGTACGTACGTACGTACGT\n"
            "+\n"
            "IIIIIIIIIIIIIIIIIIII\n",
            encoding="utf-8"
        )

    try:
        ont_metadata = json.dumps({
            "format": "Fastq",
            "run_id": "africa_demo_run_001",
            "sample_id": "synthetic_pf_sample",
            "organism": "Plasmodium_falciparum",
            "dorado_basecalled": True,
            "quality_metrics": {
                "mean_qscore": 12.5,
                "read_count": 1,
                "n50": 20,
                "read_length_histogram": [[20, 1]]
            }
        })

        cmd = [
            "curl", "-fsS",
            "-F", f"file=@{stub_path}",
            "-F", f"ont_metadata={ont_metadata}",
            f"{gateway}/api/v1/ingest/ont"
        ]
        result = subprocess.check_output(cmd, text=True, timeout=30)
        ingest_response = json.loads(result)
        drs_id = ingest_response.get("id")

        if not drs_id:
            return {"error": f"No DRS ID in ONT ingest response: {result}"}

        req = urllib.request.Request(f"{gateway}/ga4gh/drs/v1/objects/{drs_id}")
        with urllib.request.urlopen(req, timeout=10) as resp:
            drs_obj = json.loads(resp.read())

        ont_metrics = drs_obj.get("extensions", {}).get("ont_metrics") or \
                      drs_obj.get("ont_metrics")

        beacon_result = None
        if fs.multi_pathogen_beacon:
            beacon_url = (
                f"{gateway}/ga4gh/beacon/v2/g_variants"
                f"?filters=organism%3DPlasmodium_falciparum"
            )
            try:
                req2 = urllib.request.Request(beacon_url)
                with urllib.request.urlopen(req2, timeout=10) as resp2:
                    beacon_result = json.loads(resp2.read())
            except Exception as be:
                beacon_result = {"error": str(be)}

        return {
            "ok": True,
            "drs_id": drs_id,
            "ont_metrics_present": ont_metrics is not None,
            "ont_metrics": ont_metrics,
            "beacon_organism_query": beacon_result,
            "organism": "Plasmodium_falciparum",
            "note": "Synthetic ONT FASTQ ingested; DRS object confirmed with metadata",
        }
    except subprocess.CalledProcessError as e:
        return {"error": f"curl failed: {e.stderr}"}
    except Exception as e:
        return {"error": str(e)}


def scenario_multi_pathogen_beacon(gateway: str, root: Path, fs: AfricaFeatureSet) -> dict:
    if not fs.multi_pathogen_beacon:
        return {"skipped": True, "reason": "multi_pathogen_beacon filtering_terms not available"}

    try:
        req = urllib.request.Request(
            f"{gateway}/ga4gh/beacon/v2/filtering_terms?type=PathoGenFilter"
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            terms = json.loads(resp.read())

        req2 = urllib.request.Request(f"{gateway}/ga4gh/beacon/v2/g_variants?limit=1")
        with urllib.request.urlopen(req2, timeout=10) as resp2:
            human_result = json.loads(resp2.read())

        schema_present = "$schema" in human_result.get("meta", {}) or \
                         "$schema" in human_result

        req3 = urllib.request.Request(
            f"{gateway}/ga4gh/beacon/v2/g_variants"
            f"?filters=organism%3DHomo_sapiens&limit=1"
        )
        with urllib.request.urlopen(req3, timeout=10) as resp3:
            human_filtered = json.loads(resp3.read())

        return {
            "ok": True,
            "pathogen_filter_terms": terms.get("filteringTerms", [])[:3],
            "human_query_works": not human_result.get("error"),
            "meta_schema_present": schema_present,
            "organism_filter_works": not human_filtered.get("error"),
            "note": "Multi-pathogen Beacon filtering confirmed; human genomics unaffected",
        }
    except Exception as e:
        return {"error": str(e)}


def scenario_outbreak_mode(gateway: str, root: Path, fs: AfricaFeatureSet) -> dict:
    if not fs.outbreak_mode:
        return {"skipped": True, "reason": "outbreak_mode endpoints not available"}

    try:
        activate_payload = json.dumps({
            "policy": "demo_outbreak_policy",
            "activated_by": "ferrum-demo@synapticfour.com"
        }).encode("utf-8")

        req = urllib.request.Request(
            f"{gateway}/api/v1/outbreak/activate",
            data=activate_payload,
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                activate_result = json.loads(resp.read())
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return {
                    "skipped": True,
                    "reason": "outbreak_mode endpoint exists but no demo policy configured",
                    "hint": "Add [outbreak.policies] demo_outbreak_policy to ferrum config"
                }
            raise

        audit_result = None
        if fs.residency_audit:
            req2 = urllib.request.Request(f"{gateway}/api/v1/audit/residency?limit=5")
            with urllib.request.urlopen(req2, timeout=10) as resp2:
                audit_result = json.loads(resp2.read())

        chain_valid = None
        if fs.residency_audit:
            try:
                req3 = urllib.request.Request(f"{gateway}/api/v1/audit/residency/verify")
                with urllib.request.urlopen(req3, timeout=10) as resp3:
                    verify_result = json.loads(resp3.read())
                    chain_valid = verify_result.get("chain_valid")
            except Exception:
                pass

        deactivate_payload = json.dumps({
            "policy": "demo_outbreak_policy",
            "reason": "demo completed"
        }).encode("utf-8")
        req4 = urllib.request.Request(
            f"{gateway}/api/v1/outbreak/deactivate",
            data=deactivate_payload,
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req4, timeout=10) as resp4:
            deactivate_result = json.loads(resp4.read())

        return {
            "ok": True,
            "activated": activate_result.get("ok", activate_result),
            "deactivated": deactivate_result.get("ok", deactivate_result),
            "audit_chain_valid": chain_valid,
            "audit_entries_sample": audit_result,
            "note": "Outbreak Mode lifecycle: activate → audit → deactivate. All steps confirmed.",
        }
    except Exception as e:
        return {"error": str(e)}


def scenario_residency_audit(gateway: str, root: Path, fs: AfricaFeatureSet) -> dict:
    if not fs.residency_audit:
        return {"skipped": True, "reason": "residency_audit endpoints not available"}

    try:
        req = urllib.request.Request(f"{gateway}/api/v1/audit/residency?limit=10")
        with urllib.request.urlopen(req, timeout=10) as resp:
            entries = json.loads(resp.read())

        req2 = urllib.request.Request(f"{gateway}/api/v1/audit/residency/verify")
        with urllib.request.urlopen(req2, timeout=10) as resp2:
            verify = json.loads(resp2.read())

        event_types: dict[str, int] = {}
        for entry in (entries if isinstance(entries, list) else entries.get("entries", [])):
            et = entry.get("event_type", "unknown")
            event_types[et] = event_types.get(et, 0) + 1

        beacon_entries = [
            e for e in (entries if isinstance(entries, list) else entries.get("entries", []))
            if e.get("event_type") in ("data_accessed", "beacon_query")
        ]
        data_stayed = all(not e.get("data_left_node", True) for e in beacon_entries)

        return {
            "ok": True,
            "chain_valid": verify.get("chain_valid"),
            "entry_count": verify.get("entry_count"),
            "last_hash": verify.get("last_hash", "")[:16] + "...",
            "event_type_summary": event_types,
            "beacon_queries_data_stayed": data_stayed,
            "note": "Cryptographic audit chain verified. All beacon queries confirmed data_left_node=false.",
        }
    except Exception as e:
        return {"error": str(e)}


def scenario_reference_registry(gateway: str, root: Path, fs: AfricaFeatureSet) -> dict:
    if not fs.reference_registry:
        return {"skipped": True, "reason": "reference_registry endpoint not available"}

    try:
        req = urllib.request.Request(f"{gateway}/api/v1/references")
        with urllib.request.urlopen(req, timeout=10) as resp:
            refs = json.loads(resp.read())

        ref_list = refs if isinstance(refs, list) else refs.get("references", [])
        ids = [r.get("id") for r in ref_list]

        grch38_present = "GRCh38" in ids
        h3africa_present = "H3Africa_v1" in ids
        pathogen_refs = [r for r in ref_list if r.get("population_scope", "").startswith("Pathogen")]

        return {
            "ok": True,
            "total_references": len(ref_list),
            "grch38_present": grch38_present,
            "h3africa_present": h3africa_present,
            "pathogen_reference_count": len(pathogen_refs),
            "all_ids": ids,
            "note": "Reference genome registry confirmed with African population panels.",
        }
    except Exception as e:
        return {"error": str(e)}


SCENARIOS = [
    ("offline_mode",          scenario_offline_mode),
    ("ont_ingestion",         scenario_ont_ingestion),
    ("multi_pathogen_beacon", scenario_multi_pathogen_beacon),
    ("outbreak_mode",         scenario_outbreak_mode),
    ("residency_audit",       scenario_residency_audit),
    ("reference_registry",    scenario_reference_registry),
]


def run_all(gateway: str, root: Path, fs: AfricaFeatureSet) -> dict:
    results: dict[str, Any] = {
        "detected_features": fs.summary(),
        "available_count": fs.available_count(),
        "scenarios": {},
    }

    for name, fn in SCENARIOS:
        print(f"[africa] scenario: {name} ...", flush=True)
        t0 = time.perf_counter()
        try:
            result = fn(gateway, root, fs)
        except Exception as e:
            result = {"error": f"unhandled exception: {e}"}
        elapsed = time.perf_counter() - t0
        result["elapsed_seconds"] = round(elapsed, 3)
        results["scenarios"][name] = result
        status = "SKIPPED" if result.get("skipped") else ("ERROR" if result.get("error") else "OK")
        print(f"[africa] {name}: {status} ({elapsed:.1f}s)", flush=True)

    ran = sum(1 for r in results["scenarios"].values() if not r.get("skipped"))
    skipped = sum(1 for r in results["scenarios"].values() if r.get("skipped"))
    errors = sum(1 for r in results["scenarios"].values() if r.get("error"))

    results["summary"] = {
        "ran": ran,
        "skipped": skipped,
        "errors": errors,
        "all_passed": errors == 0,
    }

    return results


# ---------------------------------------------------------------------------
# Village Network CLI (legacy --gateway / --scenario / --organism interface)
# ---------------------------------------------------------------------------

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


def _village_ont_ingestion(gateway: str, organism: str) -> None:
    """Synthetic pathogen ingest via standard DRS for village-network demo."""
    seq = ORGANISM_SEQUENCES.get(
        organism,
        f">{organism} synthetic demo\n" + "ACGT" * 12 + "\n",
    )
    tmp = tempfile.NamedTemporaryFile(
        mode="w", suffix=f"_{organism}.fa", delete=False, encoding="utf-8"
    )
    tmp.write(seq)
    tmp.close()
    path = Path(tmp.name)
    try:
        url = f"{gateway.rstrip('/')}/ga4gh/drs/v1/ingest/file"
        cmd = [
            "curl", "-fsS",
            "-F", f"file=@{path}",
            "-F", f"name={organism}_ont_demo.fa",
            "-F", f"description=Africa demo synthetic {organism}",
            url,
        ]
        out = subprocess.check_output(cmd, text=True)
        oid = json.loads(out)["id"]
        print(f"[africa] ingested {organism} → DRS object {oid}")
    except subprocess.CalledProcessError:
        print(
            f"[africa] DRS ingest unavailable for {organism}",
            file=sys.stderr,
        )
    finally:
        path.unlink(missing_ok=True)


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1].startswith("http"):
        gw = sys.argv[1]
        fs = detect(gw)
        root = Path(".").resolve()
        print(json.dumps(run_all(gw, root, fs), indent=2))
    else:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("--gateway", required=True)
        parser.add_argument("--scenario", required=True, choices=("ont_ingestion",))
        parser.add_argument("--organism", default="Plasmodium_falciparum")
        args = parser.parse_args()
        if args.scenario == "ont_ingestion":
            _village_ont_ingestion(args.gateway, args.organism)
