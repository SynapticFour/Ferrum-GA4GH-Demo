# What a run shows

A successful `./run` shows that the laptop stack can ingest files through DRS, submit a WES run that TES executes with Cromwell or Nextflow and GATK, and write a hap.py JSON for that slice.

The numbers in the README table and in [benchmark.md](benchmark.md) are pipeline smoke. They are not a GIAB publication result. A blind caller on the tiny synthetic interval `22:1700-2300` often has F1 0, because GATK may emit no variants. That is expected, not a Ferrum failure. Rows that used truth `--alleles` and reported F1 1.0 are withdrawn (`paper/20260322T1331Z/WITHDRAWN.json`).

## What a run does not show

- Genome-wide GIAB or Platinum concordance.
- Clinical validity.
- GA4GH conformance. That check is [HelixTest](https://github.com/SynapticFour/HelixTest).
- Africa or field features.
- Execution of the Dockstore GATK germline WDL. The file is fetched, not run.
- A certificate, or a clinical pilot. A green run is a technical signal for the pinned Ferrum tag.

## Pin

[PINNED_VERSIONS.txt](../PINNED_VERSIONS.txt) sets `Ferrum-git` to `2bd147c99735866ac9cfb530f62ef984c8efce8b`, which is Ferrum tag v0.3.2. That pin is deliberate. Registry: WEB-VERSION-001. It is the demo pin. It is not the current Ferrum git tag, and Ferrum's default branch is newer. It is not "current Ferrum is v0.3.2".

The same file pins ga4gh-infra for `./run --with-infra`. That pin is a separate line. It is not the Ferrum pin.
