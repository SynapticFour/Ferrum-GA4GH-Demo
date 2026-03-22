# Ferrum GA4GH demonstration & benchmark

End-to-end, **single-command** artefact that exercises **[Ferrum](https://github.com/SynapticFour/Ferrum)** GA4GH APIs (**TRS**, **DRS**, **WES**, **TES**) on a small **GIAB / Platinum** subset, then scores the output VCF with **hap.py** against GIAB truth.

## Prerequisites

- Docker (Desktop or Engine) with sufficient RAM (~8 GB recommended for Cromwell + GATK)
- `git`, `python3`, `curl`, `bash`
- Network access (first run clones Ferrum, pulls images, downloads public genomics files)

## Run

```bash
./run
# or: bash demo/run.sh
```

`./run --help` lists CLI flags. **Phase 3 — Nextflow parity:** `./run --nextflow` runs the same GATK slice as WDL via **`workflows/tiny_hc.nf`**, WES type `NEXTFLOW`, TES task **`nextflow run workflow.nf`** with **`docker { enabled = true }`** in a run-local `nextflow.config` (see [docs/architecture.md](docs/architecture.md)). Combine with macro: **`./run --nextflow --macro`**. **Phase 2 macro (plain vs at-rest Crypt4GH ingest):** `./run --macro` (WDL) or with Nextflow as above. **DRS client-key micro-timing:** `./run --crypt4gh` with `FERRUM_GA4GH_CRYPT4GH_PUBKEY` set. Resource planning: [docs/RESOURCE-ESTIMATES.md](docs/RESOURCE-ESTIMATES.md).

| Environment | Meaning |
|-------------|---------|
| `FERRUM_GA4GH_ENGINE` | `wdl` (default) or `nextflow` — which workflow engine WES submits via TES. |
| `FERRUM_GA4GH_MACRO_COMPARE` | `1` — Phase 2 A/B: plain ingest then Crypt4GH-at-rest ingest (`./run --macro`). |
| `FERRUM_GA4GH_ENCRYPT_INGEST` | `1` — single run with `encrypt=true` multipart ingest (requires node keys in gateway). |
| `FERRUM_GA4GH_CRYPT4GH_PUBKEY` | Optional client public key file for DRS micro-benchmark `X-Crypt4GH-Public-Key` timing. |
| `FERRUM_GA4GH_RESET_VOLUMES` | `1` (default) wipes compose volumes each run; `0` keeps DB/MinIO between runs. **`./run --no-reset` sets this** — only use if you know the DB migration state is consistent; otherwise `ferrum-init` may fail when migrations are re-applied against an existing schema. Prefer a full run without `--no-reset` when in doubt. |
| `FERRUM_TES_DOCKER_PLATFORM` | e.g. `linux/amd64` — on **arm64** hosts the demo defaults this so TES can run **amd64-only** images (Nextflow executor). |

Outputs land under `results/` (`query.vcf.gz`, `benchmark.json`, `metrics.json`, `drs_micro.json`, optional `phase2_pass_*.json` / `benchmark.phase2_*.json` with `--macro`, hap.py artefacts). Documentation is refreshed automatically.

## Documentation

| Doc | Content |
|-----|---------|
| [docs/PHASES.md](docs/PHASES.md) | Phases 1–4 (DRS micro, macro Crypt4GH, Nextflow, docs/CLI) |
| [docs/architecture.md](docs/architecture.md) | Stack diagram, data plane, overlay, Phase 2 macro |
| [docs/benchmark.md](docs/benchmark.md) | Last-run hap.py + GA4GH checklist (auto-updated) |
| [docs/RESOURCE-ESTIMATES.md](docs/RESOURCE-ESTIMATES.md) | RAM, disk, transfer planning |

## Layout

| Path | Role |
|------|------|
| `demo/run.sh` | Orchestrates clone/patch Ferrum, compose, TRS cache, DRS ingest, WES, benchmark, docs |
| `demo/config.yaml` | Pinned coordinates / URLs (keep in sync with `scripts/fetch_giab_subset.sh`) |
| `demo/docker-compose.ga4gh.yml` | Compose overlay: TES + WES workdir + `docker.sock` + Crypt4GH node keys mount |
| `demo/fixtures/crypt4gh-node/` | Non-production **node.sec** / **node.pub** for `encrypt=true` ingest |
| `demo/lib/compose_metrics.py` | Builds `metrics.json` from pass snapshots (single or Phase 2 macro) |
| `demo/lib/record_pass_snapshot.py` | Writes `results/phase2_pass_<label>.json` per pipeline pass |
| `demo/lib/ingest_and_inputs.py` | DRS multipart ingest + WDL `inputs.json` + Nextflow `nf_params.json` |
| `demo/lib/build_wes_payload.py` | WES run JSON for WDL or Nextflow |
| `drs/mapping.json` | Generated DRS object map |
| `workflows/tiny_hc.wdl` | Minimal **HaplotypeCaller** WDL (Cromwell via TES) |
| `workflows/tiny_hc.nf` | Same logic as DSL2 **Nextflow** (Docker-backed processes via TES) |
| `scripts/drs_micro_benchmark.py` | Wall-time for DRS `/stream` (plain vs optional Crypt4GH header) |
| `workflows/cached/` | Dockstore TRS primary descriptor (GATK germline bundle) |
| `scripts/` | Data + TRS fetch, doc updater |
| `benchmark/` | hap.py (micromamba) image + runner |
| `docs/` | [PHASES](docs/PHASES.md), architecture, auto-updated benchmark, resource estimates |

## Results snapshot

<!-- GA4GH_BENCHMARK_TABLE_START -->
| Metric | Value |
|--------|-------|
| Precision | 1.0 |
| Recall | 1.0 |
| F1 | 1.0 |
| Runtime (demo) | 26 s |
| WES engine | nextflow |
| DRS stream (median s) | 0.0036585830384865403 |
| WES run | `01KMAGZS5BTEKQHQ0JTHGQA9XF` |

<!-- GA4GH_BENCHMARK_TABLE_END -->

## Implementation note

Upstream Ferrum defaults to a **noop** TES backend for CI. This repository applies a **small overlay** under `vendor/ferrum-overlay/` (`FERRUM_TES_BACKEND`, **WDL** and **Nextflow** bind-mount paths for WES→TES, Docker volume binds / network for nested engines) so the gateway can run **GATK HaplotypeCaller** while staying GA4GH-compatible. **DRS `access_url` handling** lives in upstream Ferrum (overlay no longer patches `ferrum-drs`); `demo/run.sh` resets `repo.rs` after rsync if an old clone still had a local overlay copy.

## Licence

**This repository** is licensed under the [Apache License 2.0](LICENSE). That applies to scripts, docs, and demo code here — **not** to [Ferrum](https://github.com/SynapticFour/Ferrum) itself, which remains under **BUSL-1.1**. Benchmark workflow descriptors (e.g. GATK / Dockstore) follow their respective upstream licenses.

---

Built for the **open science** community and for **reproducible GA4GH** benchmarking on top of [Ferrum](https://github.com/SynapticFour/Ferrum). This demo repository is maintained with the same care for clarity and traceability as the upstream project. **Proudly developed by individuals on the autism spectrum in Germany** — we value precision, honest measurement, and documentation you can rely on. © Synaptic Four · Demo code under [Apache-2.0](LICENSE); Ferrum under its own license (see upstream).
