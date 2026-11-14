# Ferrum GA4GH demonstration — documentation index

Every document under `docs/`, grouped as a tutorial, how-to guides, reference, and explanation. One line each. This demonstration does not grow a product architecture. [architecture.md](architecture.md) describes the demo stack.

## Tutorial

| Document | What it is |
|----------|------------|
| [GETTING-STARTED.md](GETTING-STARTED.md) | Docker, the pin, `./run`, and where to read the manifest. |

## How-to guides

| Document | What it is |
|----------|------------|
| [OUTPUTS.md](OUTPUTS.md) | Files a run writes, and which of them to cite. |
| [IMAGE-PIN-POLICY.md](IMAGE-PIN-POLICY.md) | When a floating image tag is refused. |
| [paper/20260322T1331Z/REPRODUCIBILITY.md](paper/20260322T1331Z/REPRODUCIBILITY.md) | How that withdrawn snapshot was produced. |
| [paper/20260322T1331Z/WITHDRAWN.json](paper/20260322T1331Z/WITHDRAWN.json) | Marks that snapshot withdrawn. |
| [paper/20260322T1331Z/benchmark.json](paper/20260322T1331Z/benchmark.json) | Withdrawn benchmark numbers from that snapshot. |
| [paper/20260322T1331Z/benchmark.phase2_plain.json](paper/20260322T1331Z/benchmark.phase2_plain.json) | Plain phase-2 numbers from that snapshot. |
| [paper/20260322T1331Z/benchmark.phase2_crypt4gh.json](paper/20260322T1331Z/benchmark.phase2_crypt4gh.json) | Crypt4GH phase-2 numbers from that snapshot. |
| [paper/20260322T1331Z/dataset_profile.json](paper/20260322T1331Z/dataset_profile.json) | Dataset profile stored with that snapshot. |
| [paper/20260322T1331Z/drs_micro.json](paper/20260322T1331Z/drs_micro.json) | DRS micro timings stored with that snapshot. |
| [paper/20260322T1331Z/engine_compare.json](paper/20260322T1331Z/engine_compare.json) | Engine comparison stored with that snapshot. |
| [paper/20260322T1331Z/interval.txt](paper/20260322T1331Z/interval.txt) | Genomic interval used for that snapshot. |
| [paper/20260322T1331Z/metrics.json](paper/20260322T1331Z/metrics.json) | Metrics stored with that snapshot. |
| [paper/20260322T1331Z/phase2_pass_crypt4gh.json](paper/20260322T1331Z/phase2_pass_crypt4gh.json) | Crypt4GH phase-2 record from that snapshot. |
| [paper/20260322T1331Z/phase2_pass_plain.json](paper/20260322T1331Z/phase2_pass_plain.json) | Plain phase-2 record from that snapshot. |
| [paper/20260322T1331Z/phase2_pass_primary.json](paper/20260322T1331Z/phase2_pass_primary.json) | Primary phase-2 record from that snapshot. |
| [paper/20260322T1331Z/wes_request.json](paper/20260322T1331Z/wes_request.json) | WES request stored with that snapshot. |

## Reference

| Document | What it is |
|----------|------------|
| [CLAIMS.md](CLAIMS.md) | Sentences this demo is allowed to make. |
| [COVERAGE.md](COVERAGE.md) | Which flags run here and which do not. |
| [benchmark.md](benchmark.md) | Pipeline-smoke numbers. Not a GIAB paper. |
| [examples/RUN_MANIFEST.example.json](examples/RUN_MANIFEST.example.json) | Shape of the manifest a run writes. |
| [ECOSYSTEM.md](ECOSYSTEM.md) | This demo beside Ferrum and the other public repositories. |

## Explanation

| Document | What it is |
|----------|------------|
| [WHAT-A-RUN-SHOWS.md](WHAT-A-RUN-SHOWS.md) | What a successful run demonstrates, and what it does not. |
| [FOR-EVALUATORS.md](FOR-EVALUATORS.md) | The deliberate v0.3.2 pin, and how to read a run. |
| [architecture.md](architecture.md) | How the demo containers are wired. |
| [PERSONA.md](PERSONA.md) | Who the walkthrough is written for. |

The pin file is [PINNED_VERSIONS.txt](../PINNED_VERSIONS.txt) at the repository root.

*[← Back to the README](../README.md)*
