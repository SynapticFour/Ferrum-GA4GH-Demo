# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Crypt4GH keys** — `node.sec` / `node.pub` generated at `./run` (gitignored). Previously committed private key is burned; git history rewrite is an operator step.
- **docker-socket-proxy** — gateway no longer bind-mounts host `docker.sock`. Nested TES may still bind the host socket. Not a hospital TES posture.
- **`live-run.yml`** — schedule + dispatch only. GitHub-hosted is not `./run` evidence unless `FERRUM_GA4GH_LIVE_RUN=1`.
- **Ferrum pin v0.3.1** — stock checkout, `vendor/ferrum-overlay` removed. TES poll and residency hash are upstream.

### Added

- **`docs/PERSONA.md`** — institute persona sheet (what `./run` proved vs not).

### Changed

- **Africa ONT ingest** — `ont_metadata` matches Ferrum v0.3.0 (`format: fastq`, required `source_path`); DRS id from `object_id`.
- **`--with-infra` vendor** — run ga4gh-infra `scripts/prepare-docker-vendor.sh` before compose (Dockerfiles `COPY docker/vendor`; that tree is gitignored).
- **`--with-infra` Passport DRS** — add mock-idp subject as `demo-workspace-01` viewer before Bearer GET (`test-object-1` is workspace-private).
- **Residency overlay** — hash audit timestamps as microsecond Zulu so Postgres `chain_valid` matches stored `timestamptz` (stock Ferrum v0.3.0 `to_rfc3339()` round-trip is false).
- **Honesty / evidence contract** — Caller no longer receives `--alleles` truth. Skip-only Africa/co-deploy is `not_evaluated`, not a pass. Invalid residency `chain_valid` is an error **when `./run --africa`**. Default `./run` probes Africa but does not fail the GA4GH smoke on those scenarios; artefacts (`RUN_MANIFEST.json`) are always written.
- **Ferrum pin** — `PINNED_VERSIONS.txt` tracks Ferrum **v0.3.0** (`6444469…`). Overlay rebased on that tag (honest WES poll, keep 0.3 workdir logs). Default clone path `.cache/stack/Ferrum` so `--with-infra` monorepo context works.
- **Overlay** — Removed HelixTest WES poll delay. Executor images pinned (no `:latest` on WDL/NF path). Overlay SPDX/NOTICE (BUSL-1.1). Ferrum and ga4gh-infra git pins are a hard fail unless `FERRUM_GA4GH_ALLOW_UNPINNED=1`. Canonical env `FERRUM_SRC`.
- **CI** — unittest in CI; CodeQL Python only; dependency-review fail-closed; Dependabot for GitHub Actions restored.
- **Village / Pi** — No fake netem, no `ga4gh_compliant: true`, no `curl|bash` / `get.docker.com|sh`. `:latest` refused.
- **`FERRUM_SRC` alias** — `demo/run.sh` accepts documented `FERRUM_SRC` as well as `FERUM_SRC`.
- **Architecture honesty** — Phase 4 CI is syntax-only; live stack remains local (`./run`).
- **gatk-rs Alpha** — `:latest` / empty image refused unless `FERRUM_GA4GH_ALLOW_LATEST=1`. Not the evidence path.

### Security

- Static HTTP serves `workflows/` only (not repo root / Crypt4GH keys).
- Docker static CLI verified against `download.docker.com` SHA256SUMS.

### Added

- **`docs/CLAIMS.md` / `docs/OUTPUTS.md` / example `RUN_MANIFEST.json`** — claim vs evidence; what `./run` writes.
- **Unit tests** — evidence contract, residency chain, feature probes, caller honesty, docs honesty, withdrawn paper JSON.
- **Coverage map + evidence smokes** — [docs/COVERAGE.md](docs/COVERAGE.md), `PINNED_VERSIONS.txt`, `make smoke-syntax` / `smoke-evidence` / `smoke-evidence-strict`.
- **Optional `--gatk-rs` path** — Nextflow workflow `workflows/tiny_hc_gatk_rs.nf` (Alpha). Soft-skips when image missing or unpinned. Default Broad GATK unchanged.

### Fixed

- **`demo/run.sh`** — Run `compose_metrics.py` before `update_engine_compare.py` so `results/engine_compare.json` reflects the current pass.
- **`--with-infra` clone** — pin checked before clone; existing checkout must match `GA4GH-INFRA-git=`.
