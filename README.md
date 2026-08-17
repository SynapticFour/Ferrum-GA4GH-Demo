# Ferrum GA4GH demonstration & pipeline smoke

**Proof / outreach — not a product, not a pilot, not an evaluation kit.** Local laptop smoke of [Ferrum](https://github.com/SynapticFour/Ferrum). Persona: [docs/PERSONA.md](docs/PERSONA.md).

**Stock Ferrum v0.3.1 is the `./run` pin.** No `vendor/ferrum-overlay`. TES poll and residency timestamps live upstream. A green `./run` is proof of **tagged** Ferrum, not a patched checkout.

Single command to run **Ferrum** **DRS · WES · TES** (plus a **TRS descriptor fetch**) on a **tiny** slice, then **hap.py vs local truth**.

**What a successful `./run` proves:** the laptop stack can ingest files via DRS, submit a WES run that TES executes (Cromwell or Nextflow + GATK), and produce a hap.py JSON for **that slice**.

**What it does not prove:** GIAB/Platinum genome-wide concordance, clinical validity, GA4GH conformance (that is [HelixTest](https://github.com/SynapticFour/HelixTest)), Africa/field features, or that the Dockstore GATK germline WDL ran (it is fetched, not executed).

After every run, read **`results/RUN_MANIFEST.json`** first. Persona sheet (what ran vs not): [docs/PERSONA.md](docs/PERSONA.md). Claim map: [docs/CLAIMS.md](docs/CLAIMS.md). Artefact list: [docs/OUTPUTS.md](docs/OUTPUTS.md).

Scope boundary: this demo stays **GA4GH pipeline-smoke-centric** (TRS fetch / DRS / WES / TES). MII/KDS validation belongs to upstream Ferrum MII Connect and optional Ferrum-Lab-Kit wrapper workflows.

> **Legal notice:** This repository documents technical capabilities and operating guidance. It is not legal advice and does not by itself provide regulatory certification or compliance guarantees. Compliance outcomes depend on operator configuration, contracts, and organisational controls. hap.py Precision/Recall/F1 here are **slice-level pipeline smoke**, not a publication GIAB result.

## SynapticFour GA4GH stack

This demo is **proof / outreach**, not one of five products. Portfolio: [docs/ECOSYSTEM.md](docs/ECOSYSTEM.md) · [Ferrum PORTFOLIO.md](https://github.com/SynapticFour/Ferrum/blob/main/docs/PORTFOLIO.md).

## Prerequisites

Docker (~**8 GB** RAM, ~**20 GB** disk), `git`, `python3`, `curl`, `bash`, network (clone Ferrum, images, public data). **Sizing & phases:** [docs/architecture.md](docs/architecture.md).

**Demo-only security:** the gateway reaches Docker through **docker-socket-proxy** (host `docker.sock` is not bind-mounted on the gateway). Nested TES tasks may still receive a host-daemon `docker.sock` bind so Cromwell can start GATK. Crypt4GH `node.sec` is **generated at `./run` time and gitignored**. Do not copy this compose posture to a hospital network.

## Run

```bash
./run
# or: make up
```

Requires a **pinned** Ferrum git SHA in [PINNED_VERSIONS.txt](PINNED_VERSIONS.txt) (**v0.3.1**). Override only with `FERRUM_GA4GH_ALLOW_UNPINNED=1`. Canonical checkout env: **`FERRUM_SRC`** (default `.cache/stack/Ferrum`; `FERUM_SRC` still accepted as a deprecated alias).

Co-deploy **Ferrum + ga4gh-infra** (identity plane + data/compute):

```bash
./run --with-infra
# or: make up-with-infra
```

### Stop / tear down

| Goal | Command |
|------|---------|
| Stop containers, **keep data** | `./run --down` or `make down` |
| Remove volumes (fresh start) | `./run --destroy` or `make destroy` |

Default `./run` resets volumes before start unless you pass `--no-reset`.

| Flag | Effect |
|------|--------|
| *(default)* | WDL / Cromwell path. Caller is **blind** to the truth VCF (no `--alleles`). |
| `--nextflow` | Same GATK slice via `workflows/tiny_hc.nf` (Broad GATK 4.4) |
| `--gatk-rs` | **Optional Alpha:** Nextflow via `workflows/tiny_hc_gatk_rs.nf`. Not the evidence path. Soft-skips if the image is missing, empty, or `:latest` (pin `FERRUM_GA4GH_GATK_RS_IMAGE`; `FERRUM_GA4GH_ALLOW_LATEST=1` for a throwaway lab). |
| `--macro` | Two passes: plain + Crypt4GH-at-rest ingest; **merges** `results/drs_micro.json` with `plain` + `crypt4gh_at_rest` (+ optional `crypt4gh` if pubkey env set) |
| `--crypt4gh` | Requires `FERRUM_GA4GH_CRYPT4GH_PUBKEY`: adds optional **client-header** timing to `drs_micro.json` (see [benchmark.md](docs/benchmark.md)) |
| `--no-reset` | Keep compose volumes — see [architecture → Demo scope](docs/architecture.md#demo-scope-phases) |
| `--africa` | Apply Africa resilience overlay; run Africa scenarios **only** when probes show the capability (Beacon `/info` alone is not multi-pathogen). Skip-only → `verdict: not_evaluated`, not a pass. |
| `--with-infra` | Co-deploy **ga4gh-infra** + Ferrum external auth; see [architecture → Co-deploy](docs/architecture.md#co-deploy-with-ga4gh-infra) |
| `--giab-full` | **Not implemented** (exit 3). |
| `--help` | Full usage |

### Africa resilience features

Ferrum may grow Africa-specific endpoints (offline mode, ONT ingestion, multi-pathogen Beacon, outbreak mode, residency audit). This demo **probes** the running build and runs scenarios only for detected capabilities.

Missing features are **`not_evaluated`**, not a pass. Default `./run` **probes** Africa endpoints but does **not** run scenarios (so a broken residency chain cannot fail the GA4GH smoke). Pass **`--africa`** to run scenarios; `chain_valid: false` is then a **failure**, after artefacts are written.

```bash
./run --africa    # overlay + scenarios if features detected; failed scenarios exit 1 after writing artefacts
```

Results: `results/africa_results.json` — `summary.verdict` is `passed` | `failed` | `not_evaluated`.

See [synapticfour.com/en/ferrum-field](https://synapticfour.com/en/ferrum-field) for the field overview (product docs, not a certificate from this repo).

**Environment:** `FERRUM_GA4GH_ENGINE` (`wdl` \| `nextflow`), `FERRUM_GA4GH_CALLER` (`gatk` \| `gatk-rs`), `FERRUM_GA4GH_GATK_RS_IMAGE`, `FERRUM_GA4GH_GATK_RS_SOFT`, `FERRUM_GA4GH_MACRO_COMPARE`, `FERRUM_GA4GH_ENCRYPT_INGEST`, `FERRUM_GA4GH_CRYPT4GH_PUBKEY`, `FERRUM_GA4GH_RESET_VOLUMES`, `FERRUM_TES_DOCKER_PLATFORM` (arm64 defaults to `linux/amd64` for Nextflow), `FERRUM_SRC` / deprecated `FERUM_SRC`, `FERRUM_GA4GH_ALLOW_UNPINNED`. See `./run --help`.

**Verify artefacts after a run:** `make smoke-evidence` (or `make smoke-evidence-strict` after `--macro`). Coverage map: [docs/COVERAGE.md](docs/COVERAGE.md).

**Outputs:** `results/` — especially **`RUN_MANIFEST.json`**, `query.vcf.gz`, `benchmark.json`, `metrics.json`, `drs_micro.json`, `africa_results.json`, `trs_fetch.json`. **Docs:** `scripts/update_docs.py` refreshes the table below and [docs/benchmark.md](docs/benchmark.md).

## Village Network Demo (laptop simulation)

Two Ferrum **containers** on one laptop, labelled Kisumu and Nouna. This is **not** two Raspberry Pi 5s, **not** rural WiFi (no netem on the Ferrum path), and **not** a GA4GH conformance run.

```bash
FERRUM_IMAGE=ghcr.io/synapticfour/ferrum:<tag-or-digest> \
  bash demo/scenarios/village-network/run-village-demo.sh
```

`:latest` is refused. Stock Ferrum ignores `FERRUM_FEDERATION__*` until federation exists upstream; the script records `claims.federation_peers_queried` from the actual JSON. `ga4gh_compliant` is **always false** in `results/village-network-demo.json`.

For physical hardware, `demo/scenarios/raspberry-pi/install-ferrum-edge.sh` requires `FERRUM_IMAGE` (no `curl | bash`, no `get.docker.com | sh`).

Pipeline input policy: WES requests are **DRS-first** for the primary dataset (`input_drs_uri`) while keeping per-file workflow parameters bound to DRS-backed `/stream` URLs for engine compatibility.

### DRS `/stream` micro-benchmark (`drs_micro.json`)

Loopback/compose timings (n=3 by default), not a WAN benchmark.

| Key | When |
|-----|------|
| **`plain`** | Always (per pass): median wall time for streaming **plaintext** `ref_fasta`. |
| **`crypt4gh_at_rest`** | After **`./run --macro`**: second `ref_fasta` object (encrypted in MinIO); measures **server-side decrypt** on `GET .../stream`. |
| **`crypt4gh`** | If **`FERRUM_GA4GH_CRYPT4GH_PUBKEY`** is set (e.g. `demo/fixtures/crypt4gh-node/node.pub`): optional header timing; PEM is sent as **single-line base64**. |

Details: [docs/benchmark.md](docs/benchmark.md) (reviewer summary after a run).

## Docs layout

| File | Role |
|------|------|
| [docs/PERSONA.md](docs/PERSONA.md) | Institute persona: what `./run` proved vs not |
| [docs/CLAIMS.md](docs/CLAIMS.md) | Claim vs evidence (what you may cite) |
| [docs/OUTPUTS.md](docs/OUTPUTS.md) | What `./run` writes under `results/` |
| [docs/examples/RUN_MANIFEST.example.json](docs/examples/RUN_MANIFEST.example.json) | Manifest schema (no live numbers) |
| [docs/ECOSYSTEM.md](docs/ECOSYSTEM.md) | Portfolio role (proof/outreach, not a product) |
| [docs/COVERAGE.md](docs/COVERAGE.md) | What Demo proves vs Showcase/HelixTest; smoke targets |
| [PINNED_VERSIONS.txt](PINNED_VERSIONS.txt) | Ferrum/git + executor image pins |
| [docs/architecture.md](docs/architecture.md) | Diagram, data plane, resources |
| [docs/benchmark.md](docs/benchmark.md) | Last run tables (regenerated; read RUN_MANIFEST first) |

## Repository layout

| Path | Role |
|------|------|
| `./run`, `demo/run.sh` | Entrypoints |
| `demo/scenarios/village-network/` | Laptop two-container simulation |
| `demo/scenarios/raspberry-pi/install-ferrum-edge.sh` | Pi 5 installer (pinned image required) |
| `demo/docker-compose.ga4gh.yml` | TES, WES workdir, docker-socket-proxy, Crypt4GH keys (generated) |
| `demo/lib/*.py` | Ingest, WES JSON, metrics, Africa scenarios, manifests |
| `workflows/tiny_hc.{wdl,nf}` | Minimal HaplotypeCaller (**no** `--alleles`) |
| `scripts/` | Fetch, TRS cache, DRS micro-bench, `dataset_profile.py`, `update_docs.py` |
| `tests/` | Unit tests for evidence contract, probes, caller honesty |

## Last local run (regenerated by `./run`)

Numbers below are a **pipeline smoke**. If the dataset row says synthetic, do not cite them as GIAB. Previous F1=1.0 rows with `--alleles` truth remain withdrawn (`docs/paper/20260322T1331Z/WITHDRAWN.json`).

<!-- GA4GH_BENCHMARK_TABLE_START -->
| Metric | Value |
|--------|-------|
| Claim scope | Pipeline smoke — not a GIAB publication result |
| Dataset | Synthetic GIAB-style subset (22:1700-2300) — pipeline smoke, not a GIAB publication benchmark |
| Caller uses truth `--alleles` | no |
| Precision | 0.0 |
| Recall | 0.0 |
| F1 | 0.0 |
| Runtime (demo) | 51 s |
| WES engine | nextflow |
| DRS stream plain `ref_fasta` (median s) | 0.006153832946438342 |
| DRS stream Crypt4GH **at-rest** (median s, server decrypt) | n/a (`./run --macro` merges this) |
| DRS stream client header `X-Crypt4GH-Public-Key` (median s) | n/a (set `FERRUM_GA4GH_CRYPT4GH_PUBKEY` for header leg) |
| DRS micro repetitions (n) | 3 |
| BAM slice (on disk) | 847 B |
| WES run | `01M03CB216RJ2R4T2G5N1JX3X3` |

<!-- GA4GH_BENCHMARK_TABLE_END -->

**Reviewers:** After `./run`, DRS micro **plain vs at-rest** medians, explicit **n**, BAM slice size, **Cromwell vs Nextflow** land in [docs/benchmark.md](docs/benchmark.md). Cite `results/RUN_MANIFEST.json` (`hap_py.cite`), not this table alone. Schema: [docs/examples/RUN_MANIFEST.example.json](docs/examples/RUN_MANIFEST.example.json).

## Licence

This **repository** is [Apache-2.0](LICENSE). [Ferrum](https://github.com/SynapticFour/Ferrum) remains **BUSL-1.1** (see [NOTICE](NOTICE)). GATK / Dockstore descriptors follow their upstream licences.

---

**Synaptic Four** · [contact@synapticfour.com](mailto:contact@synapticfour.com) · [synapticfour.com](https://synapticfour.com) · this repo Apache-2.0; Ferrum binaries BUSL-1.1
