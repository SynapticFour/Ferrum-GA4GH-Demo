# Ferrum Edge — Video Script
# Duration: ~3 minutes | Format: avatar presenter + screen recording overlay
# Languages: DE (primary) / EN / FR (auto-translated via HeyGen/Synthesia)
# Production: HeyGen Creator ($24/mo) — one month subscription, 3 languages

---

## SCENE 1 — THE PROBLEM (0:00–0:35)
*Visual: Map of Africa with dots appearing at research labs*

"In 2025, 46 African countries gained the ability to sequence genomes locally.
That is remarkable progress. The challenge that followed: how do you share
that data with international partners — safely, and without sending sensitive
samples abroad?"

"The answer, until now, required servers, cloud subscriptions, and IT teams
that most field labs simply don't have."

---

## SCENE 2 — THE SOLUTION (0:35–1:10)
*Visual: Raspberry Pi 5 on a lab bench. Terminal opening.*

"Ferrum Edge changes that. One command. One device. A fully GA4GH-conformant
genomic data node — running on a Raspberry Pi that costs ninety dollars."

[SCREEN: `bash install-ferrum-edge.sh` running, progress bar, then:]
[SCREEN: `✓ Beacon v2 responding`]

"In under ten minutes, this device becomes a Beacon v2 node — the same
standard used by Genomics England, the European Genomic Data Infrastructure,
and Africa CDC."

---

## SCENE 3 — THE VILLAGE NETWORK (1:10–1:55)
*Visual: Two Raspberry Pis on a table connected by a simple WiFi router*

"Now imagine two labs. Kisumu, Kenya — sequencing malaria samples.
Nouna, Burkina Faso — sequencing tuberculosis isolates."

"Each device holds its own data. Neither sends anything to the cloud.
But when a researcher in Berlin asks: 'Does anyone have matched Plasmodium
and TB data?' — both labs answer. Yes or no. No raw data transferred."

[SCREEN: Terminal showing federated Beacon query returning results from both nodes]
[SCREEN: `data_left_node: false` in the audit log]

"The data never left either lab. The audit log proves it — cryptographically."

---

## SCENE 4 — GA4GH COMPLIANCE (1:55–2:25)
*Visual: HelixTest running, green checkmarks*

"This is not a workaround or a simplified version. Ferrum Edge passes the
same GA4GH conformance suite as institutional deployments with full server
infrastructure."

[SCREEN: HelixTest output — all tests passing]

"Beacon v2. DRS. Crypt4GH encryption. Passport-based access control.
All of it. On a Raspberry Pi."

---

## SCENE 5 — THE CALL TO ACTION (2:25–3:00)
*Visual: synapticfour.com/en/ferrum-edge on screen*

"If your lab sequences data locally and needs to participate in international
research networks — without sending your data abroad — Ferrum Edge is built
for you."

"We are looking for first pilot partners: NPHIs, field labs, university
bioinformatics units. The software is open source. The pilot is free."

"One device. Ninety dollars. Global GA4GH interoperability."

*[End card: synapticfour.com/en/ferrum-africa · contact@synapticfour.com]*

---

## PRODUCTION NOTES FOR HEYGEN
- Avatar: choose a professional, neutral avatar (not a specific ethnicity)
- Background: clean lab setting or neutral dark background
- Screen overlays: use Picture-in-Picture for terminal recordings
- Translation: use HeyGen's one-click translation for EN→FR and EN→DE
- Custom avatar: optional ($99 one-time) — only if you want your own face
- Export: 1080p, MP4, no watermark (requires Creator plan at minimum)
- Estimated production time: 2–3 hours for all three language versions

## SCREEN RECORDING CHECKLIST
| Scene | Command / asset |
|-------|-----------------|
| 2 | `demo/scenarios/raspberry-pi/install-ferrum-edge.sh` or `Ferrum-Lab-Kit/install-edge.sh` |
| 3 | `demo/scenarios/village-network/run-village-demo.sh` (laptop simulation) |
| 4 | `lab-kit conformance run` + HelixTest green output |

## DE / FR TRANSLATION HINTS
- Keep "GA4GH", "Beacon v2", "DRS", "HelixTest" as proper nouns (do not translate)
- "Raspberry Pi" stays in English in DE/FR technical contexts
- Translate "field lab" → DE: *Feldlabor*, FR: *laboratoire de terrain*
