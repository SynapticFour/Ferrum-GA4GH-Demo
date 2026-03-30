# Ferrum GA4GH demonstration & benchmark

Single command to run **[Ferrum](https://github.com/SynapticFour/Ferrum)** **TRS · DRS · WES · TES** on a small **GIAB / Platinum** subset, then **hap.py** vs truth.

## Prerequisites

Docker (~**8 GB** RAM), `git`, `python3`, `curl`, `bash`, network (clone Ferrum, images, public data). **Sizing & phases:** [docs/architecture.md](docs/architecture.md).

## Run

```bash
./run
```

| Flag | Effect |
|------|--------|
| *(default)* | WDL / Cromwell path |
| `--nextflow` | Same GATK slice via `workflows/tiny_hc.nf` |
| `--macro` | Two passes: plain + Crypt4GH-at-rest ingest; **merges** `results/drs_micro.json` with `plain` + `crypt4gh_at_rest` (+ optional `crypt4gh` if pubkey env set) |
| `--crypt4gh` | Requires `FERRUM_GA4GH_CRYPT4GH_PUBKEY`: adds optional **client-header** timing to `drs_micro.json` (see [benchmark.md](docs/benchmark.md)) |
| `--no-reset` | Keep compose volumes — see [architecture → Demo scope](docs/architecture.md#demo-scope-phases) |
| `--help` | Full usage |

**Environment:** `FERRUM_GA4GH_ENGINE` (`wdl` \| `nextflow`), `FERRUM_GA4GH_MACRO_COMPARE`, `FERRUM_GA4GH_ENCRYPT_INGEST`, `FERRUM_GA4GH_CRYPT4GH_PUBKEY`, `FERRUM_GA4GH_RESET_VOLUMES`, `FERRUM_TES_DOCKER_PLATFORM` (arm64 defaults to `linux/amd64` for Nextflow). See `./run --help`.

**Outputs:** `results/` — `query.vcf.gz`, `benchmark.json`, `metrics.json`, **`drs_micro.json`** (see below), optional `phase2_*`, `benchmark.phase2_*`, **`drs_mapping_phase_plain.json`** after `--macro`. **Docs:** `scripts/update_docs.py` refreshes the table below and [docs/benchmark.md](docs/benchmark.md).

### DRS `/stream` micro-benchmark (`drs_micro.json`)

| Key | When |
|-----|------|
| **`plain`** | Always (per pass): median wall time for streaming **plaintext** `ref_fasta`. |
| **`crypt4gh_at_rest`** | After **`./run --macro`**: second `ref_fasta` object (encrypted in MinIO); measures **server-side decrypt** on `GET .../stream`. |
| **`crypt4gh`** | If **`FERRUM_GA4GH_CRYPT4GH_PUBKEY`** is set (e.g. `demo/fixtures/crypt4gh-node/node.pub`): optional header timing; PEM is sent as **single-line base64**. |

Details, median table, and object-id notes: [docs/benchmark.md → Publication-friendly summary](docs/benchmark.md#publication-friendly-summary).

## Docs layout

| File | Role |
|------|------|
| [docs/architecture.md](docs/architecture.md) | Diagram, data plane, overlay, resources |
| [docs/benchmark.md](docs/benchmark.md) | Last run, GA4GH checklist, **DRS micro** keys + medians, **publication-friendly** block (engines, **n**, dataset sizes) |

## Repository layout

| Path | Role |
|------|------|
| `./run`, `demo/run.sh` | Entrypoints |
| `demo/docker-compose.ga4gh.yml` | TES, WES workdir, `docker.sock`, Crypt4GH keys |
| `demo/lib/*.py` | Ingest, WES JSON, metrics, snapshots, `update_engine_compare.py` |
| `vendor/ferrum-overlay/` | Minimal Ferrum patches: gateway TES env + small `ferrum-wes` TES submit tweaks (see architecture) |
| `workflows/tiny_hc.{wdl,nf}` | Minimal HaplotypeCaller |
| `scripts/` | Fetch, TRS cache, DRS micro-bench, `dataset_profile.py`, `update_docs.py` |

## Results snapshot

<!-- GA4GH_BENCHMARK_TABLE_START -->
| Metric | Value |
|--------|-------|
| Precision | 1.0 |
| Recall | 1.0 |
| F1 | 1.0 |
| Runtime (demo) | 54 s |
| WES engine | wdl |
| DRS stream plain `ref_fasta` (median s) | 0.008823291049338877 |
| DRS stream Crypt4GH **at-rest** (median s, server decrypt) | 0.0022616249043494463 |
| DRS stream client header `X-Crypt4GH-Public-Key` (median s) | 0.0018515419214963913 |
| DRS micro repetitions (n) | 3 |
| BAM slice (on disk) | 1.89 KiB |
| WES run | `01KMAZBCMWCR9V3XZGW6R5PY45` |

<!-- GA4GH_BENCHMARK_TABLE_END -->

**Publications / reviewers:** DRS micro **plain vs at-rest** (and optional header) medians, explicit **n**, BAM slice size, **Cromwell vs Nextflow** table → [docs/benchmark.md](docs/benchmark.md#publication-friendly-summary) (refreshed each `./run`; run **`./run --macro`** for the merged at-rest leg).

## Licence

This **repository** is [Apache-2.0](LICENSE). [Ferrum](https://github.com/SynapticFour/Ferrum) upstream remains **BUSL-1.1**. GATK / Dockstore descriptors follow their upstream licences.

---

Open science, reproducible GA4GH benchmarking. **Proudly developed by individuals on the autism spectrum in Germany.** Precision, honest measurement, documentation you can rely on. © Synaptic Four · [Apache-2.0](LICENSE).

This repository documents technical benchmark procedures and results. It does not constitute legal advice, regulatory certification, or a formal compliance determination for any jurisdiction.
