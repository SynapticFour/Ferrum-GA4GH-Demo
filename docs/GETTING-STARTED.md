# Getting started

**Prerequisites:** Docker (~8 GB RAM, ~20 GB disk), `git`, `python3`, `curl`, `bash`, network (clone Ferrum, images, public data). Sizing: [architecture.md](architecture.md).

```bash
make up
# or: ./run
```

Requires a **pinned** Ferrum git SHA in [PINNED_VERSIONS.txt](../PINNED_VERSIONS.txt) (**v0.3.2**). Override only with `FERRUM_GA4GH_ALLOW_UNPINNED=1`. Checkout env: `FERRUM_SRC` (default `.cache/stack/Ferrum`).

Co-deploy Ferrum + ga4gh-infra:

```bash
make up-with-infra
# or: ./run --with-infra
```

Stop: `make down`. Remove volumes: `make destroy`. Default `./run` resets volumes unless `--no-reset`.

After the run: `make smoke-evidence` (or `make smoke-evidence-strict` after `--macro`). Read `results/RUN_MANIFEST.json` first.

`--giab-full` is not implemented (exit 3). Flag list: `./run --help`. Coverage: [COVERAGE.md](COVERAGE.md).
