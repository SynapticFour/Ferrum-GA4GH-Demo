# Ferrum GA4GH demonstration & benchmark

End-to-end, **single-command** artefact that exercises **[Ferrum](https://github.com/SynapticFour/Ferrum)** GA4GH APIs (**TRS**, **DRS**, **WES**, **TES**) on a small **GIAB / Platinum** subset, then scores the output VCF with **hap.py** against GIAB truth.

## Prerequisites

- Docker (Desktop or Engine) with sufficient RAM (~8 GB recommended for Cromwell + GATK)
- `git`, `python3`, `curl`, `bash`
- Network access (first run clones Ferrum, pulls images, downloads public genomics files)

## Run

```bash
bash demo/run.sh
```

Outputs land under `results/` (`query.vcf.gz`, `benchmark.json`, `metrics.json`, hap.py artefacts). Documentation is refreshed automatically.

## Layout

| Path | Role |
|------|------|
| `demo/run.sh` | Orchestrates clone/patch Ferrum, compose, TRS cache, DRS ingest, WES, benchmark, docs |
| `demo/config.yaml` | Pinned coordinates / URLs (keep in sync with `scripts/fetch_giab_subset.sh`) |
| `demo/docker-compose.ga4gh.yml` | Compose overlay: Docker TES + WES workdir bind + docker.sock |
| `demo/lib/ingest_and_inputs.py` | DRS multipart ingest + Cromwell JSON inputs |
| `drs/mapping.json` | Generated DRS object map |
| `workflows/tiny_hc.wdl` | Minimal **HaplotypeCaller** WDL executed via WES→TES |
| `workflows/cached/` | Dockstore TRS primary descriptor (GATK germline bundle) |
| `scripts/` | Data + TRS fetch, doc updater |
| `benchmark/` | hap.py (micromamba) image + runner |
| `docs/` | Auto-updated benchmark + architecture notes |

## Results snapshot

<!-- GA4GH_BENCHMARK_TABLE_START -->
| Metric | Value |
|--------|-------|
| Precision | 1.0 |
| Recall | 1.0 |
| F1 | 1.0 |
| Runtime (demo) | 44 s |
| WES run | `01KM834NT87Q1CD3S31G6N8R87` |

<!-- GA4GH_BENCHMARK_TABLE_END -->

## Implementation note

Upstream Ferrum defaults to a **noop** TES backend for CI. This repository applies a **small, reproducible overlay** under `vendor/ferrum-overlay/` (configurable `FERRUM_TES_BACKEND`, WDL inputs for Cromwell, Docker volume binds) so the same gateway image can run a real **GATK HaplotypeCaller** task while remaining API-compatible with GA4GH WES/TES.

## Licence

Benchmark workflow descriptors follow their upstream licenses (GATK / Dockstore). Ferrum remains under its BUSL-1.1 license; consult each upstream component for redistribution terms.
