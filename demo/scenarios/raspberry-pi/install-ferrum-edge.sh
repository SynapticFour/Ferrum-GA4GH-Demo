#!/usr/bin/env bash
# Ferrum Edge — Raspberry Pi 5 installer (clone this repo; do not pipe to bash).
#
# Usage (from a clone):
#   FERRUM_IMAGE=ghcr.io/synapticfour/ferrum:<tag-or-digest> \
#     bash demo/scenarios/raspberry-pi/install-ferrum-edge.sh
#
# Requirements: Raspberry Pi 5 (4GB+), Raspberry Pi OS 64-bit or Ubuntu 24.04
# After Docker is present, the node can run without further downloads if the image is already local.
#
# Lab-Kit alternative: Ferrum-Lab-Kit/install-edge.sh (profile + compose merge)

set -euo pipefail

FERRUM_DATA_DIR="${FERRUM_DATA_DIR:-$HOME/.ferrum}"
FERRUM_PORT="${FERRUM_PORT:-8080}"
FERRUM_IMAGE="${FERRUM_IMAGE:-}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
NC='\033[0m'; BOLD='\033[1m'

banner() { echo -e "\n${BOLD}$1${NC}"; }
ok()     { echo -e "${GREEN}ok${NC} $1"; }
warn()   { echo -e "${YELLOW}warn${NC} $1"; }
fail()   { echo -e "${RED}fail${NC} $1"; exit 1; }

if [[ -z "$FERRUM_IMAGE" ]]; then
  fail "Set FERRUM_IMAGE to a pinned tag or digest (not :latest). Example: ghcr.io/synapticfour/ferrum:<sha>"
fi
case "$FERRUM_IMAGE" in
  *:latest|*:latest-arm64|*:latest-amd64)
    if [[ "${FERRUM_ALLOW_LATEST:-0}" != "1" ]]; then
      fail "Refusing :latest. Pin a digest/tag or set FERRUM_ALLOW_LATEST=1 for a throwaway lab."
    fi
    warn "FERRUM_ALLOW_LATEST=1 — image may drift."
    ;;
esac

echo ""
echo "Ferrum Edge — Raspberry Pi field lab setup (Synaptic Four)"
echo "Data directory: $FERRUM_DATA_DIR  image: $FERRUM_IMAGE"
echo "This installer does not certify GA4GH conformance. Run HelixTest against the node."
echo ""

ARCH=$(uname -m)
[[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]] || \
  warn "Architecture $ARCH detected. ARM64 recommended for Raspberry Pi."

RAM_MB=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
[[ $RAM_MB -ge 3800 ]] || \
  fail "Minimum 4GB RAM required. Detected: ${RAM_MB}MB"
ok "RAM: ${RAM_MB}MB"

banner "Checking Docker..."
if ! command -v docker &>/dev/null; then
  fail "Docker is not installed. Install Docker from your OS packages (do not pipe get.docker.com to sh from this script)."
fi
ok "Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"

banner "Setting up data directory..."
mkdir -p "$FERRUM_DATA_DIR/objects" "$FERRUM_DATA_DIR/data"
ok "Data directory: $FERRUM_DATA_DIR"

banner "Generating Ferrum Edge configuration..."
cat > "$FERRUM_DATA_DIR/docker-compose.yml" <<COMPOSE
services:
  ferrum:
    image: "${FERRUM_IMAGE}"
    platform: linux/arm64
    environment:
      FERRUM_AFRICA__OFFLINE_FIRST: "true"
      FERRUM_AFRICA__MAX_MEMORY_MB: "$(( RAM_MB * 3 / 4 ))"
      FERRUM_AFRICA__SQLITE_PATH: "/data/ferrum.db"
      FERRUM_AFRICA__OBJECTS_PATH: "/data/objects"
      FERRUM_AFRICA__POWER_ENABLED: "true"
      FERRUM_MAX_CONCURRENT_REQUESTS: "4"
      FERRUM_BACKGROUND_INDEXING: "false"
    ports:
      - "${FERRUM_PORT}:8080"
    volumes:
      - ./data:/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 12

volumes: {}
COMPOSE
ok "Configuration written to $FERRUM_DATA_DIR/docker-compose.yml"

banner "Pulling Ferrum image..."
docker pull "$FERRUM_IMAGE" || \
  fail "Image pull failed. Check network and that FERRUM_IMAGE exists."

banner "Starting Ferrum..."
cd "$FERRUM_DATA_DIR"
docker compose up -d

banner "Waiting for Ferrum to start..."
for i in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${FERRUM_PORT}/health" &>/dev/null; then
    ok "Ferrum is running"
    break
  fi
  [[ $i -eq 30 ]] && fail "Ferrum did not start within 60 seconds"
  sleep 2
done

BEACON=$(curl -fsS "http://127.0.0.1:${FERRUM_PORT}/ga4gh/beacon/v2/info" 2>/dev/null || echo '{}')
BEACON_ID=$(echo "$BEACON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id','unknown'))" 2>/dev/null || echo "unknown")
ok "Beacon v2 responding: id=$BEACON_ID"

HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || echo '127.0.0.1')"
echo ""
echo "Ferrum Edge is running on ${HOST_IP}:${FERRUM_PORT}"
echo "  Beacon v2:  http://${HOST_IP}:${FERRUM_PORT}/ga4gh/beacon/v2"
echo "  DRS:        http://${HOST_IP}:${FERRUM_PORT}/ga4gh/drs/v1"
echo "  Health:     http://${HOST_IP}:${FERRUM_PORT}/health"
echo "  Data:       $FERRUM_DATA_DIR"
echo ""
echo "This is a local node start, not a conformance certificate."
echo "  Conformance: HelixTest against http://127.0.0.1:${FERRUM_PORT}"
echo "  Lab-Kit:     https://github.com/SynapticFour/Ferrum-Lab-Kit"
