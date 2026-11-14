# For evaluators

No public status is recorded for this demonstration. It is a laptop walkthrough of a pinned Ferrum tag, not a product stage of its own.

## What to read after a run

1. `results/RUN_MANIFEST.json`
2. [WHAT-A-RUN-SHOWS.md](WHAT-A-RUN-SHOWS.md)
3. [CLAIMS.md](CLAIMS.md) and [COVERAGE.md](COVERAGE.md)

A green `./run` is pipeline smoke on the pinned tag. It is not a GIAB publication score, not GA4GH certification, and not a clinical pilot. hap.py cells that used truth `--alleles` and showed F1 1.0 are withdrawn.

## Pin

The `./run` pin is Ferrum **v0.3.2**, commit `2bd147c99735866ac9cfb530f62ef984c8efce8b`, in [PINNED_VERSIONS.txt](../PINNED_VERSIONS.txt). That pin is deliberate. Registry: WEB-VERSION-001. The website sentence is this demo pin. It is not the current Ferrum git tag. Ferrum's default branch is newer. The pin is not "current Ferrum is v0.3.2".

## Security of the demo posture

The gateway reaches Docker through docker-socket-proxy. Nested TES tasks may still receive a host `docker.sock` bind. Do not copy this Compose posture to a hospital network. Details stay in the [README](../README.md).

Contact: [contact@synapticfour.com](mailto:contact@synapticfour.com)
