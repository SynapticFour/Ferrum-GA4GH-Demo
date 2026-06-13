# Testing

This repository validates behavior through lightweight CI checks plus end-to-end demo execution.

## CI gates

- `.github/workflows/ci.yml`
  - Bash syntax checks for entrypoints and shell scripts.
  - Python bytecode compilation checks for `demo/lib` and `scripts`.
- `.github/workflows/quality-gate.yml`
  - Ensures repository workflow definitions are present.
- `.github/workflows/codeql.yml`, `.github/workflows/secret-scan.yml`, `.github/workflows/dependency-review.yml`
  - Security and dependency policy checks.

## Required local verification for behavior changes

1. Run static checks:
   - `bash -n run`
   - `bash -n demo/run.sh`
   - `bash -n demo/scenarios/village-network/run-village-demo.sh`
   - `bash -n demo/scenarios/raspberry-pi/install-ferrum-edge.sh`
   - `python3 -m compileall -q demo/lib scripts`
2. Run a demo execution:
   - `./run` (WDL path), and when relevant `./run --nextflow`.
   - Optional (needs Ferrum Africa image): `bash demo/scenarios/village-network/run-village-demo.sh`
3. Confirm produced artifacts are coherent:
   - `results/benchmark.json`
   - `results/metrics.json`
   - `results/drs_micro.json`

## DRS expectation in pipeline runs

- Pipeline inputs are ingested via DRS and referenced through DRS-backed URLs.
- WES requests should include an explicit `input_drs_uri` marker for the primary dataset when available, while preserving engine-compatible per-file inputs.

## PR requirement

Any non-trivial behavior change should include verification evidence (CI pass, local commands, or both) or a clear explanation of why execution is not feasible in that environment.

## Africa scenario verification

Africa scenarios run automatically as part of `./run` after the main benchmark.
To verify Africa scenarios specifically:

```bash
# With a running Ferrum instance:
python3 demo/lib/africa_feature_detect.py http://127.0.0.1:18080

# Run scenarios against running instance:
python3 -c "
import sys, json
sys.path.insert(0, 'demo/lib')
from africa_feature_detect import detect
from africa_scenarios import run_all
from pathlib import Path
fs = detect('http://127.0.0.1:18080')
results = run_all('http://127.0.0.1:18080', Path('.'), fs)
print(json.dumps(results['summary'], indent=2))
"
```

Expected output when no Africa features present:

```json
{"ran": 0, "skipped": 6, "errors": 0, "all_passed": true}
```

Expected output when all Africa features present:

```json
{"ran": 6, "skipped": 0, "errors": 0, "all_passed": true}
```

The demo never fails due to Africa feature absence. `all_passed: true` is always expected — errors indicate a real problem with a feature that IS present.

## Co-deploy (Ferrum + ga4gh-infra) verification

Co-deploy scenarios run when `./run --with-infra` is used and ga4gh-infra services
are reachable. Without the flag, `results/co_deploy_results.json` records a skip note.

```bash
# Full demo with co-deploy (clones ga4gh-infra to .cache/ga4gh-infra if needed):
./run --with-infra

# Probe infra only (with stack running):
python3 demo/lib/infra_feature_detect.py

# Run co-deploy scenarios against running Ferrum + infra:
python3 -c "
import sys, json
sys.path.insert(0, 'demo/lib')
from infra_feature_detect import detect
from co_deploy_scenarios import run_all
from pathlib import Path
fs = detect()
results = run_all('http://127.0.0.1:18080', Path('.'), fs)
print(json.dumps(results['summary'], indent=2))
"
```

Expected output when infra is not running:

```json
{"ran": 0, "skipped": 4, "errors": 0, "all_passed": true}
```

Expected output when infra is running and Ferrum co-deploy overlay is active:

```json
{"ran": 4, "skipped": 0, "errors": 0, "all_passed": true}
```

Static checks for co-deploy scripts:

```bash
python3 -m compileall -q demo/lib/infra_feature_detect.py demo/lib/co_deploy_scenarios.py
docker compose -f demo/docker-compose.ga4gh-infra.yml config  # needs GA4GH_INFRA_SRC + FERRUM_GA4GH_DEMO_ROOT
```

HelixTest co-deploy conformance: see [HelixTest ferrum+infra mode](../HelixTest/helixtest/docs/ferrum.md#ferruminfra-co-deploy-mode).
