#!/usr/bin/env bash
# Stop or remove the Ferrum GA4GH Demo Docker stack (standalone or co-deploy with ga4gh-infra).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-ferrum-ga4gh-demo}"
REMOVE_VOLUMES=0
HARD=0

usage() {
  cat <<'EOF'
Usage: scripts/stack-down.sh [--volumes] [--hard]

  --volumes   Remove Docker volumes (database, MinIO data, etc.)
  --hard      --volumes plus force-remove leftover containers for this project name

Environment:
  COMPOSE_PROJECT_NAME   Docker Compose project (default: ferrum-ga4gh-demo)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --volumes|-v)
      REMOVE_VOLUMES=1
      shift
      ;;
    --hard)
      HARD=1
      REMOVE_VOLUMES=1
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

down_args=(down --remove-orphans)
if [[ "$REMOVE_VOLUMES" -eq 1 ]]; then
  down_args+=(-v)
fi

# Project name groups all services (Ferrum + optional ga4gh-infra overlays).
if docker compose -p "$COMPOSE_PROJECT_NAME" "${down_args[@]}" 2>/dev/null; then
  :
else
  # Fallback when compose metadata is unavailable but containers remain.
  ids="$(docker ps -aq --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME" 2>/dev/null || true)"
  if [[ -n "$ids" ]]; then
    docker rm -f $ids
  fi
fi

if [[ "$HARD" -eq 1 ]]; then
  for id in $(docker ps -aq --filter "name=${COMPOSE_PROJECT_NAME}" 2>/dev/null || true); do
    docker rm -f "$id" 2>/dev/null || true
  done
fi

if [[ "$REMOVE_VOLUMES" -eq 1 ]]; then
  echo "Ferrum GA4GH Demo stack destroyed (volumes removed)."
else
  echo "Ferrum GA4GH Demo stack stopped (volumes kept). Re-run ./run --no-reset to reuse data."
fi
