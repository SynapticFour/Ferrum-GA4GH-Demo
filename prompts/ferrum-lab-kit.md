# Ferrum — local lab kit / compose parity

Context: **Ferrum-GA4GH-Demo** runs a **compose overlay** (`demo/docker-compose.ga4gh.yml`) on top of Ferrum’s `deploy/docker-compose.yml`: TES, WES host workdir mount, `docker.sock`, Crypt4GH node keys, `extra_hosts` for `host.docker.internal`.

“**Lab kit**” = any **local developer bundle** (compose files, env templates, README) shipped with Ferrum or a sibling repo.

---

## Prompt (copy below)

You are aligning **Ferrum’s local development / lab** story with **GA4GH TES + WES** workflows.

**Checklist for lab compose:**

1. **Gateway** receives **`FERRUM_WES_WORK_HOST`** (absolute host path) matching what **Rust** reads inside the container — **not** conflated with the **host-side** compose variable name used in `docker compose` substitution (the GA4GH demo historically uses **`FERUM_WES_WORK_HOST`** on the host to populate **`FERRUM_WES_WORK_HOST`** in the service env; consider **one spelling** upstream to avoid confusion).

2. **Mounts:** `FERRUM_WES_WORK_HOST` → `/wes-runs` (or documented equivalent), **`docker.sock`**, optional static **`docker` CLI** for Linux targets inside TES tasks.

3. **Networking:** `FERRUM_TES_DOCKER_NETWORK` = compose project network; **`FERRUM_TES_EXTRA_HOSTS`** includes `host.docker.internal:host-gateway` (Linux) so nested engines can fetch workflow URLs from the host.

4. **Crypt4GH (optional):** Document mount for **node keypair** and DRS `encrypt=true` if the lab kit claims parity with encrypted-at-rest demos.

**Ask:** Produce or update a **single “full stack” compose overlay example** in Ferrum docs that matches these env vars, so external demos can **rsync fewer patches**.

---

## Optional

If the lab kit is a **separate repository**, link it from Ferrum’s main README and keep env var names **identical** to `deploy/docker-compose.yml` + GA4GH overlay conventions.
