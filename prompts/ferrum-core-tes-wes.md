# Ferrum core — TES / WES / GA4GH execution

Context: the **Ferrum-GA4GH-Demo** runs Cromwell and Nextflow via **real Docker TES** with nested GATK. Today that requires a small **overlay** on upstream Ferrum (`ferrum-gateway` `tes-docker`, `ferrum-wes` TES bodies, `ferrum-tes` Docker executor tweaks).

---

## Prompt (copy below)

You are helping improve **SynapticFour/Ferrum** (Rust, GA4GH WES/TES/DRS).

**Goal:** Reduce or eliminate the need for demo-only patches while keeping GA4GH compatibility.

**Observed integration patterns (from GA4GH demo):**

1. **WES → TES (WDL)** — TES task runs **Cromwell** with `inputs.json` under `FERRUM_WES_WORK_HOST/{run_id}`, bind-mounted at the **same absolute host path** inside the Cromwell container so nested `docker run -v` resolves on the host. Cromwell images use a Java entrypoint; the executor must override **entrypoint** and pass **`bash -lc`** + script or Cromwell treats extra args as JVM args.

2. **WES → TES (Nextflow)** — Same bind-mount. **Do not** rely on `nextflow run http://host/.../workflow.nf` alone: Nextflow 24+ may treat the URL like an SCM provider and fail. **Reliable pattern:** `curl`/`wget` workflow to a local `workflow.nf`, write minimal `nextflow.config` with `docker { enabled = true }`, then `nextflow run workflow.nf -params-file params.json`. Bare **`-with-docker`** without a global image can abort; **`docker { enabled = true }`** + per-process `container` works.

3. **TES Docker executor** — Needs optional **`docker.sock`** and static **Linux `docker` CLI** bind for nested containers; **compose `network_mode`** so Cromwell/Nextflow can reach `ferrum-gateway` on the compose network; **`extra_hosts`** (`host.docker.internal:host-gateway`) for fetching workflow descriptors from the host.

4. **Multi-arch** — Official **nextflow/nextflow** images are often **amd64-only**. Optional **`FERRUM_TES_DOCKER_PLATFORM=linux/amd64`** (or equivalent) on **container create** helps **arm64** dev machines (Apple Silicon).

5. **DRS `/stream` and workflow engines** — URLs commonly end with path **`stream`**. Staging by basename causes **collisions** for multiple inputs. Workflow authors need **`stageAs:`** (Nextflow) or equivalent distinct local names.

6. **Gateway build** — Docker TES path uses **`--features tes-docker`** on `ferrum-gateway`; document or default for “full stack” profiles.

**Ask:** Propose concrete upstream changes (code, env vars, docs) so a **GA4GH benchmark repo** can depend on Ferrum with **minimal or no overlay**. Reference crates: `ferrum-tes`, `ferrum-wes`, `ferrum-gateway`.

---

## Reference overlay files (demo)

Paths relative to **Ferrum-GA4GH-Demo** `vendor/ferrum-overlay/`:

- `crates/ferrum-wes/src/executors/tes.rs`
- `crates/ferrum-tes/src/executors/docker.rs`
- `crates/ferrum-gateway/Cargo.toml`, `src/main.rs`, `deploy/Dockerfile.gateway`
