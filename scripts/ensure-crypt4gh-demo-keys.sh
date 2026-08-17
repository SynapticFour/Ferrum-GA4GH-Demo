#!/usr/bin/env bash
# Generate a demo-only Crypt4GH node keypair if missing.
# Never commit node.sec / node.pub. Old committed private keys are burned.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/demo/fixtures/crypt4gh-node"
SEC="$DIR/node.sec"
PUB="$DIR/node.pub"
mkdir -p "$DIR"

if [[ -f "$SEC" && -f "$PUB" ]]; then
  echo "[demo] Crypt4GH demo keys already present under $DIR"
  exit 0
fi

VENV="${FERRUM_GA4GH_C4GH_VENV:-$ROOT/.venv-c4gh}"
if [[ ! -x "$VENV/bin/python" ]]; then
  python3 -m venv "$VENV"
fi
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q 'crypt4gh>=1.6'
"$VENV/bin/python" - "$SEC" "$PUB" <<'PY'
import sys
from pathlib import Path

sec, pub = Path(sys.argv[1]), Path(sys.argv[2])
from crypt4gh.keys.c4gh import generate

generate(str(sec), str(pub), callback=lambda _prompt: b"")
print(f"[demo] wrote {sec} and {pub} (empty passphrase, demo-only)")
PY
chmod 600 "$SEC"
chmod 644 "$PUB"
echo "[demo] Crypt4GH keys are gitignored. Do not copy this keypair to a hospital node."
