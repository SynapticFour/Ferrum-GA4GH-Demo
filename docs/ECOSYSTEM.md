# Synaptic Four — this repo in the portfolio

Four **products**, two free **ambassadors**, Ferrum **companions**, and **proof** repos. Glue is GA4GH; Solum extends into clinical data. **Not a bundle SKU.** Canonical map: [Ferrum PORTFOLIO.md](https://github.com/SynapticFour/Ferrum/blob/main/docs/PORTFOLIO.md).

**You are here:** [Ferrum-GA4GH-Demo](https://github.com/SynapticFour/Ferrum-GA4GH-Demo) — **proof / outreach**, not a product. Local `./run` pipeline smoke. Not a GIAB publication benchmark, not a pilot.

## Repositories

| Kind | Repository | Role | License |
|------|------------|------|---------|
| Proof | **Ferrum-GA4GH-Demo** (this repo) | Laptop pipeline smoke | Apache-2.0 |
| Product | [Ferrum](https://github.com/SynapticFour/Ferrum) | GA4GH data/compute | BUSL-1.1 |
| Product | [ga4gh-infra](https://github.com/SynapticFour/ga4gh-infra) | Identity plane | Apache-2.0 |
| Ambassador | [HelixTest](https://github.com/SynapticFour/HelixTest) | Conformance CLI | Apache-2.0 |
| With Ferrum | [Ferrum-Lab-Kit](https://github.com/SynapticFour/Ferrum-Lab-Kit) | Subset install | BUSL-1.1 |

## Ownership boundaries

| Layer | Owner | Notes |
|-------|--------|--------|
| Identity | **ga4gh-infra** | Broker, visas, DUO, ADS, service registry |
| Data/compute | **Ferrum** | DRS, WES/TES, TRS, Beacon; built-in passports in standalone mode |
| Deployment | **Ferrum-Lab-Kit** | Selective GA4GH surfaces for labs; does not fork Ferrum |
| Demo / pipeline smoke | **Ferrum-GA4GH-Demo** | Tiny-slice DRS·WES·TES + hap.py; optional `--with-infra` |
| Conformance | **HelixTest** | Automated API and workflow tests |

This demo **composes** Ferrum and ga4gh-infra via Docker Compose overlays; it does not implement GA4GH APIs itself. See [docs/architecture.md](architecture.md).

## Default co-deploy ports

| Service | Standalone Ferrum | Co-deploy (demo / lab) |
|---------|-------------------|-------------------------|
| Ferrum gateway | 8080 | **18080** (this demo) |
| AAI broker | — | 8180 |
| Visa registry | — | 8181 |
| DUO | — | 8182 |
| Service registry | — | 8183 |
| ADS | — | 8190 |
| mock-idp | — | 9100 |

## Local lifecycle (unified commands)

Repos that run a **local Docker stack** share the same verbs:

| Verb | Meaning |
|------|---------|
| **up** | Install (if needed) and start |
| **down** | Stop containers; **keep volumes** |
| **destroy** | Stop containers and **remove volumes** |

| Repository | Deploy | Stop | Destroy | Notes |
|------------|--------|------|---------|-------|
| **ga4gh-infra** | `make up` / `just up` | `make down` | `make destroy` | Native binary: [getting-started.md](https://github.com/SynapticFour/ga4gh-infra/blob/main/docs/getting-started.md) |
| **Ferrum** | `make up` / `ferrum demo start` | `make down` | `make destroy` | Laptop: `ferrum demo start --offline` |
| **Ferrum-Lab-Kit** | `make up` | `make down` | `make destroy` | Co-deploy: `make up-with-infra` |
| **Ferrum-GA4GH-Demo** | `make up` / `./run` | `make down` | `make destroy` | Co-deploy: `make up-with-infra` |
| **HelixTest** | — | — | — | Conformance runner (needs a running target) |

**Multi-repo co-deploy** (Ferrum + ga4gh-infra):

```bash
# Benchmark path (Demo)
cd Ferrum-GA4GH-Demo && make up-with-infra
make down        # or make destroy

# Field edge path (Lab Kit)
cd Ferrum-Lab-Kit && make up-with-infra
make down        # or make destroy
```

Secondary options (always available): repo `scripts/stack-*.sh`, raw `docker compose`, and paths documented in each README.

## Quick starts

**Benchmark + co-deploy (this repo):**

```bash
# Defaults: .cache/stack/Ferrum and .cache/stack/ga4gh-infra (siblings).
# Or point at existing checkouts:
export FERRUM_SRC=/path/to/Ferrum
# deprecated alias: FERUM_SRC
export GA4GH_INFRA_SRC=/path/to/ga4gh-infra
./run --with-infra
```

**Field edge + infra (lab):**

```bash
cd Ferrum-Lab-Kit && ./install-edge.sh --with-infra
```

**Conformance:**

```bash
helixtest --all --mode ferrum
helixtest --all --mode ferrum+infra --profile ferrum-infra
```

## Documentation map

| Topic | Document |
|-------|----------|
| Ferrum ↔ ga4gh-infra wiring | [Ferrum GA4GH-INFRA-INTEGRATION.md](https://github.com/SynapticFour/Ferrum/blob/main/docs/GA4GH-INFRA-INTEGRATION.md) |
| Demo compose merge order | [docs/architecture.md](architecture.md) |
| Lab co-deploy profiles | [field-edge+infra.toml](https://github.com/SynapticFour/Ferrum-Lab-Kit/blob/main/config/profiles/field-edge+infra.toml) |
| HelixTest co-deploy mode | [helixtest/docs/ferrum.md](https://github.com/SynapticFour/HelixTest/blob/main/helixtest/docs/ferrum.md) |
| Africa-Mode (SQLite) | [ga4gh-infra AFRICA-DEPLOYMENT](https://github.com/SynapticFour/ga4gh-infra/blob/main/docs/AFRICA-DEPLOYMENT.md) |

## CI

GitHub Actions runs script checks, co-deploy Python compile checks, and compose YAML validation on `main`. Full `./run --with-infra` is validated locally and in Ferrum/HelixTest CI.
