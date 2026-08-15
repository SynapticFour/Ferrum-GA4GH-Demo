# Testing

This repository validates behavior through unit tests, syntax CI, and end-to-end demo execution.

## CI gates

- `.github/workflows/ci.yml` — `bash -n`, `compileall`, **`python3 -m unittest`**, compose config, Africa/co-deploy imports.
- `.github/workflows/codeql.yml` (Python only), `secret-scan.yml`, `dependency-review.yml` (fail-closed).

## Required local verification for behavior changes

1. Static + unit: `make test` and `make smoke-syntax`.
2. Behavioral: `./run` (WDL), and when relevant `./run --nextflow` / `./run --macro` / `./run --africa` / `./run --with-infra`.
3. Evidence gate: `make smoke-evidence` (add `--strict` after `--macro`). Combined optional proof: `./run --macro --africa --with-infra` then `make smoke-evidence-strict`.

Coverage map: [docs/COVERAGE.md](docs/COVERAGE.md). Claim map: [docs/CLAIMS.md](docs/CLAIMS.md).

## Evidence contract

- Skip-only Africa/co-deploy → `summary.verdict = not_evaluated`, `all_passed = false`.
- Default `./run` does not run Africa scenarios; `./run --africa` does, and fails after writing artefacts if `verdict=failed`.
- `./run --with-infra` co-deploy failures likewise write artefacts, then exit 1 at the end (WES still runs).
- `chain_valid: false` → scenario `error`, demo fails if Africa ran.
- Outbreak activate HTTP 401/403 with laptop `demo-user` is **skipped** (no `outbreak_activator` visa), not a pass.
- TRS fetch JSON must have `executed: false`.
- hap.py JSON must have `caller_uses_truth_alleles: false` before `RUN_MANIFEST.json` `hap_py.cite` is true.
- Tests are stdlib `unittest.TestCase` (CI does not install pytest).

## Africa / co-deploy (running stack)

```bash
python3 demo/lib/africa_feature_detect.py http://127.0.0.1:18080
```

Expected when no Africa endpoints exist:

```json
{"ran": 0, "skipped": 6, "errors": 0, "all_passed": false, "verdict": "not_evaluated"}
```

`all_passed: true` is **only** expected when `ran > 0` and `errors == 0`.

HelixTest co-deploy conformance: see HelixTest ferrum+infra mode — not this repo's CI.
