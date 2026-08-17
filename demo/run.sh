#!/usr/bin/env bash
# One-command GA4GH demo: Ferrum (TRS+DRS+WES+TES) + GIAB subset + Dockstore cache + hap.py benchmark + doc refresh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export FERRUM_GA4GH_DEMO_ROOT="$ROOT"

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-ferrum-ga4gh-demo}"
# Host path for WES bind (Docker daemon must see this path). Do not inherit a poisoned shell
# (e.g. leftover FERUM_WES_WORK_HOST from a compose-config test). Override only explicitly:
_REPO_WES_DEFAULT="$ROOT/results/wes-work"
if [[ -n "${FERRUM_GA4GH_WES_HOST_OVERRIDE:-}" ]]; then
  export FERUM_WES_WORK_HOST="${FERRUM_GA4GH_WES_HOST_OVERRIDE}"
else
  export FERUM_WES_WORK_HOST="$_REPO_WES_DEFAULT"
fi
# Official nextflow/nextflow images are amd64-only; without this, arm64 hosts fail to create the TES container.
case "$(uname -m)" in
  arm64 | aarch64)
    export FERRUM_TES_DOCKER_PLATFORM="${FERRUM_TES_DOCKER_PLATFORM:-linux/amd64}"
    ;;
esac
export FERRUM_TES_DOCKER_NETWORK_MODE="${COMPOSE_PROJECT_NAME}_default"
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
export FERRUM_GA4GH_CALLER="${FERRUM_GA4GH_CALLER:-gatk}"
_gatk_rs_pin="$(awk -F= '/^gatk-rs-image=/{print $2; exit}' "$ROOT/PINNED_VERSIONS.txt" 2>/dev/null || true)"
_gatk_rs_pin="${_gatk_rs_pin// /}"
export FERRUM_GA4GH_GATK_RS_IMAGE="${FERRUM_GA4GH_GATK_RS_IMAGE:-${_gatk_rs_pin:-}}"
export FERRUM_GA4GH_GATK_RS_SOFT="${FERRUM_GA4GH_GATK_RS_SOFT:-1}"

TS_START="$(date +%s)"
mkdir -p "$FERUM_WES_WORK_HOST" "$ROOT/results" "$ROOT/workflows/cached" "$ROOT/data" "$ROOT/drs"

command -v docker >/dev/null || { echo "docker required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 required" >&2; exit 1; }
command -v curl >/dev/null || { echo "curl required (for static docker CLI in TES/Cromwell)" >&2; exit 1; }

echo "[demo] ensuring Crypt4GH demo keys (gitignored; not the burned committed key)..."
chmod +x "$ROOT/scripts/ensure-crypt4gh-demo-keys.sh"
bash "$ROOT/scripts/ensure-crypt4gh-demo-keys.sh"

# Optional Alpha path: not the evidence default. Refuse :latest / empty image unless overridden.
if [[ "${FERRUM_GA4GH_CALLER}" == "gatk-rs" ]]; then
  _gatk_rs_refuse=0
  case "${FERRUM_GA4GH_GATK_RS_IMAGE}" in
    ""|*:latest|*:latest-arm64|*:latest-amd64) _gatk_rs_refuse=1 ;;
  esac
  if [[ "$_gatk_rs_refuse" == "1" && "${FERRUM_GA4GH_ALLOW_LATEST:-0}" != "1" ]]; then
    echo "[demo] gatk-rs is Alpha and not the evidence path. Pin FERRUM_GA4GH_GATK_RS_IMAGE (digest/tag, not :latest) or set FERRUM_GA4GH_ALLOW_LATEST=1 for a throwaway lab." >&2
    python3 - <<PY
import json
from datetime import datetime, timezone
from pathlib import Path
root = Path("$ROOT")
out = {
  "schema_version": 1,
  "stage": "gatk_rs_wes",
  "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
  "status": "skipped",
  "reason": "image_unpinned",
  "image": "${FERRUM_GA4GH_GATK_RS_IMAGE}",
  "soft": True,
  "honesty": (
    "Optional gatk-rs WES path skipped: image empty or :latest. "
    "Default Broad GATK path is unchanged. Not evidence-grade."
  ),
}
(root / "results").mkdir(parents=True, exist_ok=True)
(root / "results" / "gatk_rs_wes_result.json").write_text(json.dumps(out, indent=2) + "\\n", encoding="utf-8")
print(json.dumps({"ok": True, "skipped": True, "reason": "image_unpinned"}))
PY
    if [[ "${FERRUM_GA4GH_GATK_RS_SOFT}" == "1" ]]; then
      exit 0
    fi
    exit 3
  fi
  echo "[demo] caller=gatk-rs image=${FERRUM_GA4GH_GATK_RS_IMAGE} (optional Alpha; default remains Broad GATK)"
  docker pull "${FERRUM_GA4GH_GATK_RS_IMAGE}" >/dev/null 2>&1 || true
  if ! docker image inspect "${FERRUM_GA4GH_GATK_RS_IMAGE}" >/dev/null 2>&1; then
    python3 - <<PY
import json
from datetime import datetime, timezone
from pathlib import Path
root = Path("$ROOT")
out = {
  "schema_version": 1,
  "stage": "gatk_rs_wes",
  "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
  "status": "skipped",
  "reason": "image_missing",
  "image": "${FERRUM_GA4GH_GATK_RS_IMAGE}",
  "soft": True,
  "honesty": (
    "Optional gatk-rs WES path soft-skipped: Docker image not present. "
    "Default Ferrum Nextflow + Broad GATK path is unchanged. "
    "gatk-rs is Alpha — absence of the image is not a Ferrum product failure."
  ),
}
(root / "results").mkdir(parents=True, exist_ok=True)
(root / "results" / "gatk_rs_wes_result.json").write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"ok": True, "skipped": True, "wrote": str(root / "results" / "gatk_rs_wes_result.json")}))
PY
    if [[ "${FERRUM_GA4GH_GATK_RS_SOFT}" == "1" ]]; then
      echo "[demo] gatk-rs image missing — soft-skip (set FERRUM_GA4GH_GATK_RS_SOFT=0 to hard-fail)"
      exit 0
    fi
    echo "[demo] gatk-rs image missing and FERRUM_GA4GH_GATK_RS_SOFT=0 — hard-fail" >&2
    exit 3
  fi
fi

echo "[demo] ensuring Linux docker CLI for Cromwell/Nextflow-in-TES (nested docker runs)..."
chmod +x "$ROOT/scripts/ensure_docker_cli_static.sh"
bash "$ROOT/scripts/ensure_docker_cli_static.sh" "$ROOT"
DOCKER_CLI_HOST="$ROOT/.cache/docker-cli-static/docker"
export FERRUM_TES_DOCKER_MOUNT_SOCKET=1
export FERRUM_TES_DOCKER_CLI_HOST_PATH="$DOCKER_CLI_HOST"

# Prefer FERRUM_SRC; keep FERUM_SRC as a deprecated alias (typo in early docs).
FERRUM_SRC="${FERRUM_SRC:-${FERUM_SRC:-$ROOT/.cache/stack/Ferrum}}"
FERUM_SRC="$FERRUM_SRC"
export FERRUM_SRC FERUM_SRC
_pin="$(awk -F= '/^Ferrum-git=/{print $2; exit}' "$ROOT/PINNED_VERSIONS.txt" 2>/dev/null || true)"
_pin="${_pin// /}"
_allow_unpin="${FERRUM_GA4GH_ALLOW_UNPINNED:-0}"
if [[ ! -d "$FERRUM_SRC/.git" ]]; then
  echo "[demo] cloning Ferrum into $FERRUM_SRC ..."
  mkdir -p "$(dirname "$FERRUM_SRC")"
  if [[ -z "$_pin" ]]; then
    echo "[demo] PINNED_VERSIONS.txt has empty Ferrum-git= — set a SHA or FERRUM_GA4GH_ALLOW_UNPINNED=1" >&2
    exit 3
  fi
  git clone https://github.com/SynapticFour/Ferrum.git "$FERRUM_SRC"
  echo "[demo] checking out pinned Ferrum-git=${_pin}"
  git -C "$FERRUM_SRC" fetch --depth 1 origin "$_pin"
  git -C "$FERRUM_SRC" checkout --detach "$_pin"
else
  _have="$(git -C "$FERRUM_SRC" rev-parse HEAD)"
  if [[ -n "$_pin" && "$_have" != "$_pin" ]]; then
    echo "[demo] Ferrum at $FERRUM_SRC is $_have, pin is $_pin" >&2
    if [[ "$_allow_unpin" != "1" ]]; then
      echo "[demo] refusing unpinned Ferrum (set FERRUM_GA4GH_ALLOW_UNPINNED=1 to override)" >&2
      exit 3
    fi
    echo "[demo] warn: continuing unpinned because FERRUM_GA4GH_ALLOW_UNPINNED=1"
  fi
fi
echo "[demo] Ferrum sources: $FERRUM_SRC ($(git -C "$FERRUM_SRC" rev-parse --short HEAD 2>/dev/null || echo unknown))"

GA4GH_INFRA_SRC="${GA4GH_INFRA_SRC:-$(dirname "$FERRUM_SRC")/ga4gh-infra}"
if [[ "${FERRUM_GA4GH_WITH_INFRA:-0}" == "1" ]]; then
  _infra_pin="$(awk -F= '/^GA4GH-INFRA-git=/{print $2; exit}' "$ROOT/PINNED_VERSIONS.txt" 2>/dev/null || true)"
  _infra_pin="${_infra_pin// /}"
  if [[ ! -d "$GA4GH_INFRA_SRC/.git" ]]; then
    if [[ -z "$_infra_pin" && "$_allow_unpin" != "1" ]]; then
      echo "[demo] PINNED_VERSIONS.txt has empty GA4GH-INFRA-git=; set a SHA or FERRUM_GA4GH_ALLOW_UNPINNED=1" >&2
      exit 3
    fi
    echo "[demo] cloning ga4gh-infra into $GA4GH_INFRA_SRC ..."
    mkdir -p "$(dirname "$GA4GH_INFRA_SRC")"
    git clone https://github.com/SynapticFour/ga4gh-infra.git "$GA4GH_INFRA_SRC"
    if [[ -n "$_infra_pin" ]]; then
      echo "[demo] checking out pinned GA4GH-INFRA-git=${_infra_pin}"
      git -C "$GA4GH_INFRA_SRC" fetch --depth 1 origin "$_infra_pin"
      git -C "$GA4GH_INFRA_SRC" checkout --detach "$_infra_pin"
    else
      echo "[demo] warn: cloning unpinned ga4gh-infra because FERRUM_GA4GH_ALLOW_UNPINNED=1"
    fi
  else
    _have_infra="$(git -C "$GA4GH_INFRA_SRC" rev-parse HEAD)"
    if [[ -n "$_infra_pin" && "$_have_infra" != "$_infra_pin" ]]; then
      echo "[demo] ga4gh-infra at $GA4GH_INFRA_SRC is $_have_infra, pin is $_infra_pin" >&2
      if [[ "$_allow_unpin" != "1" ]]; then
        echo "[demo] refusing unpinned ga4gh-infra (set FERRUM_GA4GH_ALLOW_UNPINNED=1 to override)" >&2
        exit 3
      fi
      echo "[demo] warn: continuing unpinned ga4gh-infra because FERRUM_GA4GH_ALLOW_UNPINNED=1"
    fi
  fi
  export GA4GH_INFRA_SRC
  if [[ -x "$GA4GH_INFRA_SRC/scripts/prepare-docker-vendor.sh" ]]; then
    echo "[demo] ensuring ga4gh-infra docker/vendor (Dockerfiles COPY it)..."
    bash "$GA4GH_INFRA_SRC/scripts/prepare-docker-vendor.sh"
  elif [[ ! -d "$GA4GH_INFRA_SRC/docker/vendor" ]]; then
    echo "[demo] ga4gh-infra docker/vendor missing; run scripts/prepare-docker-vendor.sh in that repo" >&2
    exit 3
  fi
fi

echo "[demo] using stock Ferrum pin (no overlay; TES/residency honesty is in v0.3.1)..."
if [[ -d "$FERRUM_SRC/.git" ]]; then
  git -C "$FERRUM_SRC" checkout HEAD -- \
    crates/ferrum-drs/src/repo.rs \
    crates/ferrum-tes/src/executors/docker.rs \
    crates/ferrum-wes/src/executors/tes.rs \
    crates/ferrum-core/src/residency.rs \
    deploy/Dockerfile.gateway \
    2>/dev/null || true
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
# Serve only workflows/ (not the repo root — that would expose Crypt4GH keys).
# Bind 0.0.0.0 so TES containers can fetch via host.docker.internal (loopback is not enough).
( cd "$ROOT/workflows" && python3 -m http.server "$STATIC_PORT" --bind 0.0.0.0 ) &
STATIC_PID=$!
sleep 1

if [[ "${FERRUM_GA4GH_ENGINE}" == "nextflow" ]]; then
  if [[ "${FERRUM_GA4GH_CALLER}" == "gatk-rs" ]]; then
    WORKFLOW_URL="http://host.docker.internal:${STATIC_PORT}/tiny_hc_gatk_rs.nf"
    echo "[demo] engine=nextflow caller=gatk-rs workflow=$WORKFLOW_URL"
  else
    WORKFLOW_URL="http://host.docker.internal:${STATIC_PORT}/tiny_hc.nf"
    echo "[demo] engine=nextflow caller=gatk (Broad) workflow=$WORKFLOW_URL"
  fi
  PARAMS_JSON="$ROOT/demo/nf_params.json"
else
  WORKFLOW_URL="http://host.docker.internal:${STATIC_PORT}/tiny_hc.wdl"
  PARAMS_JSON="$ROOT/demo/inputs.json"
  echo "[demo] engine=wdl workflow=$WORKFLOW_URL"
fi

COMPOSE_FILES=(
  -f docker-compose.yml
  -f "$ROOT/demo/docker-compose.ga4gh.yml"
)
if [[ -n "${INFRA_OVERLAY:-}" ]]; then
  COMPOSE_FILES+=(${INFRA_OVERLAY})
fi
if [[ -n "${CO_DEPLOY_OVERLAY:-}" ]]; then
  COMPOSE_FILES+=(${CO_DEPLOY_OVERLAY})
fi
if [[ -n "${AFRICA_OVERLAY:-}" ]]; then
  COMPOSE_FILES+=(${AFRICA_OVERLAY})
fi

echo "[demo] building & starting Ferrum stack (docker compose)..."
(
  cd "$FERRUM_SRC/deploy"
  # Fresh Postgres/MinIO volumes avoid half-applied migrations when re-running the demo.
  if [[ "${FERRUM_GA4GH_RESET_VOLUMES:-1}" == "1" ]]; then
    docker compose -p "$COMPOSE_PROJECT_NAME" \
      "${COMPOSE_FILES[@]}" \
      down -v --remove-orphans 2>/dev/null || true
  fi
  docker compose -p "$COMPOSE_PROJECT_NAME" \
    "${COMPOSE_FILES[@]}" \
    up -d --build
)

echo "[demo] pre-pull workflow images (best-effort; skip if offline)..."
docker pull broadinstitute/cromwell:93-0232cbd >/dev/null 2>&1 || true
docker pull broadinstitute/gatk:4.4.0.0@sha256:044112d3d70603732d4a654ecaee33919cf9d45332d47268f5f1697b6ed558ed >/dev/null 2>&1 || true
if [[ "${FERRUM_GA4GH_CALLER}" == "gatk-rs" ]]; then
  docker pull "${FERRUM_GA4GH_GATK_RS_IMAGE}" >/dev/null 2>&1 || true
  docker pull quay.io/biocontainers/htslib:1.19--h5e77b09_0 >/dev/null 2>&1 || true
fi
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

if [[ "${FERRUM_GA4GH_WITH_INFRA:-0}" == "1" ]]; then
  echo "[demo] waiting for ga4gh-infra co-deploy services..."
  for url in \
    "http://127.0.0.1:8180/service-info" \
    "http://127.0.0.1:8181/service-info" \
    "http://127.0.0.1:8183/service-info" \
    "http://127.0.0.1:8190/service-info"; do
    for _ in $(seq 1 60); do
      if curl -fsS "$url" >/dev/null 2>&1; then
        break
      fi
      sleep 2
    done
    curl -fsS "$url" >/dev/null
  done
fi

# Co-deploy scenarios run before the WES pipeline so auth/registry checks are not blocked by hap.py.
if [[ "${FERRUM_GA4GH_WITH_INFRA:-0}" == "1" ]]; then
    echo "[demo] detecting ga4gh-infra co-deploy services..."
    python3 "$ROOT/demo/lib/infra_feature_detect.py" \
        > "$ROOT/results/infra_features.json" 2>/dev/null || true

    INFRA_AVAILABLE=$(python3 -c "
import json, sys
try:
    d = json.load(open('$ROOT/results/infra_features.json'))
    print(d.get('available_count', 0))
except Exception:
    print(0)
")

    INFRA_FAILED=0
    if [[ "$INFRA_AVAILABLE" -gt 0 ]]; then
        echo "[demo] ga4gh-infra detected ($INFRA_AVAILABLE services). Running co-deploy scenarios..."
        python3 - <<PYEOF
import sys, json
sys.path.insert(0, '$ROOT/demo/lib')
from infra_feature_detect import detect
from co_deploy_scenarios import run_all
from pathlib import Path

root = Path('$ROOT')
gateway = '$GATEWAY'
fs = detect()
results = run_all(gateway, root, fs)
(root / 'results' / 'co_deploy_results.json').write_text(
    json.dumps(results, indent=2), encoding='utf-8'
)
print(json.dumps({"ok": True, "summary": results["summary"]}))
PYEOF
        if python3 -c "import json; raise SystemExit(0 if json.load(open('$ROOT/results/co_deploy_results.json')).get('summary',{}).get('verdict')!='failed' else 1)"; then
          INFRA_FAILED=0
        else
          INFRA_FAILED=1
        fi
    else
        echo "[demo] ga4gh-infra services not reachable. Skipping co-deploy scenarios."
        python3 -c "
import json
from pathlib import Path
Path('$ROOT/results/co_deploy_results.json').write_text(
    json.dumps({'detected_features': {}, 'available_count': 0,
                'scenarios': {}, 'summary': {'ran': 0, 'skipped': 4, 'errors': 0,
                'all_passed': False, 'verdict': 'not_evaluated',
                'note': 'ga4gh-infra not running'}},
    indent=2), encoding='utf-8')
"
    fi
else
    python3 -c "
import json
from pathlib import Path
Path('$ROOT/results/co_deploy_results.json').write_text(
    json.dumps({'detected_features': {}, 'available_count': 0,
                'scenarios': {}, 'summary': {'ran': 0, 'skipped': 4, 'errors': 0,
                'all_passed': False, 'verdict': 'not_evaluated',
                'note': 'Run ./run --with-infra to enable co-deploy scenarios'}},
    indent=2), encoding='utf-8')
"
fi

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
  if [[ "${FERRUM_GA4GH_CALLER}" == "gatk-rs" ]]; then
    python3 - "$ROOT/demo/nf_params.json" "${FERRUM_GA4GH_GATK_RS_IMAGE}" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
d = json.loads(p.read_text(encoding="utf-8")) if p.is_file() else {}
d["gatk_rs_image"] = sys.argv[2]
p.write_text(json.dumps(d, indent=2) + "\n", encoding="utf-8")
PY
  fi
  export FERRUM_GA4GH_INPUT_DRS_URI
  FERRUM_GA4GH_INPUT_DRS_URI="$(
    python3 -c "import json; print(json.load(open('$ROOT/drs/mapping.json'))['objects']['input_bam']['drs_uri'])"
  )"

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

  QUERY_VCF=""
  VCF_WAIT_SECS="${FERRUM_GA4GH_VCF_WAIT_SECS:-1800}"
  VCF_POLL_INTERVAL="${FERRUM_GA4GH_VCF_POLL_INTERVAL:-5}"
  VCF_ATTEMPTS=$((VCF_WAIT_SECS / VCF_POLL_INTERVAL))
  [[ "$VCF_ATTEMPTS" -ge 1 ]] || VCF_ATTEMPTS=1
  echo "[demo] waiting up to ${VCF_WAIT_SECS}s for query VCF under ${FERUM_WES_WORK_HOST}/${RUN_ID}..."
  for _ in $(seq 1 "$VCF_ATTEMPTS"); do
    QUERY_VCF="$(find "$FERUM_WES_WORK_HOST/$RUN_ID" -type f \( -name 'output.vcf.gz' -o -name '*.vcf.gz' \) 2>/dev/null | grep -v g.vcf | head -1 || true)"
    [[ -n "$QUERY_VCF" ]] || QUERY_VCF="$(find "$FERUM_WES_WORK_HOST/$RUN_ID" -type f -name '*.vcf.gz' 2>/dev/null | head -1 || true)"
    [[ -f "$QUERY_VCF" ]] && break
    sleep "$VCF_POLL_INTERVAL"
  done
  [[ -f "$QUERY_VCF" ]] || { echo "no query VCF under $FERUM_WES_WORK_HOST/$RUN_ID" >&2; find "$FERUM_WES_WORK_HOST/$RUN_ID" | head -50 >&2; exit 1; }
  cp -f "$QUERY_VCF" "$ROOT/results/query.vcf.gz"
  echo "[demo] query VCF -> results/query.vcf.gz"

  echo "[demo] DRS stream micro-benchmark (plain + optional Crypt4GH header)..."
  chmod +x "$ROOT/scripts/drs_micro_benchmark.py"
  REF_OID="$(python3 -c "import json; print(json.load(open('$ROOT/drs/mapping.json'))['objects']['ref_fasta']['object_id'])")"
  DRS_MICRO_ARGS=(python3 "$ROOT/scripts/drs_micro_benchmark.py" "$GATEWAY" "$REF_OID" -o "$ROOT/results/drs_micro.json")
  if [[ -n "${FERRUM_GA4GH_CRYPT4GH_PUBKEY:-}" && -f "${FERRUM_GA4GH_CRYPT4GH_PUBKEY}" ]]; then
    DRS_MICRO_ARGS+=(--crypt4gh-pubkey "${FERRUM_GA4GH_CRYPT4GH_PUBKEY}")
  fi
  "${DRS_MICRO_ARGS[@]}"

  GW_CID="$(
    docker compose -p "$COMPOSE_PROJECT_NAME" \
      -f "$FERRUM_SRC/deploy/docker-compose.yml" \
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
  cp -f "$ROOT/drs/mapping.json" "$ROOT/results/drs_mapping_phase_plain.json"
  cp -f "$ROOT/results/benchmark.json" "$ROOT/results/benchmark.phase2_plain.json"
  pipeline_pass crypt4gh 1
  cp -f "$ROOT/results/benchmark.json" "$ROOT/results/benchmark.phase2_crypt4gh.json"
  echo "[demo] DRS micro: plain vs Crypt4GH-at-rest ref_fasta (same logical file, two object ids)..."
  PLAIN_REF="$(python3 -c "import json; print(json.load(open('$ROOT/results/drs_mapping_phase_plain.json'))['objects']['ref_fasta']['object_id'])")"
  ENC_REF="$(python3 -c "import json; print(json.load(open('$ROOT/drs/mapping.json'))['objects']['ref_fasta']['object_id'])")"
  DRS_MICRO_ARGS=(python3 "$ROOT/scripts/drs_micro_benchmark.py" "$GATEWAY" "$PLAIN_REF" \
    --encrypted-object-id "$ENC_REF" -o "$ROOT/results/drs_micro.json")
  if [[ -n "${FERRUM_GA4GH_CRYPT4GH_PUBKEY:-}" && -f "${FERRUM_GA4GH_CRYPT4GH_PUBKEY}" ]]; then
    DRS_MICRO_ARGS+=(--crypt4gh-pubkey "${FERRUM_GA4GH_CRYPT4GH_PUBKEY}")
  fi
  "${DRS_MICRO_ARGS[@]}"
else
  pipeline_pass primary "${FERRUM_GA4GH_ENCRYPT_INGEST:-0}"
fi

# ── Africa probes always; scenarios fail the process only with --africa ──
echo "[demo] detecting Africa features in running Ferrum instance..."
python3 "$ROOT/demo/lib/africa_feature_detect.py" "$GATEWAY" \
    > "$ROOT/results/africa_features.json" 2>/dev/null || true

AFRICA_AVAILABLE=$(python3 -c "
import json
try:
    d = json.load(open('$ROOT/results/africa_features.json'))
    print(d.get('available_count', 0))
except Exception:
    print(0)
")
AFRICA_MODE="${FERRUM_GA4GH_AFRICA_MODE:-0}"
AFRICA_FAILED=0

if [[ "$AFRICA_MODE" == "1" && "$AFRICA_AVAILABLE" -gt 0 ]]; then
    echo "[demo] --africa: features detected ($AFRICA_AVAILABLE). Running scenarios..."
    python3 - <<PYEOF
import sys, json
sys.path.insert(0, '$ROOT/demo/lib')
from africa_feature_detect import detect
from africa_scenarios import run_all
from pathlib import Path

root = Path('$ROOT')
gateway = '$GATEWAY'
fs = detect(gateway)
results = run_all(gateway, root, fs)
(root / 'results' / 'africa_results.json').write_text(
    json.dumps(results, indent=2), encoding='utf-8'
)
print(json.dumps({"ok": True, "summary": results["summary"]}))
PYEOF
    AFRICA_FAILED=0
    if python3 -c "import json; raise SystemExit(0 if json.load(open('$ROOT/results/africa_results.json')).get('summary',{}).get('verdict')!='failed' else 1)"; then
      AFRICA_FAILED=0
    else
      AFRICA_FAILED=1
    fi
elif [[ "$AFRICA_AVAILABLE" -gt 0 ]]; then
    echo "[demo] Africa endpoints detected ($AFRICA_AVAILABLE) but --africa was not set; recording not_evaluated (not a pass, not a fail of the GA4GH smoke)."
    python3 -c "
import json
from pathlib import Path
feat = {}
p = Path('$ROOT/results/africa_features.json')
if p.is_file():
    try:
        feat = json.loads(p.read_text())
    except Exception:
        feat = {}
Path('$ROOT/results/africa_results.json').write_text(
    json.dumps({
        'detected_features': (feat.get('features') or {}),
        'available_count': int('$AFRICA_AVAILABLE'),
        'scenarios': {},
        'summary': {
            'ran': 0, 'skipped': 6, 'errors': 0,
            'all_passed': False, 'verdict': 'not_evaluated',
            'note': 'Africa scenarios run only with ./run --africa. Detection is not a pass.',
        },
    }, indent=2), encoding='utf-8')
"
else
    echo "[demo] No Africa features detected. Recording not_evaluated (not a pass)."
    python3 -c "
import json
from pathlib import Path
Path('$ROOT/results/africa_results.json').write_text(
    json.dumps({'detected_features': {}, 'available_count': 0,
                'scenarios': {}, 'summary': {'ran': 0, 'skipped': 6, 'errors': 0,
                'all_passed': False, 'verdict': 'not_evaluated',
                'note': 'No Africa-specific endpoints in this Ferrum build'}},
    indent=2), encoding='utf-8')
"
fi

if [[ "${FERRUM_GA4GH_MACRO_COMPARE:-0}" == "1" ]]; then
  METRICS_MODE=macro
else
  METRICS_MODE=single
fi
python3 "$ROOT/demo/lib/compose_metrics.py" "$METRICS_MODE" "$ROOT"

echo "[demo] dataset on-disk profile + engine timing merge..."
python3 "$ROOT/scripts/dataset_profile.py" "$ROOT"
python3 "$ROOT/demo/lib/update_engine_compare.py" "$ROOT"

python3 "$ROOT/scripts/update_docs.py" \
  --repo-root "$ROOT" \
  --metrics "$ROOT/results/metrics.json" \
  --benchmark "$ROOT/results/benchmark.json" \
  --readme "$ROOT/README.md" \
  --bench-md "$ROOT/docs/benchmark.md"

python3 "$ROOT/demo/lib/write_run_manifest.py" "$ROOT"

TOTAL_ELAPSED=$(( $(date +%s) - TS_START ))
echo "[demo] done (wall clock since script start: ${TOTAL_ELAPSED}s)"
echo "[demo] Read results/RUN_MANIFEST.json for what this run did and did not prove."
if [[ "${AFRICA_FAILED:-0}" != "0" ]]; then
  echo "[demo] --africa scenarios failed (see results/africa_results.json). GA4GH smoke artefacts were still written." >&2
fi
if [[ "${INFRA_FAILED:-0}" != "0" ]]; then
  echo "[demo] --with-infra co-deploy scenarios failed (see results/co_deploy_results.json). GA4GH smoke artefacts were still written." >&2
fi
if [[ "${AFRICA_FAILED:-0}" != "0" || "${INFRA_FAILED:-0}" != "0" ]]; then
  exit 1
fi
