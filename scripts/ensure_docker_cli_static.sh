#!/usr/bin/env bash
# Cromwell's Docker backend shells out to `docker`; broadinstitute/cromwell images ship without the CLI.
# Download a Linux static client and verify it against Docker's SHA256SUMS on the same origin.
set -euo pipefail
ROOT="${1:?repo root}"
OUT="$ROOT/.cache/docker-cli-static/docker"
VER="${DOCKER_STATIC_VERSION:-27.4.1}"
ARCH="${DOCKER_STATIC_ARCH:-x86_64}"
STAMP="$(dirname "$OUT")/docker-cli.version"
PINNED_SHA="$(awk -F= -v k="Docker-cli-sha256-${ARCH}" '$0 ~ "^"k"=" {print $2; exit}' "$ROOT/PINNED_VERSIONS.txt" 2>/dev/null || true)"
PINNED_SHA="${PINNED_SHA// /}"
mkdir -p "$(dirname "$OUT")"
if [[ -f "$OUT" && -x "$OUT" && -f "$STAMP" && "$(cat "$STAMP")" == "${ARCH}:${VER}" ]]; then
  exit 0
fi
rm -f "$OUT"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
BASE="https://download.docker.com/linux/static/stable/${ARCH}"
TGZ="$tmp/docker-${VER}.tgz"
echo "[docker-cli] fetching static client ${ARCH} ${VER}..."
curl -fsSL -o "$TGZ" "${BASE}/docker-${VER}.tgz"
curl -fsSL -o "$tmp/SHA256SUMS" "${BASE}/SHA256SUMS"
python3 - "$TGZ" "$tmp/SHA256SUMS" "$PINNED_SHA" <<'PY'
import hashlib, pathlib, sys
tgz = pathlib.Path(sys.argv[1])
sums = pathlib.Path(sys.argv[2])
pinned = sys.argv[3].strip()
got = hashlib.sha256(tgz.read_bytes()).hexdigest()
expect = None
for line in sums.read_text(encoding="utf-8").splitlines():
    parts = line.split()
    if len(parts) >= 2 and parts[-1].lstrip("*") == tgz.name:
        expect = parts[0]
        break
if expect is None:
    raise SystemExit(f"no SHA256SUMS entry for {tgz.name}")
if got != expect:
    raise SystemExit(f"SHA256SUMS mismatch: {got} != {expect}")
if pinned and got != pinned:
    raise SystemExit(f"pinned SHA mismatch: {got} != {pinned}")
print(f"[docker-cli] sha256 ok {got}")
PY
tar -xz -C "$tmp" -f "$TGZ"
mv "$tmp/docker/docker" "$OUT"
chmod +x "$OUT"
printf '%s\n' "${ARCH}:${VER}" >"$STAMP"
