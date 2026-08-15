# Ferrum overlay (BUSL-1.1)

Rust sources here are **derived from Ferrum** and stay under Ferrum's
**BUSL-1.1**. See the repository [NOTICE](../../NOTICE).

They exist because stock Ferrum TES defaults to noop until
`FERRUM_GATEWAY_FEATURES` includes `tes-docker` and WES workdir binds are
configured. `demo/run.sh` rsyncs this tree onto the **pinned** Ferrum
checkout before `docker compose build`.

This overlay **must not**:

- fake WES poll states for HelixTest (QUEUED/RUNNING delay);
- use `:latest` executor images on the WDL/Nextflow path;
- report residency `chain_valid: true` without hashing the same canonical timestamp Postgres stores.

Pin fail in `demo/run.sh` is a hard error unless
`FERRUM_GA4GH_ALLOW_UNPINNED=1`. Overlay sources are rebased on Ferrum **v0.3.0**
(workdir log persistence kept; synthetic WES lifecycle delay removed;
residency hash uses microsecond Zulu timestamps so Postgres `chain_valid` works).
