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
| `--macro` | Two passes: plain ingest + Crypt4GH-at-rest (`--nextflow --macro` supported) |
| `--crypt4gh` | DRS micro-bench with `FERRUM_GA4GH_CRYPT4GH_PUBKEY` (required) |
| `--no-reset` | Keep compose volumes — see [architecture → Demo scope](docs/architecture.md#demo-scope-phases) |
| `--help` | Full usage |

**Environment:** `FERRUM_GA4GH_ENGINE` (`wdl` \| `nextflow`), `FERRUM_GA4GH_MACRO_COMPARE`, `FERRUM_GA4GH_ENCRYPT_INGEST`, `FERRUM_GA4GH_CRYPT4GH_PUBKEY`, `FERRUM_GA4GH_RESET_VOLUMES`, `FERRUM_TES_DOCKER_PLATFORM` (arm64 defaults to `linux/amd64` for Nextflow). See `./run --help`.

**Outputs:** `results/` — `query.vcf.gz`, `benchmark.json`, `metrics.json`, `drs_micro.json`, optional `phase2_*` / `benchmark.phase2_*`. **Docs:** `scripts/update_docs.py` refreshes the table below and [docs/benchmark.md](docs/benchmark.md).

## Docs layout

| File | Role |
|------|------|
| [docs/architecture.md](docs/architecture.md) | Diagram, data plane, overlay, resources, upstream lessons |
| [docs/benchmark.md](docs/benchmark.md) | Last run + GA4GH checklist (auto) |

## Repository layout

| Path | Role |
|------|------|
| `./run`, `demo/run.sh` | Entrypoints |
| `demo/docker-compose.ga4gh.yml` | TES, WES workdir, `docker.sock`, Crypt4GH keys |
| `demo/lib/*.py` | Ingest, WES JSON, metrics, snapshots |
| `vendor/ferrum-overlay/` | Patched Ferrum crates + gateway Dockerfile (see architecture) |
| `workflows/tiny_hc.{wdl,nf}` | Minimal HaplotypeCaller |
| `scripts/` | Fetch, TRS cache, DRS micro-bench, doc update |

## Results snapshot

<!-- GA4GH_BENCHMARK_TABLE_START -->
| Metric | Value |
|--------|-------|
| Precision | 1.0 |
| Recall | 1.0 |
| F1 | 1.0 |
| Runtime (demo) | 56 s |
| WES engine | wdl |
| DRS stream (median s) | 0.0033063750015571713 |
| WES run | `01KMAHEC37KDR3NDHSVBV4DEPE` |

<!-- GA4GH_BENCHMARK_TABLE_END -->

## Licence

This **repository** is [Apache-2.0](LICENSE). [Ferrum](https://github.com/SynapticFour/Ferrum) upstream remains **BUSL-1.1**. GATK / Dockstore descriptors follow their upstream licences.

---

Open science, reproducible GA4GH benchmarking. **Proudly developed by individuals on the autism spectrum in Germany** — precision, honest measurement, documentation you can rely on. © Synaptic Four · [Apache-2.0](LICENSE).
