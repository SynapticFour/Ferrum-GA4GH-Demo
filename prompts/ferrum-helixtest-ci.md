# Ferrum — HelixTest / CI vs production TES

Context: upstream Ferrum defaults to **noop TES** for lightweight CI (**HelixTest** and similar paths). The **GA4GH demo** needs **real Docker TES**; mixing “keep volumes” compose runs with **`ferrum-init`** exposed migration friction.

---

## Prompt (copy below)

You are helping improve **SynapticFour/Ferrum** CI and **init** behaviour.

**Problem A — TES backend expectations:**  
CI uses **noop TES**; self-hosters and GA4GH demos need **Docker TES** with documented env (`FERRUM_TES_BACKEND`, `FERRUM_TES_WORK_DIR`, `FERRUM_TES_EXTRA_BINDS`, `FERRUM_TES_DOCKER_NETWORK`, `FERRUM_TES_EXTRA_HOSTS`, optional `FERRUM_TES_DOCKER_PLATFORM`). **Ask:** Make the split **explicit in docs** (HelixTest vs “full stack”), and consider a **compose profile** or **documented recipe** for Docker TES so demos do not fork `Dockerfile.gateway`.

**Problem B — `ferrum-init` / migrations:**  
Re-running init against an **existing** Postgres volume sometimes yields **“relation already exists”** or partial migration state when operators skip `docker compose down -v` (`--no-reset`-style workflows). **Ask:** Harden migrations (idempotency, version table, or init guard) or document **required** reset semantics for development.

**Deliverable:** Short ADR or `docs/` section: *HelixTest / CI defaults* vs *Docker TES GA4GH profile*, plus migration expectations.

---

## Naming note

**HelixTest** here means Ferrum’s **automated / lightweight test** configuration (noop TES, fast feedback). If your repo uses a different public name, retitle this file locally.
