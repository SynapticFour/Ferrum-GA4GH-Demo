# Demo Crypt4GH node keypair (non-production)

`node.sec` / `node.pub` are a **Crypt4GH** keypair generated with `crypt4gh-keygen` for local **Ferrum GA4GH Demo** only. They are mounted read-only into `ferrum-gateway` so DRS ingest can use `encrypt=true` (server encrypts with the node public key) and `/objects/{id}/stream` can decrypt at rest with the node private key.

For **benchmarking**: export `FERRUM_GA4GH_CRYPT4GH_PUBKEY` pointing at `node.pub` if you want the optional **`crypt4gh`** leg in `results/drs_micro.json` (HTTP header `X-Crypt4GH-Public-Key`; the micro script strips PEM to one-line base64). **`./run --macro`** compares **plain vs Crypt4GH-at-rest** `ref_fasta` streams (`plain` vs `crypt4gh_at_rest` in the same JSON) using two object ids; see [docs/benchmark.md](../../docs/benchmark.md#publication-friendly-summary).

Do **not** use these keys for production or sensitive data.
