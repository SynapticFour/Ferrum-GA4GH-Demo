# Demo Crypt4GH node keypair (non-production)

`node.sec` / `node.pub` are a **Crypt4GH** keypair generated with `crypt4gh-keygen` for local **Ferrum GA4GH Demo** only. They are mounted read-only into `ferrum-gateway` so DRS ingest can use `encrypt=true` (server encrypts with the node public key) and `/objects/{id}/stream` can decrypt at rest with the node private key.

Do **not** use these keys for production or sensitive data.
