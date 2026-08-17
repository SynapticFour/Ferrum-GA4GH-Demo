# Demo Crypt4GH node keypair (non-production)

`node.sec` / `node.pub` are **generated locally** by `scripts/ensure-crypt4gh-demo-keys.sh` (`./run` calls it). They are **gitignored**.

They are mounted read-only into `ferrum-gateway` so DRS ingest can use `encrypt=true` and `/objects/{id}/stream` can decrypt at rest.

A private key that was previously committed in this path is **burned**. Do not reuse it. Git history still contains the old blob until an operator runs `git filter-repo` / BFG and force-pushes (not done in suite 2026.08-draft).

For **benchmarking**: export `FERRUM_GA4GH_CRYPT4GH_PUBKEY` pointing at the generated `node.pub`. **`./run --macro`** compares plain vs Crypt4GH-at-rest streams.

Do **not** use these keys for production or sensitive data.
