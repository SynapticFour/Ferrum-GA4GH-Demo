# Image pin policy

**Status:** 2026-08-12 · org level-up **C10**
**Repo:** Ferrum-GA4GH-Demo

## Policy

| Context | Rule |
|---------|------|
| **Reproducible benchmark evidence** | Pin Ferrum / ga4gh-infra image versions via env (`FERRUM_IMAGE`, `*_VERSION`) for any run that feeds an Evidence Pack. |
| **CI / developer laptop** | Defaults may use published tags; avoid silent `:latest` drift between “what we showed” and “what CI ran.” |
| **Third-party helpers** | Tools such as `nicolaka/netshoot:latest` are **debug-only** — not part of evidence claims. |

## Current notes

- ga4gh-infra co-deploy compose already defaults infra images to `0.1.0`-class tags via env — keep that pattern.
- Village scenario `FERRUM_IMAGE` defaults to `ghcr.io/synapticfour/ferrum:latest` — override for published evidence runs.

## Review

Monthly: [MONTHLY-DEPENDENCY-HYGIENE](https://github.com/SynapticFour/synapticfour-infra/blob/main/docs/MONTHLY-DEPENDENCY-HYGIENE.md).
