#!/usr/bin/env python3
"""Refresh docs/benchmark.md and the GA4GH summary table in README.md from JSON artefacts."""
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def _load_json(path: Path) -> dict | None:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def _publication_block(
    root: Path,
    metrics: dict,
    dm: dict,
    dataset_line: str,
) -> str:
    """Cromwell vs Nextflow table, dataset sizes, DRS n for reviewers."""
    lines: list[str] = ["\n## Publication-friendly summary\n\n"]

    # DRS micro: explicit n
    repeat_n = dm.get("repeat_n")
    if repeat_n is None:
        repeat_n = (dm.get("plain") or {}).get("samples")
        repeat_n = len(repeat_n) if isinstance(repeat_n, list) else "n/a"
    max_b = dm.get("max_bytes", "n/a")
    if isinstance(max_b, int) and max_b >= 1024 * 1024:
        max_b_disp = f"{max_b / (1024 * 1024):.1f} MiB (~{max_b:,} bytes)"
    elif isinstance(max_b, int):
        max_b_disp = f"{max_b:,} bytes"
    else:
        max_b_disp = str(max_b)
    has_at_rest = isinstance(dm.get("crypt4gh_at_rest"), dict) and not (
        dm.get("crypt4gh_at_rest") or {}
    ).get("skipped")
    drs_modes = (
        "plaintext storage vs **Crypt4GH-at-rest** (server decrypt on `/stream`, `--encrypted-object-id`)"
        if has_at_rest
        else "plaintext storage"
    )
    lines.append(
        f"**DRS `/stream` micro-benchmark:** median wall time uses **n = {repeat_n}** repeated "
        f"requests per mode ({drs_modes}; capped at **{max_b_disp}** per request unless `--max-bytes 0`). "
        f"See `scripts/drs_micro_benchmark.py` (`--repeat`, `--encrypted-object-id`).\n\n"
    )

    # Dataset sizes
    prof = _load_json(root / "results" / "dataset_profile.json")
    if prof and prof.get("ingest_total_bytes", 0) > 0:
        bam = (prof.get("files") or {}).get("input_bam") or {}
        lines.append("**Dataset (local files ingested to DRS):**\n\n")
        lines.append(
            f"| Item | Size |\n|------|------|\n"
            f"| **BAM slice** (`na12878_slice.bam`) | {bam.get('human', 'n/a')} ({bam.get('bytes', 0):,} bytes) |\n"
            f"| **All six ingest objects** (BAM+BAI+ref+ref.fai+truth+tbi) | **{prof.get('ingest_total_human', 'n/a')}** ({prof.get('ingest_total_bytes', 0):,} bytes) |\n\n"
        )
        lines.append(
            f"**Genomic interval:** `{prof.get('interval', 'n/a')}`"
            + (" (synthetic subset)" if prof.get("synthetic_subset") else " (public subset)")
            + ".\n\n"
        )
    else:
        lines.append(
            "**Dataset:** run the demo once to generate `results/dataset_profile.json` "
            f"(or see table above: *{dataset_line}*).\n\n"
        )

    # Engine comparison
    ec = _load_json(root / "results" / "engine_compare.json") or {}
    cw = ec.get("cromwell_wdl") or {}
    nf = ec.get("nextflow") or {}
    lines.append(
        "**Cromwell vs Nextflow** (same `tiny_hc` logic, same DRS objects, same interval):\n\n"
    )
    lines.append(
        "| Engine | TES executor image | Pipeline wall time (s) | WES run id (example) |\n"
        "|--------|-------------------|------------------------|------------------------|\n"
    )
    lines.append(
        f"| **Cromwell** (WDL `tiny_hc.wdl`) | `broadinstitute/cromwell:…` | "
        f"{cw.get('pipeline_elapsed_seconds', '—')} | `{cw.get('wes_run_id', '—')}` |\n"
    )
    lines.append(
        f"| **Nextflow** (`tiny_hc.nf`) | `nextflow/nextflow:24.10.3` (+ GATK container) | "
        f"{nf.get('pipeline_elapsed_seconds', '—')} | `{nf.get('wes_run_id', '—')}` |\n\n"
    )
    if not nf.get("pipeline_elapsed_seconds"):
        lines.append(
            "*Fill the Nextflow row by running* `./run --nextflow` *once; the Cromwell row by a plain* `./run` "
            "*(each run updates* `results/engine_compare.json`*).*\n\n"
        )
    lines.append(
        "Times are **end-to-end per pass** (ingest, DRS micro-bench, WES, hap.py), not GATK-only.\n"
    )
    return "".join(lines)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--metrics", required=True)
    ap.add_argument("--benchmark", required=True)
    ap.add_argument("--readme", required=True)
    ap.add_argument("--bench-md", required=True)
    ap.add_argument(
        "--repo-root",
        default=None,
        help="Repository root (for synthetic vs real dataset label); defaults to parent of scripts/",
    )
    args = ap.parse_args()

    metrics = json.loads(Path(args.metrics).read_text())
    bench = json.loads(Path(args.benchmark).read_text())
    root = Path(args.repo_root or Path(__file__).resolve().parents[1])
    interval_txt = root / "results" / "interval.txt"
    interval = (
        interval_txt.read_text().strip()
        if interval_txt.is_file()
        else "chr22 (see results/interval.txt)"
    )
    if (root / "data" / "synthetic_manifest.txt").is_file():
        dataset = f"Synthetic GIAB-style subset ({interval})"
    else:
        dataset = (
            "NA12878 Platinum slice + GIAB HG001 truth (GRCh37), "
            f"{interval}"
        )

    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    summary_src = bench.get("summary_source") or bench.get("summary_json", "n/a")
    try:
        sp = Path(str(summary_src))
        if sp.is_absolute():
            summary_src = str(sp.relative_to(root.resolve()))
    except (ValueError, OSError):
        pass

    dm = metrics.get("drs_micro") or {}
    plain_w = (dm.get("plain") or {}).get("wall_seconds") or {}
    plain_med = plain_w.get("median") if isinstance(plain_w, dict) else None
    drs_n = dm.get("repeat_n", "n/a")
    at_rest = dm.get("crypt4gh_at_rest")
    at_rest_line = ""
    if isinstance(at_rest, dict) and not at_rest.get("skipped") and not at_rest.get("error"):
        aw = at_rest.get("wall_seconds") or {}
        if isinstance(aw, dict) and aw.get("median") is not None:
            at_rest_line = (
                f"| DRS /stream Crypt4GH **at-rest** median (s, ref_fasta, server decrypt) | "
                f"{aw.get('median')} |\n"
            )
    crypt = dm.get("crypt4gh")
    crypt_line = ""
    if isinstance(crypt, dict) and not crypt.get("skipped") and not crypt.get("error"):
        cw = crypt.get("wall_seconds") or {}
        if isinstance(cw, dict) and cw.get("median") is not None:
            crypt_line = (
                f"| DRS /stream client header (`X-Crypt4GH-Public-Key`) median (s) | "
                f"{cw.get('median')} |\n"
            )
    at_rest_med = None
    if isinstance(at_rest, dict) and not at_rest.get("skipped"):
        aw = at_rest.get("wall_seconds") or {}
        if isinstance(aw, dict):
            at_rest_med = aw.get("median")
    engine = metrics.get("wes_engine", "wdl")

    p2 = metrics.get("phase2_macro")
    phase2_md = ""
    if isinstance(p2, dict):
        pl = p2.get("plain") or {}
        cr = p2.get("crypt4gh_at_rest") or {}

        def _hp(d):
            h = d.get("hap_py") or {}
            return (
                h.get("precision"),
                h.get("recall"),
                h.get("f1_score"),
            )

        pp, pr, pf = _hp(pl)
        cp, cr_r, cf = _hp(cr)
        eng = (pl.get("wes_engine") or "wdl").strip().lower()
        if eng == "nextflow":
            eng_line = (
                "Same **Nextflow** workflow (`workflows/tiny_hc.nf`), same interval, same hap.py truth"
            )
        else:
            eng_line = (
                "Same **WDL** workflow (`workflows/tiny_hc.wdl`), same interval, same hap.py truth"
            )
        phase2_md = f"""
## Phase 2 macro (plain vs Crypt4GH at-rest ingest)

{eng_line} — two DRS ingests on one stack: **plaintext blobs** vs **`encrypt=true`** (node key in `demo/fixtures/crypt4gh-node/`). The engine still localizes via `GET .../stream`; the gateway decrypts at rest when `is_encrypted` (see Ferrum DRS stream handler). Pipeline wall time **includes** ingest, DRS micro-bench, WES, and hap.py.

| Profile | Time (s) | WES run | Precision | Recall | F1 |
|---------|----------|---------|-----------|--------|-----|
| Plain ingest | {pl.get("pipeline_elapsed_seconds", "n/a")} | `{pl.get("wes_run_id", "n/a")}` | {pp} | {pr} | {pf} |
| Crypt4GH at-rest | {cr.get("pipeline_elapsed_seconds", "n/a")} | `{cr.get("wes_run_id", "n/a")}` | {cp} | {cr_r} | {cf} |

Artefacts: `results/benchmark.phase2_plain.json`, `results/benchmark.phase2_crypt4gh.json`, `results/phase2_pass_*.json`.
"""

    bench_md = f"""# Benchmark (hap.py)

Auto-generated by `demo/run.sh` — **do not hand-edit** (regenerated on each pipeline run).

| Field | Value |
|-------|-------|
| Last run | {now} |
| Pipeline wall time (s) | {metrics.get("pipeline_elapsed_seconds", "n/a")} |
| WES engine | {engine} |
| WES run id | `{metrics.get("wes_run_id", "n/a")}` |
| DRS /stream plain median (s, ref_fasta) | {plain_med if plain_med is not None else "n/a"} |
| DRS micro repetitions (n) | {drs_n} |
{at_rest_line}{crypt_line}| Precision | {bench.get("precision")} |
| Recall | {bench.get("recall")} |
| F1 | {bench.get("f1_score")} |
| Input dataset | {dataset} |
| hap.py metrics | `{summary_src}` |

## GA4GH components exercised

1. **TRS** — Dockstore `ga4gh/trs/v2` descriptor cached under `workflows/cached/`.
2. **DRS** — Files ingested via `POST /ga4gh/drs/v1/ingest/file`; the workflow engine localizes `GET .../objects/{{id}}/stream` (Cromwell or Nextflow; raw bytes on the compose network).
3. **WES** — `POST /ga4gh/wes/v1/runs` (WDL or Nextflow + params).
4. **TES** — Ferrum routes WES to `POST /ga4gh/tes/v1/tasks` (Docker backend: Cromwell + nested GATK, or Nextflow with Docker enabled + nested GATK).
5. **DRS micro** — `scripts/drs_micro_benchmark.py` times `GET .../objects/{{id}}/stream` (**n = {drs_n}** runs per mode by default). Phase 2 (`./run --macro`) compares **plaintext vs Crypt4GH-at-rest** `ref_fasta` object ids; optional PEM/base64 `X-Crypt4GH-Public-Key` for client re-encrypt experiments. See `results/drs_micro.json`.
{_publication_block(root, metrics, dm, dataset)}
{phase2_md}
"""
    Path(args.bench_md).parent.mkdir(parents=True, exist_ok=True)
    Path(args.bench_md).write_text(bench_md)

    prof = _load_json(root / "results" / "dataset_profile.json")
    bam_h = "n/a"
    if prof:
        bam = (prof.get("files") or {}).get("input_bam") or {}
        bam_h = str(bam.get("human", "n/a"))

    readme = Path(args.readme).read_text()
    table = f"""| Metric | Value |
|--------|-------|
| Precision | {bench.get("precision")} |
| Recall | {bench.get("recall")} |
| F1 | {bench.get("f1_score")} |
| Runtime (demo) | {metrics.get("pipeline_elapsed_seconds", "n/a")} s |
| WES engine | {engine} |
| DRS stream plain (median s) | {plain_med if plain_med is not None else "n/a"} |
| DRS stream Crypt4GH at-rest (median s) | {at_rest_med if at_rest_med is not None else "n/a"} |
| DRS micro repetitions (n) | {drs_n} |
| BAM slice (on disk) | {bam_h} |
| WES run | `{metrics.get("wes_run_id", "n/a")}` |
"""
    start = "<!-- GA4GH_BENCHMARK_TABLE_START -->"
    end = "<!-- GA4GH_BENCHMARK_TABLE_END -->"
    if start in readme and end in readme:
        pre, rest = readme.split(start, 1)
        mid, post = rest.split(end, 1)
        readme = f"{pre}{start}\n{table}\n{end}{post}"
    else:
        readme += f"\n\n{start}\n{table}\n{end}\n"
    Path(args.readme).write_text(readme)


if __name__ == "__main__":
    main()
