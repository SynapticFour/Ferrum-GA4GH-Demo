# Claims vs evidence

Use this file before citing the demo in a paper, grant, or customer deck.

| Claim you might want | Allowed? | Evidence |
|----------------------|----------|----------|
| Laptop stack ingested files via DRS and ran WES→TES→GATK | Yes, after a successful `./run` | `results/wes_request.json`, `results/metrics.json` `wes_run_id`, `results/query.vcf.gz` |
| hap.py Precision/Recall/F1 on **this slice** | Only if `RUN_MANIFEST.json` `hap_py.cite` is true | Blind caller + labelled dataset. Still not a genome-wide GIAB paper. |
| GIAB / Platinum **publication** concordance | **No** | Slice is tiny; synthetic fallback is labelled; caller no longer gets `--alleles`. Still not a genome-wide GIAB paper. |
| Dockstore GATK germline WDL executed | **No** | `results/trs_fetch.json` `executed: false`. WES runs `workflows/tiny_hc.wdl` / `.nf`. |
| GA4GH conformance | **No** | HelixTest. Village JSON sets `ga4gh_compliant: false`. |
| Two Raspberry Pi village labs / rural 1 Mbit/s WiFi | **No** | Two Docker containers on one host. No netem on the Ferrum path. |
| Africa/field features work | Only if `africa_results.json` `summary.verdict` is `passed` and `ran > 0` | Skip-only is `not_evaluated`, not a pass. `chain_valid: false` is a failure. Postgres `chain_valid` is stock Ferrum **v0.3.1** (microsecond Zulu hash). |
| Co-deploy Passport on DRS | After `./run --with-infra` if `co_deploy_results.json` `verdict` is `passed` | Broker JWT `iss` must match `FERRUM_AUTH__ISSUER` (host `external_url`); JWKS is the Docker-network broker URL. `test-object-1` is workspace-private. |
| Crypt4GH at-rest stream timing | After `./run --macro` | `drs_micro.json` `crypt4gh_at_rest`. Loopback, n=3 default. |
| Production-ready TES/Docker | **No** | Gateway uses docker-socket-proxy (`0.3.0` by digest, `EXEC=0`). Nested TES may still bind host `docker.sock`. Overlay was **removed**; TES workdir is stock Ferrum v0.3.1. |

The artefact to attach to a review is **`results/RUN_MANIFEST.json`**, then the JSON it points at — not the README table alone.
