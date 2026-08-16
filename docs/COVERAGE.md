# Ferrum-GA4GH-Demo coverage map

**Date:** 2026-08-15
**Honesty:** This repo is a **GA4GH pipeline smoke** (DRS · WES · TES + hap.py on a tiny slice, plus a TRS **descriptor fetch**). It is **not** a GIAB publication benchmark, not HelixTest conformance, and not a field-hardware proof.

**Pins:** [`PINNED_VERSIONS.txt`](../PINNED_VERSIONS.txt) (Ferrum **v0.3.1**) · Image policy: [`IMAGE-PIN-POLICY.md`](IMAGE-PIN-POLICY.md)

## What this Demo verifies (tangible)

| Layer | How | Command | Evidence |
|-------|-----|---------|----------|
| TRS descriptor fetch (not executed) | Dockstore GET | `./run` | `results/trs_fetch.json` (`executed: false`) |
| DRS ingest + `/stream` | Pipeline inputs | `./run` | `drs/mapping.json`, `results/drs_micro.json` → `plain` |
| WES → TES → GATK (WDL) | Cromwell | `./run` (default) | `results/query.vcf.gz`, `metrics.json`, `RUN_MANIFEST.json` |
| WES → TES → GATK (Nextflow) | Nextflow | `./run --nextflow` | same + `engine_compare.json` when both run |
| hap.py vs truth | Docker hap.py | every successful `./run` | `results/benchmark.json` (precision/recall/F1) |
| Crypt4GH at-rest DRS micro | dual ingest | `./run --macro` | `drs_micro.json` → `crypt4gh_at_rest` |
| Crypt4GH client header (optional) | pubkey env | `./run --crypt4gh` | `drs_micro.json` → `crypt4gh` |
| Africa feature probes | detect + scenarios | after `./run` / `--africa` | `results/africa_results.json` (`summary.verdict`; skip is not a pass) |
| ga4gh-infra co-deploy | Passport / registry | `./run --with-infra` | `results/co_deploy_results.json` (broker `iss` + workspace member) |
| gatk-rs Alpha WES | soft-skip | `./run --gatk-rs` | `results/gatk_rs_wes_result.json` |
| Village Network / Pi edge | manual scripts | see README | not part of main `results/` contract |

## What lives elsewhere (still required for full ecosystem proof)

| Capability | Where |
|------------|--------|
| HELIOS signed evidence | Showcase `make up` / HELIOS stage |
| Evidence Pack / golden path | Showcase `make evidence-pack` / `golden-path` |
| Solum companion | Showcase `make solum-stage` · [Solum-Demo](https://github.com/SynapticFour/Solum-Demo) |
| Consent gate / H2.1 teeth | Showcase `make consent-gate` / `h21-teeth` |
| HelixTest conformance | HelixTest · Ferrum CI |
| htsget / Beacon product depth | Ferrum + HelixTest (not main GIAB path here) |
| Org-IAM / multi-tenant | Product + Showcase pilots — not this Demo |

## CI expectation

| Workflow | What |
|----------|------|
| `ci.yml` | Shell syntax, Python compile, **unittest**, Africa/co-deploy import checks, village compose config |
| CodeQL / secret-scan / dependency-review | Security |

**No Docker stack / no `./run` in default CI.** Live proof is local: `make smoke-evidence` after `./run`. Read `results/RUN_MANIFEST.json`.

## Smoke targets

| Target | Needs | Proves |
|--------|-------|--------|
| `make smoke-syntax` | nothing | Same static checks as CI |
| `make smoke-evidence` | prior `./run` artefacts under `results/` | benchmark + metrics + DRS micro coherent |
| `make smoke-evidence-strict` | prior `--macro` (+ optional `--with-infra`) | also requires `crypt4gh_at_rest` |
