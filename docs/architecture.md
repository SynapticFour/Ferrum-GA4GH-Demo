# Architecture

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
    C[Cromwell container]
    GK[GATK container]
  end
  R -->|multipart ingest| DRS
  R -->|Dockstore API| TRSnote[Dockstore TRS public API]
  TRSnote -.->|cache WDL| R
  R -->|POST /runs WDL| WES
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

1. **Reference + reads + truth** — `scripts/fetch_giab_subset.sh` downloads a **GRCh37** window on **chr22** from public Platinum / GIAB / 1000G endpoints (see `demo/config.yaml`).
2. **Static HTTP** — `python3 -m http.server` exposes `workflows/tiny_hc.wdl` to **Cromwell** using `host.docker.internal` (plus `host-gateway` extra_hosts on Linux).
3. **DRS** — Local files are uploaded with `POST /ga4gh/drs/v1/ingest/file`. Cromwell localizes **`GET /ga4gh/drs/v1/objects/{id}/stream`** URLs (`http://ferrum-gateway:8080/...`) so nested tasks read raw bytes from the gateway on the compose network.
4. **WES → TES** — Ferrum’s WES layer submits a TES task running **broadinstitute/cromwell** with `inputs.json` under a host bind mount. The run directory is mounted at the **same absolute host path** inside Cromwell so nested `docker run -v ...` paths resolve on the host (Docker Desktop–safe). **FERRUM_TES_EXTRA_BINDS** adds `docker.sock` plus a **Linux static `docker` client** (see `scripts/ensure_docker_cli_static.sh`) because the Cromwell image has no Docker CLI.
5. **Nested GATK** — Cromwell’s `runtime { docker: ... }` blocks spawn **broadinstitute/gatk** via the mounted **docker.sock**.

## Patch overlay

Files under `vendor/ferrum-overlay/` are rsync’d onto a shallow **Ferrum** clone in `.cache/ferrum` before `docker compose build`. They:

- Enable **`FERRUM_TES_BACKEND=docker`** (still defaults to `noop` if unset).
- Teach the WES→TES client to pass **WDL inputs** and bind **`FERRUM_WES_WORK_HOST/{run_id}`** at the **same absolute path** inside Cromwell as on the host (so nested Docker sees valid host paths).
- Extend the TES Docker backend with **bind mounts**, **compose network attachment**, optional **extra_hosts** for `host.docker.internal`, and **entrypoint override** so `bash -lc` Cromwell wrappers are not passed to the JVM entrypoint.
- Patch **DRS** `get_access_url` to accept `access_url` stored as either a JSON string or `{"url":...}` (matches `create_object_with_id`).

## Benchmark

`benchmark/Dockerfile.happy` builds a **linux/amd64** **micromamba** image with **hap.py** (0.3.15) and **rtg-tools** (vcfeval). `benchmark/run_happy.sh` compares `results/query.vcf.gz` to `data/truth_slice.vcf.gz` inside the confident **BED** subset and writes `results/benchmark.json` from `results/happy.metrics.json.gz`.
