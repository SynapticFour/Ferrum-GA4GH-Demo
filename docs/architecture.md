# Architecture

Technical reference for this demo. **Operator entry:** [README](../README.md) (`./run`, env vars). **Last metrics:** [benchmark.md](./benchmark.md) (auto-generated after `./run`; pipeline smoke, not a GIAB paper).

## Demo scope (phases)

| # | What | Run |
|---|------|-----|
| 1 | DRS `/stream` micro-timing (plain; optional client header) | Every pass; `./run --crypt4gh` + `FERRUM_GA4GH_CRYPT4GH_PUBKEY` (PEM → single-line base64 in script) |
| 2 | Macro: plain vs Crypt4GH-at-rest ingest + **dual DRS micro** (`ref_fasta` plain oid vs encrypted oid) | `./run --macro` or `./run --nextflow --macro` |
| 3 | Nextflow same slice as WDL | `./run --nextflow` |
| 4 | Docs / `./run --help` / **syntax CI** | Done (stack runs are **local-only** — see [COVERAGE.md](./COVERAGE.md)) |

**`./run --no-reset`** sets `FERRUM_GA4GH_RESET_VOLUMES=0` and skips `compose down -v`. Faster iteration, but **`ferrum-init` migrations** can conflict with an existing DB. If init fails, run a **full** `./run` without `--no-reset`.

```mermaid
flowchart TB
  subgraph Client
    R[demo/run.sh]
  end
  subgraph FerrumStack[Ferrum Docker Compose]
    G[ferrum-gateway]
    DRS[DRS /ingest + /objects]
    TRS[TRS /tools]
    WES[WES /runs]
    TES[TES /tasks]
    PG[(Postgres)]
    S3[(MinIO)]
  end
  subgraph Exec[TES execution]
    C[Cromwell or Nextflow]
    GK[GATK container]
  end
  R -->|multipart ingest| DRS
  R -->|Dockstore API| TRSnote[Dockstore TRS public API]
  TRSnote -.->|cache WDL| R
  R -->|POST /runs| WES
  WES -->|POST /tasks| TES
  TES -->|Docker API| C
  C -->|docker.sock| GK
  DRS --> PG
  DRS --> S3
  G --> DRS
  G --> WES
  G --> TES
```

## Data plane

1. **Data** — `scripts/fetch_giab_subset.sh` + `demo/config.yaml` (GRCh37 chr22 window; synthetic fallback).
2. **Static HTTP** — `python3 -m http.server` serves `workflows/tiny_hc.{wdl,nf}` via `host.docker.internal` (+ `host-gateway` on Linux).
3. **DRS** — `POST .../ingest/file`; WES payload carries a DRS-first marker (`input_drs_uri`) and engines localize per-file `GET .../objects/{id}/stream` inputs on the compose network.
4. **DRS micro** — `scripts/drs_micro_benchmark.py` → `results/drs_micro.json`. After `./run --macro`, the script re-runs with `--encrypted-object-id` so `crypt4gh_at_rest` compares server-side decrypt timing vs plaintext `ref_fasta`. Optional `X-Crypt4GH-Public-Key` (PEM ok) for experiments; gateway re-wrap needs Passport auth in stock Ferrum.
5. **WES → TES (WDL)** — Cromwell + `inputs.json` under `{FERRUM_WES_TES_WORK_HOST_PREFIX}/{run_id}` (same path on host and in the task container). Stock Ferrum env: `FERRUM_WES_TES_WDL_BASH_LAUNCH`, `FERRUM_WES_TES_WORK_HOST_PREFIX` (see [Ferrum TES-DOCKER-BACKEND](https://github.com/SynapticFour/Ferrum/blob/main/docs/TES-DOCKER-BACKEND.md)). TES Docker: `FERRUM_TES_DOCKER_MOUNT_SOCKET`, `FERRUM_TES_DOCKER_CLI_HOST_PATH` + static Linux `docker` (`scripts/ensure_docker_cli_static.sh`).
6. **WES → TES (Nextflow)** — `params.json`, `curl` → `workflow.nf`, `nextflow.config` with `docker { enabled = true }`, then `nextflow run workflow.nf` (no bare `-with-docker`; NF 24+). Image `nextflow/nextflow:24.10.3`.
7. **Nested GATK** — `docker.sock` + `broadinstitute/gatk:4.4.0.0@sha256:044112d3d70603732d4a654ecaee33919cf9d45332d47268f5f1697b6ed558ed`.

## Phase 2 macro (Crypt4GH at rest)

`FERRUM_GA4GH_MACRO_COMPARE=1` or `./run --macro`: two passes on one stack — plaintext ingest, then `encrypt=true` using keys in `demo/fixtures/crypt4gh-node/`. Saves `results/drs_mapping_phase_plain.json`, then merges DRS micro into one `drs_micro.json` with both `plain` and `crypt4gh_at_rest`. WDL or Nextflow. Outputs: `results/phase2_pass_*.json`, `metrics.json` → `phase2_macro`. hap.py checks scientific equivalence, not byte-identical VCF.

## Resource planning (order-of-magnitude)

| Profile | RAM | Disk | Transfer (first run) |
|---------|-----|------|----------------------|
| **Current subset** | 8–12 GB host | ~5–15 GB | ~1–5 GB |
| **`./run --macro`** | same | + MinIO objects | ~2× pipeline time |
| **`./run --nextflow`** | same | + Nextflow image pull | amd64 image; on **arm64** demo sets `FERRUM_TES_DOCKER_PLATFORM=linux/amd64` |
| **Full GIAB-style WGS** (not implemented; `./run --giab-full`) | 32–64 GB+ | 200 GB–1 TB+ | 50–200 GB+ |

Crypt4GH: DRS micro (macro) = plaintext stream vs at-rest ciphertext + **server decrypt** on `/stream`; optional client-header timing if `FERRUM_GA4GH_CRYPT4GH_PUBKEY` is set. Macro adds extra gateway CPU; MinIO I/O is on the Docker network, not “internet”.

### `results/drs_micro.json` (merged after `./run --macro`)

| Field | Meaning |
|-------|---------|
| `plain` | Timings for `GET .../stream` on **plaintext** `ref_fasta` (current pass or plain-phase id). |
| `crypt4gh_at_rest` | Timings for **encrypted-at-rest** `ref_fasta` (second object id); Ferrum **decrypts while streaming**. |
| `crypt4gh` | Optional: same plain URL with `X-Crypt4GH-Public-Key` (PEM file is reduced to **one-line base64** in `scripts/drs_micro_benchmark.py`). |
| `encrypted_object_id` | DRS id of the at-rest `ref_fasta` leg (paired with plain id from `results/drs_mapping_phase_plain.json`). |

Single `./run` (no `--macro`): only the **current** ingest’s `ref_fasta` is timed under `plain`; `crypt4gh_at_rest` is absent unless you pass `--encrypted-object-id` manually. Full reviewer-facing tables: [benchmark.md](./benchmark.md) after `./run`.

Extra clone path: **`FERRUM_SRC`** (deprecated alias `FERUM_SRC`, default `.cache/stack/Ferrum`). Pin is required. See [PINNED_VERSIONS.txt](../PINNED_VERSIONS.txt).

## Patch overlay (demo)

`vendor/ferrum-overlay/` is rsync’d onto the **pinned** Ferrum checkout (v0.3.0) before `docker compose build`. Overlay Rust is **BUSL-1.1** (NOTICE). Pin checkout failure is a hard error unless `FERRUM_GA4GH_ALLOW_UNPINNED=1`. `ferrum-gateway` `Cargo.toml` / `main.rs` are **not** rsynced (those overlay copies would strip features).

- **`ferrum-wes` `executors/tes.rs`** — Ferrum v0.3.0 workdir/log persistence; **no** synthetic HelixTest QUEUED/RUNNING delay; pinned Cromwell / Nextflow images.
- **`ferrum-tes` `executors/docker.rs`** — docker executor + bind policy (stock TES is noop without `tes-docker`).
- **`ferrum-core` `residency.rs`** — hash audit timestamps as **microsecond Zulu** so Postgres `timestamptz` round-trips keep `chain_valid` true. Stock v0.3.0 `to_rfc3339()` (nanos / `+00:00` vs `Z`) makes verify return false.

Compose **`FERRUM_GATEWAY_FEATURES=tes-docker`**, **`FERRUM_TES_DOCKER_*`**, **`FERRUM_WES_TES_*`** follow [Ferrum](https://github.com/SynapticFour/Ferrum). Conformance: [HelixTest](https://github.com/SynapticFour/HelixTest). Lab on-ramp: [Ferrum-Lab-Kit](https://github.com/SynapticFour/Ferrum-Lab-Kit).

## Village Network simulation (field / edge)

Two Ferrum **containers** on one laptop (labels Kisumu + Nouna). This is **not** two Raspberry Pis, **not** rural WiFi (there is no netem on the Ferrum path), and **not** a conformance run. `FERRUM_IMAGE` must be a pin; `:latest` is refused. `FERRUM_AFRICA__*` / `FERRUM_FEDERATION__*` are ignored by stock Ferrum until those features exist. The village script writes `ga4gh_compliant: false`.

| Path | Role |
|------|------|
| `demo/scenarios/village-network/docker-compose.village.yml` | Two-node compose + network shaper |
| `demo/scenarios/village-network/run-village-demo.sh` | Full demo: ingest, federated query, resilience, audit |
| `demo/lib/africa_scenarios.py` | Synthetic ONT/pathogen ingest per node |
| `demo/lib/africa_feature_detect.py` | Probe gateway for Africa/federation flags |

**Simulation-first, then hardware:** the compose file is a laptop stand-in. Physical install: `install-ferrum-edge.sh` with a **pinned** `FERRUM_IMAGE` (no curl|bash).

```mermaid
flowchart LR
  subgraph VillageNet[village-net internal]
    K[ferrum-kisumu]
    N[ferrum-nouna]
    S[network-shaper netem]
    K <-->|1 Mbit/s| N
    S --- VillageNet
  end
  H[Host laptop] -->|18081| K
  H -->|18082| N
```

`demo/run.sh` runs **`git checkout`** on paths we no longer overlay so stale patches in `.cache/stack/Ferrum` are dropped. DRS `repo.rs` is **not** patched.

**Host vs container paths:** `demo/run.sh` sets **`FERUM_WES_WORK_HOST`** to **`$REPO/results/wes-work`** (absolute), passed into compose as **`FERRUM_WES_TES_WORK_HOST_PREFIX`**. Custom bind: **`FERRUM_GA4GH_WES_HOST_OVERRIDE`** (absolute path on the Docker host).

## Benchmark (hap.py)

`benchmark/Dockerfile.happy` — linux/amd64 micromamba, hap.py + rtg-tools. `benchmark/run_happy.sh` → `results/benchmark.json`.

Auto-generated **[docs/benchmark.md](./benchmark.md)** includes the main metrics table (plain / **Crypt4GH at-rest** / optional **client header** medians when present), **Publication-friendly summary** with a **DRS micro JSON keys** table and median rows, DRS micro **n**, on-disk **BAM / ingest totals** (`scripts/dataset_profile.py` → `results/dataset_profile.json`), **Cromwell vs Nextflow** (`demo/lib/update_engine_compare.py` → `results/engine_compare.json`), and **Africa resilience features** (from `results/africa_results.json`). Run **`./run`**, **`./run --nextflow`**, and **`./run --macro`** to populate engine compare and merged DRS micro; `results/` is gitignored but the markdown is often committed after local runs.

## Africa feature detection

After the standard GA4GH benchmark completes, `demo/run.sh` probes the running
Ferrum gateway via `demo/lib/africa_feature_detect.py` to determine which
Africa resilience features are available in the current Ferrum build.

The probe is non-destructive and non-blocking. Scenarios run via
`demo/lib/africa_scenarios.py` in the same process. Results are written to
`results/africa_results.json` and merged into `results/metrics.json`.

The `./run --africa` flag additionally applies `demo/docker-compose.africa.yml`
which configures Africa-specific Ferrum environment variables. These are ignored
by Ferrum builds that do not implement the Africa features.

**Invariant:** `./run` (without `--africa`) produces identical results regardless
of which Africa features are or are not present in the Ferrum build.

## Co-deploy with ga4gh-infra

`./run --with-infra` starts **ga4gh-infra** alongside Ferrum in one Docker Compose
project. Infra listens on a dedicated port block (**8180–8190**, **9100**) so it
does not clash with Ferrum’s gateway (**18080** by default).

| Port | Service |
|------|---------|
| 8180 | aai-broker |
| 8181 | visa-registry |
| 8182 | duo-service |
| 8183 | service-registry |
| 8190 | access-decision-service (ADS) |
| 9100 | mock-idp (OIDC upstream for broker login demos) |

| Path | Role |
|------|------|
| `demo/docker-compose.ga4gh-infra.yml` | ga4gh-infra SQLite stack (co-deploy ports) |
| `demo/docker-compose.co-deploy.yml` | Ferrum external auth + service-registry discovery |
| `demo/config/ga4gh-infra/*.toml` | Co-deploy TOML (host `localhost:818x` URLs) |
| `demo/lib/infra_feature_detect.py` | Probe broker, visa-registry, service-registry, ADS |
| `demo/lib/co_deploy_scenarios.py` | Broker login → Passport → DRS; registry listing |

**Compose merge order:** `deploy/docker-compose.yml` → `demo/docker-compose.ga4gh.yml`
→ `demo/docker-compose.ga4gh-infra.yml` → `demo/docker-compose.co-deploy.yml`
→ optional `demo/docker-compose.africa.yml`.

**Ferrum env (co-deploy overlay):** `FERRUM_AUTH__MODE=external`,
`FERRUM_AUTH__ISSUER=http://127.0.0.1:8180` (must match broker JWT `iss` /
`external_url` in `broker.sqlite.toml`), `FERRUM_AUTH__JWKS_URL=http://aai-broker:8080/jwks.json`
(Docker-network fetch from the gateway), `FERRUM_SERVICES__ENABLE_PASSPORTS=false`,
`FERRUM_DISCOVERY__ENABLED=true`, `FERRUM_DISCOVERY__AUTO_REGISTER=true`.
`aai-broker` needs `REGISTRY_BOOTSTRAP_API_KEY` (ga4gh-infra v0.2.2 fail-closes without it).
Built-in ferrum-passports are disabled; Passports are validated via ga4gh-clearinghouse
against the broker JWKS. `test-object-1` is workspace-private: the co-deploy scenario
adds the mock-idp subject as a `demo-workspace-01` viewer before the Bearer DRS GET.

**Clone layout:** default `FERRUM_SRC=$ROOT/.cache/stack/Ferrum` and
`GA4GH_INFRA_SRC=$ROOT/.cache/stack/ga4gh-infra` (siblings) so the monorepo
`Dockerfile.gateway-monorepo` context (`COPY Ferrum/` + `COPY ga4gh-infra/`) works.
`--with-infra` runs ga4gh-infra `scripts/prepare-docker-vendor.sh` (`docker/vendor` is
gitignored; Dockerfiles `COPY` it). Override with `GA4GH_INFRA_SRC`.

Co-deploy scenarios run **before** the WES pipeline when infra is detected (auth/registry
must not wait on hap.py). Failures are recorded and the pipeline still writes artefacts;
the process exits 1 at the end. Results: `results/co_deploy_results.json`.

**Invariant:** `./run` (without `--with-infra`) is unchanged. Co-deploy scenarios
are skipped with `summary.verdict: not_evaluated` and `all_passed: false` when
infra is absent. Skip is not a pass.

```mermaid
flowchart LR
  subgraph Infra[ga4gh-infra 8180-8190]
    IDP[mock-idp :9100]
    BR[aai-broker :8180]
    VR[visa-registry :8181]
    SR[service-registry :8183]
    ADS[ADS :8190]
  end
  subgraph Ferrum[Ferrum :18080]
    GW[ferrum-gateway]
    DRS[DRS]
  end
  IDP --> BR
  VR --> BR
  ADS --> BR
  BR -->|Passport JWT| GW
  GW -->|auto_register| SR
  GW --> DRS
```
