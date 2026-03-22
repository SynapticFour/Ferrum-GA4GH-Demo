# Prompts for Ferrum (and related repos)

These files are **copy-paste prompts** for maintainers, issues, or AI assistants working on **[Ferrum](https://github.com/SynapticFour/Ferrum)** (and, where noted, **HelixTest** / local lab compose). They consolidate lessons from the **Ferrum-GA4GH-Demo** without keeping long “upstream feedback” sections in `docs/architecture.md`.

| File | Use when |
|------|----------|
| [`ferrum-core-tes-wes.md`](ferrum-core-tes-wes.md) | TES Docker, WES→TES, gateway feature flags, `ferrum-wes` / `ferrum-tes` |
| [`ferrum-helixtest-ci.md`](ferrum-helixtest-ci.md) | noop TES default, CI vs real TES, `ferrum-init` / migrations |
| [`ferrum-lab-kit.md`](ferrum-lab-kit.md) | Local compose, env vars, `host.docker.internal`, parity with GA4GH demo |

**How to use:** open the relevant `.md`, copy the block under “Prompt (copy below)” into Cursor / ChatGPT / a GitHub issue, or commit these files into the Ferrum monorepo under `docs/prompts/` if you prefer a single source of truth there.
