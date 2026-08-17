# Persona — institute GA4GH pipeline smoke

**Who this demo is for:** an institute platform team that wants to see Ferrum DRS → WES → TES on a laptop, with hap.py on a **tiny** slice.

This is not a hospital evaluation, not HelixTest conformance, and not a GIAB paper. After every `./run`, read `results/RUN_MANIFEST.json` first. Claim map: [CLAIMS.md](CLAIMS.md). Coverage: [COVERAGE.md](COVERAGE.md).

## One command they should run

```bash
./run
# or: make up
make smoke-evidence
```

Pin: Ferrum **v0.3.2** in [`PINNED_VERSIONS.txt`](../PINNED_VERSIONS.txt). Co-deploy Passports: `./run --with-infra` (needs sibling `ga4gh-infra`).

## What ran vs what did not (honest sheet)

| Question they will ask | Allowed after a successful `./run`? | Evidence |
|------------------------|-------------------------------------|----------|
| Did DRS ingest and WES→TES→GATK run on this slice? | Yes | `wes_request.json`, `metrics.json` `wes_run_id`, `query.vcf.gz` |
| hap.py Precision/Recall/F1 for **this slice** | Only if `RUN_MANIFEST.json` `hap_py.cite` is true | `benchmark.json` — still not genome-wide GIAB |
| Dockstore GATK germline WDL executed? | **No** | `trs_fetch.json` `executed: false` |
| GA4GH conformance? | **No** | That is [HelixTest](https://github.com/SynapticFour/HelixTest) |
| Two Raspberry Pi village labs / field WiFi? | **No** | Two Docker containers on one host |
| Africa / residency features? | Only if `africa_results.json` `summary.verdict` is `passed` and `ran > 0` | Skip-only is `not_evaluated` |
| Passport on DRS? | After `./run --with-infra` if `co_deploy_results.json` `verdict` is `passed` | Broker `iss` must match Ferrum issuer |
| Production-ready TES/Docker? | **No** | docker-socket-proxy on the gateway; nested TES may still bind host `docker.sock` |

Default CI here is syntax + unit tests. **No Docker stack in GitHub Actions.** Live proof is local.

## Where the other personas go

| Persona | Repo |
|---------|------|
| Clinic / consent / audit | [Solum-Demo PERSONA](https://github.com/SynapticFour/Solum-Demo/blob/main/docs/PERSONA.md) |
| Composition (Ferrum + Solum + HELIOS) | [Showcase persona-evidence](https://github.com/SynapticFour/SynapticFour-Showcase/blob/main/docs/for-customers/persona-evidence.md) |
| Conformance runner | HelixTest `make prove` (offline) / `helixtest --mode ferrum` (live) |
