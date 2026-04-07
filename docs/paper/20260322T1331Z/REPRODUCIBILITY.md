# Reproducibility (paper bundle)
Generated (UTC): `2026-03-22 13:31:37Z`
## Ferrum-GA4GH-Demo
- **Git commit (this snapshot):** run `git log -1 --format=%H -- docs/paper/20260322T1331Z` from the repo root after checkout (stable pointer to the tree that contains this folder).
- **Branch:** `main`

## Upstream Ferrum (clone)
- **Path:** `.cache/ferrum`
- **Commit:** `27123587b550a4df724f67e81cc0058e1d4e4438`
- **Short:** `27123587`

## Host
- **uname:** `Darwin MacBook-Air-von-Synaptic Four 25.3.0 Darwin Kernel Version 25.3.0: Wed Jan 28 20:54:55 PST 2026; root:xnu-12377.91.3~2/RELEASE_ARM64_T8132 arm64`
- **Python:** `3.14.3`
- **Docker:** `Docker version 29.2.1, build a5c7197d72`
- **Docker Compose:** `Docker Compose version v5.1.0`
- **Linux docker CLI (bind-mount into TES / Cromwell):** `x86_64:27.4.1` (`scripts/ensure_docker_cli_static.sh`, file `.cache/docker-cli-static/docker-cli.version`)

## Pinned workflow / executor images (demo)
- **Cromwell (WES→TES bash mode):** `broadinstitute/cromwell:93-0232cbd` (see `vendor/ferrum-overlay/crates/ferrum-wes/src/executors/tes.rs`)
- **Nextflow (WES→TES):** `nextflow/nextflow:24.10.3`
- **GATK (nested):** `broadinstitute/gatk:4.4.0.0` (WDL/NF in-repo workflows)
- **hap.py image:** `benchmark/Dockerfile.happy` (micromamba-based)

## Crypt4GH
- **Node keys (demo):** `demo/fixtures/crypt4gh-node/` (`node.pub` → `FERRUM_GA4GH_CRYPT4GH_PUBKEY`)

## Paper JSON snapshot
- **Directory:** `docs/paper/20260322T1331Z/`
- **Orchestrator:** `bash scripts/run_paper_bundle.sh`
