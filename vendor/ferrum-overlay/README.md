# Ferrum overlay (BUSL-1.1)

Rust sources here are **derived from Ferrum** and stay under Ferrum's
**BUSL-1.1**. See the repository [NOTICE](../../NOTICE).

They exist because this demo still pins Ferrum **v0.3.0**. Two honesty fixes
now live on Ferrum `main` (no synthetic WES QUEUED/RUNNING delay; residency
hash uses microsecond Zulu timestamps). `demo/run.sh` still rsyncs this tree
onto that **pinned** checkout before `docker compose build`. The next Ferrum
tag retires the overlay.

This overlay **must not**:

- fake WES poll states for HelixTest (QUEUED/RUNNING delay);
- use `:latest` executor images on the WDL/Nextflow path;
- report residency `chain_valid: true` without hashing the same canonical timestamp Postgres stores.

Pin fail in `demo/run.sh` is a hard error unless
`FERRUM_GA4GH_ALLOW_UNPINNED=1`. Overlay sources are rebased on Ferrum **v0.3.0**
(workdir log persistence kept; synthetic WES lifecycle delay removed;
residency hash uses microsecond Zulu timestamps so Postgres `chain_valid` works).
