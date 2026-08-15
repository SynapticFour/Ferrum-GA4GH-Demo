# What `./run` produces

All live outputs land under `results/` (gitignored). Committed snapshots under `docs/paper/` are historical; they may predate the blind-caller change.

**Reading order for a reviewer or data-governance person:**

1. `results/RUN_MANIFEST.json` — what this run is / is not; `hap_py.cite`; Africa/co-deploy `verdict`.
2. The JSON files the manifest points at (`benchmark.json`, `metrics.json`, `trs_fetch.json`, …).
3. `query.vcf.gz` only as the GATK product of **this** slice, not as a clinical callset.

Schema without a live run: [docs/examples/RUN_MANIFEST.example.json](examples/RUN_MANIFEST.example.json). Claim map: [CLAIMS.md](CLAIMS.md).

| Artefact | Meaning |
|----------|---------|
| **`RUN_MANIFEST.json`** | Read this first. Scope, dataset kind, hap.py `cite` flag, TRS `executed: false`, Africa/co-deploy verdicts, overlay note. Schema sample: [docs/examples/RUN_MANIFEST.example.json](examples/RUN_MANIFEST.example.json). |
| `benchmark.json` | hap.py precision/recall/F1 for **this slice**. Includes `caller_uses_truth_alleles: false`, `claim_scope: pipeline_smoke`, relative `summary_source`. |
| `metrics.json` | Wall time, WES run id, engine, DRS micro pointer, Africa/co-deploy summaries. |
| `query.vcf.gz` | GATK output copied from the TES workdir. |
| `drs_micro.json` | Loopback `/stream` timings (`plain`, optional `crypt4gh_at_rest`). n=3 default. |
| `dataset_profile.json` | On-disk sizes; `synthetic_subset: true` when the GIAB fetch fell back. |
| `trs_fetch.json` | Dockstore descriptor fetch. `executed: false`. |
| `wes_request.json` | Body POSTed to WES. |
| `drs/mapping.json` | DRS object ids (repo `drs/`, not gitignored). |
| `africa_results.json` | `summary.verdict`: `passed` \| `failed` \| `not_evaluated`. |
| `co_deploy_results.json` | Same verdict contract. |
| `village-network-demo.json` | Only after the village script. `ga4gh_compliant` is always false. |
| `docs/benchmark.md` + README table | Regenerated from the JSON above. hap.py cells are redacted if `caller_uses_truth_alleles` is not `false`. |

hap.py also writes `results/happy.*` (summary/extended). Those are engine dumps; cite `benchmark.json`.

**Withdrawn:** committed paper snapshot `docs/paper/20260322T1331Z/` (hap.py F1=1.0 with `--alleles`). Do not cite those precision/recall/F1 values. Timing rows there are loopback-only. Re-run `./run` on this tree.
