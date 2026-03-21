#!/usr/bin/env bash
# Cromwell's Docker backend shells out to `docker`; broadinstitute/cromwell images ship without the CLI.
# Download a Linux static client (matches amd64 Cromwell by default) and bind-mount it in TES tasks.
set -euo pipefail
ROOT="${1:?repo root}"
OUT="$ROOT/.cache/docker-cli-static/docker"
# Newer Docker daemons reject old clients (e.g. API 1.43); keep this in sync with host Docker.
VER="${DOCKER_STATIC_VERSION:-27.4.1}"
# broadinstitute/cromwell on multi-arch hosts is often pulled as linux/amd64 — CLI must match that OS/arch.
ARCH="${DOCKER_STATIC_ARCH:-x86_64}"
STAMP="$(dirname "$OUT")/docker-cli.version"
mkdir -p "$(dirname "$OUT")"
if [[ -f "$OUT" && -x "$OUT" && -f "$STAMP" && "$(cat "$STAMP")" == "${ARCH}:${VER}" ]]; then
  exit 0
fi
rm -f "$OUT"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
URL="https://download.docker.com/linux/static/stable/${ARCH}/docker-${VER}.tgz"
echo "[docker-cli] fetching static client ${ARCH} ${VER}..."
curl -fsSL "$URL" | tar -xz -C "$tmp"
mv "$tmp/docker/docker" "$OUT"
chmod +x "$OUT"
printf '%s\n' "${ARCH}:${VER}" >"$STAMP"
