# Image pin policy

**Status:** 2026-08-15 · org level-up **C10**
**Repo:** Ferrum-GA4GH-Demo

## Policy

| Context | Rule |
|---------|------|
| **Pipeline-smoke evidence you keep** | Pin Ferrum git (`Ferrum-git=`, currently **v0.3.1**), ga4gh-infra git (`GA4GH-INFRA-git=`), and executor tags in `PINNED_VERSIONS.txt`. Village / Pi require `FERRUM_IMAGE` (digest preferred). |
| **CI / developer laptop** | Syntax CI does not pull Ferrum images. Do not use `:latest` on any path that feeds `results/`. |
| **Alpha / debug** | `gatk-rs` is not the evidence path. `:latest` is refused unless `FERRUM_GA4GH_ALLOW_LATEST=1`. Tools such as `nicolaka/netshoot:latest` are debug-only. |

## Current notes

- Default clone path is `.cache/stack/Ferrum` (named `Ferrum` so `--with-infra` monorepo `COPY Ferrum/` works).
- `./run --with-infra` clones ga4gh-infra at `GA4GH-INFRA-git=` (hard-fail if empty unless `FERRUM_GA4GH_ALLOW_UNPINNED=1`) and runs `scripts/prepare-docker-vendor.sh` (`docker/vendor` is gitignored).
- Village and Pi installers refuse `:latest`.
- hap.py image is built locally (`ferrum-ga4gh-happy:local`), not pulled from a registry `:latest`.

## Review

Monthly: [MONTHLY-DEPENDENCY-HYGIENE](https://github.com/SynapticFour/synapticfour-infra/blob/main/docs/MONTHLY-DEPENDENCY-HYGIENE.md).
