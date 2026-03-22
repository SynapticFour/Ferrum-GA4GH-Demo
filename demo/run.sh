#!/usr/bin/env bash
# One-command GA4GH demo: Ferrum (TRS+DRS+WES+TES) + GIAB subset + Dockstore cache + hap.py benchmark + doc refresh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export FERRUM_GA4GH_DEMO_ROOT="$ROOT"

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-ferrum-ga4gh-demo}"
export FERUM_WES_WORK_HOST="${FERUM_WES_WORK_HOST:-$ROOT/results/wes-work}"
# Official nextflow/nextflow images are amd64-only; without this, arm64 hosts fail to create the TES container.
case "$(uname -m)" in
  arm64 | aarch64)
    export FERRUM_TES_DOCKER_PLATFORM="${FERRUM_TES_DOCKER_PLATFORM:-linux/amd64}"
    ;;
esac
export FERRUM_TES_DOCKER_NETWORK="${COMPOSE_PROJECT_NAME}_default"
# Default host ports avoid clashing with an existing local :8080 / :8082.
export GATEWAY_PORT="${GATEWAY_PORT:-18080}"
export UI_PORT="${UI_PORT:-18082}"
pick_free_port() {
  python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("", 0))
print(s.getsockname()[1])
s.close()
PY
}
export STATIC_PORT="${STATIC_PORT:-$(pick_free_port)}"
GATEWAY="http://127.0.0.1:${GATEWAY_PORT}"
export FERRUM_GA4GH_ENGINE="${FERRUM_GA4GH_ENGINE:-wdl}"

TS_START="$(date +%s)"
mkdir -p "$FERUM_WES_WORK_HOST" "$ROOT/results" "$ROOT/workflows/cached" "$ROOT/data" "$ROOT/drs"

command -v docker >/dev/null || { echo "docker required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 required" >&2; exit 1; }
command -v curl >/dev/null || { echo "curl required (for static docker CLI in TES/Cromwell)" >&2; exit 1; }

echo "[demo] ensuring Linux docker CLI for Cromwell/Nextflow-in-TES (nested docker runs)..."
chmod +x "$ROOT/scripts/ensure_docker_cli_static.sh"
bash "$ROOT/scripts/ensure_docker_cli_static.sh" "$ROOT"
DOCKER_CLI_HOST="$ROOT/.cache/docker-cli-static/docker"
export FERRUM_TES_EXTRA_BINDS="/var/run/docker.sock:/var/run/docker.sock,${DOCKER_CLI_HOST}:/usr/local/bin/docker:ro"

FERUM_SRC="${FERUM_SRC:-$ROOT/.cache/ferrum}"
if [[ ! -d "$FERUM_SRC/.git" ]]; then
  echo "[demo] cloning Ferrum into $FERUM_SRC ..."
  mkdir -p "$(dirname "$FERUM_SRC")"
  git clone --depth 1 https://github.com/SynapticFour/Ferrum.git "$FERUM_SRC"
fi

echo "[demo] applying GA4GH demo overlay to Ferrum sources..."
rsync -a "$ROOT/vendor/ferrum-overlay/" "$FERUM_SRC/"
# Overlay no longer ships ferrum-drs repo.rs (upstream fixed access_url); reset if a prior rsync left a stale file.
if [[ -d "$FERUM_SRC/.git" ]]; then
  git -C "$FERUM_SRC" checkout HEAD -- crates/ferrum-drs/src/repo.rs 2>/dev/null || true
fi

echo "[demo] fetching GIAB / Platinum subset (falls back to synthetic on failure)..."
set +e
bash "$ROOT/scripts/fetch_giab_subset.sh"
FETCH_RV=$?
set -e
if [[ "$FETCH_RV" -ne 0 ]]; then
  echo "[demo] public data fetch failed (rv=$FETCH_RV); generating synthetic GIAB-style subset..."
  chmod +x "$ROOT/scripts/gen_synthetic_giab_subset.sh"
  bash "$ROOT/scripts/gen_synthetic_giab_subset.sh"
fi
# Interval must match the data actually on disk (fetch may skip steps if files exist).
if [[ -f "$ROOT/data/synthetic_manifest.txt" ]]; then
  echo "22:1700-2300" > "$ROOT/results/interval.txt"
else
  echo "22:16050000-16080000" > "$ROOT/results/interval.txt"
fi

echo "[demo] caching Dockstore TRS descriptor (GATK germline WDL)..."
bash "$ROOT/scripts/fetch_dockstore_trs.sh" "$ROOT/workflows/cached"

# Serve WDL over HTTP so Cromwell inside TES can fetch it via host.docker.internal.
STATIC_PID=""
cleanup() {
  if [[ -n "$STATIC_PID" ]] && kill -0 "$STATIC_PID" 2>/dev/null; then
    kill "$STATIC_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT
( cd "$ROOT" && python3 -m http.server "$STATIC_PORT" --bind 0.0.0.0 ) &
STATIC_PID=$!
sleep 1

if [[ "${FERRUM_GA4GH_ENGINE}" == "nextflow" ]]; then
  WORKFLOW_URL="http://host.docker.internal:${STATIC_PORT}/workflows/tiny_hc.nf"
  PARAMS_JSON="$ROOT/demo/nf_params.json"
  echo "[demo] engine=nextflow workflow=$WORKFLOW_URL"
else
  WORKFLOW_URL="http://host.docker.internal:${STATIC_PORT}/workflows/tiny_hc.wdl"
  PARAMS_JSON="$ROOT/demo/inputs.json"
  echo "[demo] engine=wdl workflow=$WORKFLOW_URL"
fi

echo "[demo] building & starting Ferrum stack (docker compose)..."
(
  cd "$FERUM_SRC/deploy"
  # Fresh Postgres/MinIO volumes avoid half-applied migrations when re-running the demo.
  if [[ "${FERRUM_GA4GH_RESET_VOLUMES:-1}" == "1" ]]; then
    docker compose -p "$COMPOSE_PROJECT_NAME" \
      -f docker-compose.yml \
      -f "$ROOT/demo/docker-compose.ga4gh.yml" \
      down -v --remove-orphans 2>/dev/null || true
  fi
  docker compose -p "$COMPOSE_PROJECT_NAME" \
    -f docker-compose.yml \
    -f "$ROOT/demo/docker-compose.ga4gh.yml" \
    up -d --build
)

echo "[demo] pre-pull workflow images (best-effort; skip if offline)..."
docker pull broadinstitute/cromwell:93-0232cbd >/dev/null 2>&1 || true
docker pull broadinstitute/gatk:4.4.0.0 >/dev/null 2>&1 || true
NEXTFLOW_IMAGE="nextflow/nextflow:24.10.3"
if [[ "${FERRUM_GA4GH_ENGINE}" == "nextflow" ]]; then
  case "$(uname -m)" in
    arm64 | aarch64)
      docker pull --platform linux/amd64 "$NEXTFLOW_IMAGE" >/dev/null 2>&1 || true
      ;;
    *)
      docker pull "$NEXTFLOW_IMAGE" >/dev/null 2>&1 || true
      ;;
  esac
fi

echo "[demo] waiting for gateway..."
for _ in $(seq 1 90); do
  if curl -fsS "$GATEWAY/health" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
curl -fsS "$GATEWAY/health" >/dev/null

chmod +x "$ROOT/demo/lib/compose_metrics.py" "$ROOT/demo/lib/record_pass_snapshot.py" \
  "$ROOT/demo/lib/update_engine_compare.py" "$ROOT/scripts/dataset_profile.py"

# One pass: ingest → DRS micro → WES → hap.py; wall time includes hap.py.
pipeline_pass() {
  local pass_label="$1"
  local enc_flag="$2"
  export FERRUM_GA4GH_ENCRYPT_INGEST="$enc_flag"
  echo "[demo] ---------- pass: ${pass_label} (encrypt_ingest=${enc_flag}) ----------"
  local T0 T1
  T0="$(date +%s)"

  echo "[demo] DRS ingest + workflow inputs..."
  INTERVAL="$(cat "$ROOT/results/interval.txt")"
  python3 "$ROOT/demo/lib/ingest_and_inputs.py" \
    "$GATEWAY" \
    "$ROOT/data" \
    "$ROOT/drs/mapping.json" \
    "$ROOT/demo/inputs.json" \
    "$INTERVAL"

  echo "[demo] DRS stream micro-benchmark (plain + optional Crypt4GH header)..."
  chmod +x "$ROOT/scripts/drs_micro_benchmark.py"
  REF_OID="$(python3 -c "import json; print(json.load(open('$ROOT/drs/mapping.json'))['objects']['ref_fasta']['object_id'])")"
  DRS_MICRO_ARGS=(python3 "$ROOT/scripts/drs_micro_benchmark.py" "$GATEWAY" "$REF_OID" -o "$ROOT/results/drs_micro.json")
  if [[ -n "${FERRUM_GA4GH_CRYPT4GH_PUBKEY:-}" && -f "${FERRUM_GA4GH_CRYPT4GH_PUBKEY}" ]]; then
    DRS_MICRO_ARGS+=(--crypt4gh-pubkey "${FERRUM_GA4GH_CRYPT4GH_PUBKEY}")
  fi
  "${DRS_MICRO_ARGS[@]}"

  WES_PAYLOAD="$ROOT/results/wes_request.json"
  export FERRUM_GA4GH_ENGINE
  python3 "$ROOT/demo/lib/build_wes_payload.py" "$WORKFLOW_URL" "$PARAMS_JSON" "$WES_PAYLOAD"

  echo "[demo] WES submit..."
  SUBMIT="$(curl -fsS -X POST "$GATEWAY/ga4gh/wes/v1/runs" \
    -H 'Content-Type: application/json' \
    -d @"$WES_PAYLOAD")"
  RUN_ID="$(python3 -c "import json,sys; print(json.load(sys.stdin)['run_id'])" <<<"$SUBMIT")"
  echo "[demo] run_id=$RUN_ID"

  echo "[demo] polling WES..."
  STATE=""
  for _ in $(seq 1 360); do
    ST="$(curl -fsS "$GATEWAY/ga4gh/wes/v1/runs/${RUN_ID}/status")"
    STATE="$(python3 -c "import json,sys; print(json.load(sys.stdin)['state'])" <<<"$ST")"
    echo "  state=$STATE"
    if [[ "$STATE" == "COMPLETE" ]]; then
      break
    fi
    if [[ "$STATE" == "EXECUTOR_ERROR" || "$STATE" == "SYSTEM_ERROR" || "$STATE" == "CANCELED" ]]; then
      echo "$ST" >&2
      exit 1
    fi
    sleep 5
  done
  [[ "$STATE" == "COMPLETE" ]] || { echo "WES did not complete: $STATE" >&2; exit 1; }

  QUERY_VCF="$(find "$FERUM_WES_WORK_HOST/$RUN_ID" -type f \( -name 'output.vcf.gz' -o -name '*.vcf.gz' \) 2>/dev/null | grep -v g.vcf | head -1 || true)"
  [[ -n "$QUERY_VCF" ]] || QUERY_VCF="$(find "$FERUM_WES_WORK_HOST/$RUN_ID" -type f -name '*.vcf.gz' 2>/dev/null | head -1 || true)"
  [[ -f "$QUERY_VCF" ]] || { echo "no query VCF under $FERUM_WES_WORK_HOST/$RUN_ID" >&2; find "$FERUM_WES_WORK_HOST/$RUN_ID" | head -50 >&2; exit 1; }
  cp -f "$QUERY_VCF" "$ROOT/results/query.vcf.gz"
  echo "[demo] query VCF -> results/query.vcf.gz"

  GW_CID="$(
    docker compose -p "$COMPOSE_PROJECT_NAME" \
      -f "$FERUM_SRC/deploy/docker-compose.yml" \
      -f "$ROOT/demo/docker-compose.ga4gh.yml" \
      ps -q ferrum-gateway 2>/dev/null | head -1 || true
  )"
  MEM="n/a"
  if [[ -n "$GW_CID" ]]; then
    MEM="$(docker stats --no-stream --format '{{.MemUsage}}' "$GW_CID" 2>/dev/null || echo n/a)"
  fi

  echo "[demo] hap.py benchmark..."
  bash "$ROOT/benchmark/run_happy.sh"

  T1="$(date +%s)"
  local EL=$((T1 - T0))

  python3 "$ROOT/demo/lib/record_pass_snapshot.py" \
    "$pass_label" "$EL" "$RUN_ID" "$WORKFLOW_URL" "$MEM" "$ROOT"
}

if [[ "${FERRUM_GA4GH_MACRO_COMPARE:-0}" == "1" ]]; then
  echo "[demo] Phase 2 macro: plain ingest then Crypt4GH-at-rest ingest (same stack, two passes)"
  pipeline_pass plain 0
  cp -f "$ROOT/results/benchmark.json" "$ROOT/results/benchmark.phase2_plain.json"
  pipeline_pass crypt4gh 1
  cp -f "$ROOT/results/benchmark.json" "$ROOT/results/benchmark.phase2_crypt4gh.json"
  python3 "$ROOT/demo/lib/compose_metrics.py" macro "$ROOT"
else
  pipeline_pass primary "${FERRUM_GA4GH_ENCRYPT_INGEST:-0}"
  python3 "$ROOT/demo/lib/compose_metrics.py" single "$ROOT"
fi

echo "[demo] dataset on-disk profile + engine timing merge..."
python3 "$ROOT/scripts/dataset_profile.py" "$ROOT" || true
python3 "$ROOT/demo/lib/update_engine_compare.py" "$ROOT" || true

python3 "$ROOT/scripts/update_docs.py" \
  --repo-root "$ROOT" \
  --metrics "$ROOT/results/metrics.json" \
  --benchmark "$ROOT/results/benchmark.json" \
  --readme "$ROOT/README.md" \
  --bench-md "$ROOT/docs/benchmark.md"

TOTAL_ELAPSED=$(( $(date +%s) - TS_START ))
echo "[demo] done (wall clock since script start: ${TOTAL_ELAPSED}s)"
