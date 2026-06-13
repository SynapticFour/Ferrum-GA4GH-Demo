# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

- **Benchmark artefacts** — Regenerated `./run`, `./run --nextflow`, and `./run --macro` against current Ferrum (`FERRUM_SRC`); updated `docs/benchmark.md`, README snapshot table, `demo/inputs.json`, `demo/nf_params.json`, and `drs/mapping.json` (Cromwell 54 s, Nextflow 24 s; DRS plain vs Crypt4GH-at-rest medians).

### Fixed

- **`demo/run.sh`** — Run `compose_metrics.py` before `update_engine_compare.py` so `results/engine_compare.json` and the Cromwell vs Nextflow table reflect the current pass, not stale timings.

### Security
