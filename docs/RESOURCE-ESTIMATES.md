# Ressourcen-Schätzungen (RAM, HDD, Transfer)

Alle Angaben sind **Großordnungen** für Planung — abhängig von exakten URLs, Kompression, Docker-Images, Cromwell-/GATK-Version und ob Daten bereits lokal liegen. Vor großen Läufen `docker system df` und freien Speicher prüfen.

## Aktueller Demo-Default (GIAB-/Platinum-**Subset** oder synthetisch)

| Ressource | Größenordnung | Anmerkung |
|-----------|---------------|-----------|
| **RAM (Host)** | 8–12 GB | Gateway + Postgres + MinIO + ein Cromwell/GATK-Container; mehr ist stabiler. |
| **HDD/SSD** | ~5–15 GB | Ferrum-Clone-Cache, Images, Subset-Reads/Ref, Compose-Volumes, `results/`, WES-Workdir. |
| **Transfer (einmalig)** | ~1–5 GB | Öffentliche Downloads (Subset); wiederholte Läufe weniger, wenn Cache erhalten bleibt (`FERRUM_GA4GH_RESET_VOLUMES=0`). |

**Phase 2 (`./run --macro`):** ungefähr **doppelte** Pipeline-Zeit und etwas mehr MinIO-Platz (zwei Sätze DRS-Objekte), ein Compose-Stack.

## Geplantes Profil: **volles GIAB** (z. B. HG002 WGS-ähnlich)

Hier ist „voll“ gemeint als **große** öffentliche Referenz + **vollständige** BAM/FASTQ wie typische GIAB-WGS-Pakete — **nicht** der kleine Slice aus dem aktuellen `fetch_giab_subset.sh`.

| Ressource | Größenordnung | Anmerkung |
|-----------|---------------|-----------|
| **RAM (Host)** | 32–64 GB+ | GATK HaplotypeCaller / große BAMs skalieren mit JVM und Parallelität; 64 GB ist für WGS-Komfort oft realistisch. |
| **HDD/SSD** | 200 GB – 1 TB+ | Referenz (3–4 GB gz), BAM(s) oft 50–150 GB+, Indizes, Cromwell-Workdir, Duplikate durch Container-Layer. |
| **Transfer (einmalig)** | 50–200 GB+ | Abhängig vom gewählten GIAB-Paket und Spiegel; Crypt4GH-„Re-Wrap“ ändert **nicht** die Roh-Byte-Menge aus dem Netz, kann aber CPU im Gateway erhöhen. |

## Crypt4GH / DRS (Mess-Logik)

- **Mikro-Benchmark (implementiert):** `scripts/drs_micro_benchmark.py` schreibt `results/drs_micro.json` (Median/P95, optional `X-Crypt4GH-Public-Key` wenn `FERRUM_GA4GH_CRYPT4GH_PUBKEY` gesetzt).
- **Makro (Pipeline):** zusätzliche CPU im Gateway bei Entschlüsselung/Re-Wrap; Netz **innerhalb** Docker (Gateway ↔ MinIO) zählt nicht als „Internet-Transfer“, verursacht aber I/O-Last.

## Umgebungsvariablen (bestehend)

- `FERUM_SRC` / Clone unter `.cache/ferrum` — zusätzlicher Platz für ein **zweites** Ferrum-Working-Copy nur nötig, wenn ihr bewusst getrennt baut.
- `FERRUM_GA4GH_RESET_VOLUMES=0` spart erneutes Seeden, **nicht** die Größe der Rohdaten.

Wenn `./run --giab-full` implementiert ist, sollte die Hilfe auf **konkrete** URLs und erwartete Checksums aus `demo/config.yaml` (oder einem `config-full.yaml`) verweisen.
