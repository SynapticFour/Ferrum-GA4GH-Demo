# Engineering Decisions (ADR-lite)

Track important architectural and operational decisions here.

## Template

### YYYY-MM-DD - Decision title

- **Context:** Why this decision was needed.
- **Decision:** What was chosen.
- **Consequences:** Trade-offs, risks, and follow-up actions.

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
