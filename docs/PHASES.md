# Demo phases (roadmap)

This repository grows in **numbered phases**. Each phase adds a measurable or operator-facing slice on top of the same Ferrum stack (`demo/run.sh`, `vendor/ferrum-overlay/`).

| Phase | Focus | How to run | Status |
|-------|--------|------------|--------|
| **1** | **DRS micro-benchmark** — wall time for `GET .../objects/{id}/stream` (plain; optional Crypt4GH client header) | Default in every pass; add `./run --crypt4gh` + `FERRUM_GA4GH_CRYPT4GH_PUBKEY` | Done (`scripts/drs_micro_benchmark.py`, `results/drs_micro.json`) |
| **2** | **Macro A/B** — plaintext multipart ingest vs **Crypt4GH-at-rest** (`encrypt=true`); same engine, same hap.py truth | `./run --macro` or `./run --nextflow --macro` | Done (`FERRUM_GA4GH_MACRO_COMPARE`, `results/phase2_pass_*.json`) |
| **3** | **Nextflow parity** — same GATK window as WDL via `workflows/tiny_hc.nf` and WES `NEXTFLOW` | `./run --nextflow` | Done |
| **4** | **Documentation & CLI UX** — single entrypoint (`./run`), help text, linked docs, accurate auto-generated benchmark prose | `./run --help`; this file; [README](../README.md), [architecture](./architecture.md) | Done |

## References

- [Architecture](./architecture.md) — data plane, overlay, TES/WES paths  
- [Benchmark](./benchmark.md) — hap.py table (regenerated each run)  
- [Resource estimates](./RESOURCE-ESTIMATES.md) — RAM, disk, transfer  
- [Apache-2.0 licence](../LICENSE) — this repo’s scripts and docs (Ferrum upstream remains BUSL)
