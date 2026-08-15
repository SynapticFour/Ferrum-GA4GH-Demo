# Releasing

This repository has **no Git tags yet**. Version a demo run by:

- git SHA of this repo
- `Ferrum-git=` in [PINNED_VERSIONS.txt](PINNED_VERSIONS.txt)
- `results/RUN_MANIFEST.json` from that run

When you cut the first release:

1. CI green on `main` (`unittest` included).
2. `CHANGELOG.md` updated.
3. Annotated tag `vX.Y.Z` and `git push origin vX.Y.Z`.
4. Do not call hap.py F1 a GIAB publication result in release notes.

Until then, ignore Semantic Versioning language in older copies of this file.
