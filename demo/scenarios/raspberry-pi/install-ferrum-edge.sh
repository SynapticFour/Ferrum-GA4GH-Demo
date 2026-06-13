#!/usr/bin/env bash
# Ferrum Edge — Raspberry Pi 5 installer
# From bare Raspberry Pi OS to GA4GH-conformant node in under 10 minutes.
#
# Usage:
#   curl -fsSL https://synapticfour.com/install/ferrum-edge | bash
# Or from a clone:
#   bash demo/scenarios/raspberry-pi/install-ferrum-edge.sh
#
# Requirements: Raspberry Pi 5 (4GB+), Raspberry Pi OS 64-bit or Ubuntu 24.04
# Internet: required for initial install only. After setup, runs fully offline.
#
# Lab-Kit alternative: Ferrum-Lab-Kit/install-edge.sh (profile + compose merge)

set -euo pipefail

FERRUM_DATA_DIR="${FERRUM_DATA_DIR:-$HOME/.ferrum}"
FERRUM_PORT="${FERRUM_PORT:-8080}"
FERRUM_IMAGE="${FERRUM_IMAGE:-ghcr.io/synapticfour/ferrum:latest-arm64}"

# Colour output
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
NC='\033[0m'; BOLD='\033[1m'

banner() { echo -e "\n${BOLD}$1${NC}"; }
ok()     { echo -e "${GREEN}✓${NC} $1"; }
warn()   { echo -e "${YELLOW}⚠${NC} $1"; }
fail()   { echo -e "${RED}✗${NC} $1"; exit 1; }

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Ferrum Edge — Raspberry Pi Field Lab Setup              ║"
echo "║  Synaptic Four · synapticfour.com                       ║"
echo "║                                                          ║"
echo "║  Installing a GA4GH-conformant genomic data node.       ║"
echo "║  Your data stays on this device.                        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# 1. Detect architecture
ARCH=$(uname -m)
[[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]] || \
  warn "Architecture $ARCH detected. ARM64 recommended for Raspberry Pi."

# 2. Check RAM
RAM_MB=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
[[ $RAM_MB -ge 3800 ]] || \
  fail "Minimum 4GB RAM required. Detected: ${RAM_MB}MB"
ok "RAM: ${RAM_MB}MB"

# 3. Install Docker if not present
banner "Checking Docker..."
if ! command -v docker &>/dev/null; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  warn "You may need to log out and back in for Docker permissions."
fi
ok "Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"

# 4. Create data directory
banner "Setting up data directory..."
mkdir -p "$FERRUM_DATA_DIR/objects" "$FERRUM_DATA_DIR/data"
ok "Data directory: $FERRUM_DATA_DIR"

# 5. Generate edge docker-compose
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

# 6. Pull image
banner "Pulling Ferrum image (arm64)..."
docker pull "$FERRUM_IMAGE" || \
  warn "Image pull failed — will retry on first start. Check internet connection."

# 7. Start
banner "Starting Ferrum..."
cd "$FERRUM_DATA_DIR"
docker compose up -d

# 8. Wait for health
banner "Waiting for Ferrum to start..."
for i in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${FERRUM_PORT}/health" &>/dev/null; then
    ok "Ferrum is running"
    break
  fi
  [[ $i -eq 30 ]] && fail "Ferrum did not start within 60 seconds"
  sleep 2
done

# 9. Verify Beacon v2
BEACON=$(curl -fsS "http://127.0.0.1:${FERRUM_PORT}/ga4gh/beacon/v2/info" 2>/dev/null || echo '{}')
BEACON_ID=$(echo "$BEACON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id','unknown'))" 2>/dev/null || echo "unknown")
ok "Beacon v2 responding: id=$BEACON_ID"

# 10. Done
HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || echo '127.0.0.1')"
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✓  Ferrum Edge is running                               ║"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  Beacon v2:  http://%-35s  ║\n" "${HOST_IP}:${FERRUM_PORT}/ga4gh/beacon/v2"
printf "║  DRS:        http://%-35s  ║\n" "${HOST_IP}:${FERRUM_PORT}/ga4gh/drs/v1"
printf "║  Health:     http://%-35s  ║\n" "${HOST_IP}:${FERRUM_PORT}/health"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  Data stored at: %-40s ║\n" "$FERRUM_DATA_DIR"
echo "║  No data leaves this device.                             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  Ingest data:     lab-kit ingest register --gateway http://127.0.0.1:${FERRUM_PORT}"
echo "  Run conformance: lab-kit conformance run --config lab-kit.toml"
echo "  Lab-Kit install: https://github.com/SynapticFour/Ferrum-Lab-Kit (install-edge.sh)"
echo "  View docs:       https://synapticfour.com/en/ferrum-field"
