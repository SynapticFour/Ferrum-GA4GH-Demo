# Engineering Decisions (ADR-lite)

Track important architectural and operational decisions here.

## Template

### YYYY-MM-DD - Decision title

- **Context:** Why this decision was needed.
- **Decision:** What was chosen.
- **Consequences:** Trade-offs, risks, and follow-up actions.

---

### 2026-06-03 - Africa feature integration strategy: detect-and-degrade

- **Context:** Ferrum Africa features are implemented progressively upstream.
  The demo needs to test them without breaking the existing EU/GA4GH pipeline smoke.
- **Decision:** Feature detection via HTTP probes after gateway starts. Scenarios
  run only for detected features. Missing features produce `{"skipped": true}`
  entries. The main `./run` invariant is never broken.
- **Consequences:** Demo always works regardless of Ferrum build. Africa coverage
  grows as upstream implements features. No separate demo repository needed.
  The `--africa` flag is optional and additive. Skip-only Africa results use
  `summary.verdict = not_evaluated` (`all_passed: false`). Invalid
  `chain_valid` is a failure, not a verified residency proof.

---

### 2026-08-15 - Honesty contract for customers and research-data users

- **Context:** Due diligence found hap.py F1=1.0 with `--alleles` on a synthetic
  slice sold as GIAB; skip-only Africa marked `all_passed`; WES poll delay for
  HelixTest; `:latest` and `curl|bash` installers; HTTP serving the repo root.
- **Decision:** The demo is a **pipeline smoke**. Caller is blind to truth VCF.
  Skip is `not_evaluated`. Invalid audit chains fail. Village never sets
  `ga4gh_compliant: true`. Pins are hard-fail. Overlay SPDX/NOTICE. Artefact of
  record is `results/RUN_MANIFEST.json`. Committed F1=1.0 paper JSON is labelled
  `claim_withdrawn`.
- **Consequences:** Customers and data-governance reviewers can use the repo
  without citing fake concordance. A full `./run` is still required before
  quoting new hap.py numbers. Overlay remains BUSL-1.1 inside an Apache tree.

---

### 2026-08-16 - Pin Ferrum v0.3.1; retire overlay

- **Context:** Honesty fixes (TES poll, residency microsecond Zulu) landed on Ferrum main and shipped as **v0.3.1**.
- **Decision:** Pin `Ferrum-git` to `f28f2780…`. Stop rsync. Delete `vendor/ferrum-overlay`.
- **Consequences:** `./run` proves tagged Ferrum. Stale `.cache/stack/Ferrum` patches are `git checkout`'d away. Frozen paper snapshot `docs/paper/20260322T1331Z/` still mentions the old overlay path — do not rewrite it.

---

### 2026-08-15 - Pin Ferrum v0.3.0; overlay residency hash; co-deploy issuer + workspace

- **Context:** Ferrum v0.3.0 is the coordinated stack cut. Stock WES still had a
  HelixTest poll delay (stripped in overlay). Postgres residency `chain_valid`
  was false because `to_rfc3339()` did not round-trip `timestamptz`. Co-deploy
  broker JWT `iss` is the host `external_url`; `test-object-1` is workspace-private;
  ga4gh-infra Dockerfiles `COPY docker/vendor` which is gitignored.
- **Decision:** Pin `Ferrum-git` to the v0.3.0 **commit** (not the annotated tag
  object). Default checkout `.cache/stack/Ferrum` + sibling `ga4gh-infra`. Overlay
  keeps 0.3 workdir logs, drops the poll delay, and hashes residency timestamps at
  microsecond Zulu. Co-deploy sets `FERRUM_AUTH__ISSUER` to `http://127.0.0.1:8180`
  and JWKS to `http://aai-broker:8080/jwks.json`; scenarios add the mock-idp subject
  as a workspace viewer; `prepare-docker-vendor.sh` runs before compose.
- **Consequences:** `./run --macro --africa --with-infra` is the local optional
  proof. Outbreak activate without `outbreak_activator` stays skipped. Stock Ferrum
  without the overlay still reports `chain_valid: false` on Postgres.

---

### 2026-06-12 - Simulation-first, then real hardware (Village Network)

- **Context:** Field labs in Africa need federated Beacon demos without shipping two Pis to every reviewer; physical Pi installs must stay under 10 minutes.
- **Decision:** Add a **Village Network** Docker simulation (`demo/scenarios/village-network/`) that runs two Ferrum nodes on one laptop, plus a standalone **`install-ferrum-edge.sh`** for Raspberry Pi 5. Ferrum-Lab-Kit **`field-edge`** profile remains the deployment-layer path for labs that want compose merge and `lab-kit init`.
- **Consequences:** Federation/residency features depend on upstream Ferrum. Simulation and CI validate scripts/compose syntax and unit tests. Do not claim Raspberry Pi or rural WiFi from the laptop compose file.

---

### 2026-04-10 - Establish cross-repo quality and security baseline

- **Context:** Repositories had uneven governance and CI security posture.
- **Decision:** Standardize governance docs, quality gates, and security scanning workflows.
- **Consequences:** Better consistency and contributor trust; ongoing maintenance required to keep checks aligned with stack changes.
