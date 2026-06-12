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
  The demo needs to test them without breaking the existing EU/GA4GH benchmark.
- **Decision:** Feature detection via HTTP probes after gateway starts. Scenarios
  run only for detected features. Missing features produce `{"skipped": true}`
  entries. The main `./run` invariant is never broken.
- **Consequences:** Demo always works regardless of Ferrum build. Africa coverage
  grows as upstream implements features. No separate demo repository needed.
  The `--africa` flag is optional and additive.

---

### 2026-06-12 - Simulation-first, then real hardware (Village Network)

- **Context:** Field labs in Africa need federated Beacon demos without shipping two Pis to every reviewer; physical Pi installs must stay under 10 minutes.
- **Decision:** Add a **Village Network** Docker simulation (`demo/scenarios/village-network/`) that runs two Ferrum nodes on one laptop, plus a standalone **`install-ferrum-edge.sh`** for Raspberry Pi 5. Ferrum-Lab-Kit **`field-edge`** profile remains the deployment-layer path for labs that want compose merge and `lab-kit init`.
- **Consequences:** Federation/residency features depend on upstream Ferrum Africa prompts; simulation and CI validate scripts/compose syntax before images exist. Video script lives in-repo for HeyGen/Synthesia production.

---

### 2026-04-10 - Establish cross-repo quality and security baseline

- **Context:** Repositories had uneven governance and CI security posture.
- **Decision:** Standardize governance docs, quality gates, and security scanning workflows.
- **Consequences:** Better consistency and contributor trust; ongoing maintenance required to keep checks aligned with stack changes.
