# Security Policy

## Reporting a Vulnerability

Please do **not** open public GitHub issues for security vulnerabilities.

Report vulnerabilities privately to **contact@synapticfour.com** with:
- affected repository and version/commit
- reproduction steps or proof-of-concept
- impact assessment

We will acknowledge receipt as quickly as possible, triage severity, and coordinate a responsible disclosure timeline.

## Scope and Guarantees

This project is a **laptop demo**, not a hospital TES posture. It is maintained on a best-effort basis. No absolute security guarantee is provided.

## Git history — accepted residual risk (2026-08-17)

`demo/fixtures/crypt4gh-node/node.sec` was removed from **HEAD** and is gitignored. Keys are generated at `./run` (`scripts/ensure-crypt4gh-demo-keys.sh`). The previously committed private key is **burned** — do not reuse it.

The old blob **remains in git history** on GitHub. A history rewrite (`git filter-repo` / BFG + force-push) is **not planned**. Treat any historical `node.sec` as public. New clones still get a fresh keypair at `./run`.
