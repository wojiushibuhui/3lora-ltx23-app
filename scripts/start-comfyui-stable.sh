#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/root/3lora-ltx23-app}"
COMFY_DIR="${COMFY_DIR:-/root/ComfyUI}"
PYTHON_BIN="${PYTHON_BIN:-/root/miniconda3/bin/python}"
UPDATE_SYMLINKS_SCRIPT="${UPDATE_SYMLINKS_SCRIPT:-${APP_DIR}/update-symlinks.sh}"
PORT="6006"
LISTEN_ADDR="127.0.0.1"
LOG_FILE="${COMFY_DIR}/user/comfyui-stable-startup.log"
PID_FILE="${COMFY_DIR}/user/comfyui-6006.pid"
DB_URL="${DB_URL:-sqlite:////root/ComfyUI/user/comfyui-6006.db}"
BACKUP_SUFFIX=".disabled_by_codex_20260322"
HEALTH_URL="http://${LISTEN_ADDR}:${PORT}/system_stats"
LAUNCH_MODE="${COMFY_LAUNCH_MODE:-auto}"
LOW_MEM_THRESHOLD_BYTES=$((4 * 1024 * 1024 * 1024))

FRONTEND_DIRS=(
  "custom_nodes/ComfyUI-Crystools/web"
  "custom_nodes/rgthree-comfy/web/comfyui"
  "custom_nodes/comfyui-GaussianViewer/web"
  "custom_nodes/ComfyUI-GeometryPack/web"
  "custom_nodes/ComfyUI-QwenImageLoraLoader/js"
  "custom_nodes/ComfyUI-qwenmultiangle/js"
  "custom_nodes/Comfyui_Prompt_Edit/web"
)

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

is_healthy() {
  curl -fsS --max-time 2 "$HEALTH_URL" >/dev/null 2>&1
}

ensure_frontend_disabled() {
  local rel="$1"
  local full="${COMFY_DIR}/${rel}"
  local backup="${full}${BACKUP_SUFFIX}"

  if [ -e "$full" ] && [ ! -e "$backup" ]; then
    mv "$full" "$backup"
  fi

  rm -rf "$full"
  mkdir -p "$full"
}

kill_existing_6006() {
  local pids=""

  if command -v lsof >/dev/null 2>&1; then
    pids="$(lsof -t -iTCP:${PORT} -sTCP:LISTEN 2>/dev/null || true)"
  elif command -v fuser >/dev/null 2>&1; then
    pids="$(fuser -n tcp ${PORT} 2>/dev/null || true)"
  else
    pids="$(ss -lntp 2>/dev/null | awk '/:6006 / {print $NF}' | grep -oE 'pid=[0-9]+' | cut -d= -f2 | sort -u || true)"
  fi

  if [ -n "$pids" ]; then
    log "Stopping existing listeners on :${PORT}: $pids"
    echo "$pids" | xargs -r kill -9 2>/dev/null || true
    sleep 2
  fi

  pkill -f "main.py .*--port ${PORT}" 2>/dev/null || true
  sleep 1
}

wait_for_port_release() {
  local i
  for i in $(seq 1 20); do
    if ! ss -lnt 2>/dev/null | grep -q ":${PORT} "; then
      return 0
    fi
    sleep 1
  done
  return 1
}

detect_memory_limit_bytes() {
  local limit=""
  if [ -f /sys/fs/cgroup/memory.max ]; then
    limit="$(cat /sys/fs/cgroup/memory.max 2>/dev/null || true)"
  elif [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    limit="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || true)"
  fi

  if [ -z "$limit" ] || [ "$limit" = "max" ]; then
    echo ""
  else
    echo "$limit"
  fi
}

choose_runtime_args() {
  local mem_limit=""
  local has_gpu="false"

  RUNTIME_ARGS=()
  mem_limit="$(detect_memory_limit_bytes)"

  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    has_gpu="true"
  fi

  case "$LAUNCH_MODE" in
    auto)
      if [ "$has_gpu" = "true" ]; then
        log "Detected NVIDIA driver; launching in GPU mode"
      else
        RUNTIME_ARGS+=(--cpu)
        log "No usable NVIDIA driver detected; launching in CPU mode"
        if [ -n "$mem_limit" ] && [ "$mem_limit" -le "$LOW_MEM_THRESHOLD_BYTES" ]; then
          RUNTIME_ARGS+=(--disable-all-custom-nodes)
          log "Container memory limit is ${mem_limit} bytes; enabling safe CPU boot without custom nodes"
        fi
      fi
      ;;
    cpu)
      RUNTIME_ARGS+=(--cpu)
      log "Forcing CPU mode via COMFY_LAUNCH_MODE=cpu"
      ;;
    gpu)
      log "Forcing GPU mode via COMFY_LAUNCH_MODE=gpu"
      ;;
    *)
      log "Unsupported COMFY_LAUNCH_MODE=${LAUNCH_MODE}"
      exit 1
      ;;
  esac
}

export PATH="/usr/local/bin:/root/miniconda3/bin:/usr/bin:/bin:${PATH}"
if [ "${OMP_NUM_THREADS:-}" = "0" ]; then
  export OMP_NUM_THREADS=1
fi
export NUMBA_THREADING_LAYER=workqueue
if [ -z "${LD_LIBRARY_PATH:-}" ]; then
  export LD_LIBRARY_PATH="/root/miniconda3/lib"
else
  export LD_LIBRARY_PATH="/root/miniconda3/lib:${LD_LIBRARY_PATH}"
fi

if [ ! -x "$PYTHON_BIN" ]; then
  log "Python not found: $PYTHON_BIN"
  exit 1
fi

if [ ! -f "${COMFY_DIR}/main.py" ]; then
  log "ComfyUI main.py not found in ${COMFY_DIR}"
  exit 1
fi

mkdir -p "${COMFY_DIR}/user"
cd "$COMFY_DIR"

if is_healthy; then
  log "ComfyUI already healthy on ${LISTEN_ADDR}:${PORT}"
  exit 0
fi

if [ -d "custom_nodes/.ipynb_checkpoints" ]; then
  rm -rf "custom_nodes/.ipynb_checkpoints"
fi

if [ -f "$UPDATE_SYMLINKS_SCRIPT" ]; then
  bash "$UPDATE_SYMLINKS_SCRIPT" >/dev/null 2>&1 || true
fi

for rel in "${FRONTEND_DIRS[@]}"; do
  ensure_frontend_disabled "$rel"
done

choose_runtime_args
kill_existing_6006
if ! wait_for_port_release; then
  log "Port ${PORT} is still busy after cleanup"
  exit 1
fi

: > "$LOG_FILE"
nohup "$PYTHON_BIN" main.py       "${RUNTIME_ARGS[@]}"       --listen "$LISTEN_ADDR"       --port "$PORT"       --enable-cors-header "*"       --database-url "$DB_URL"       >> "$LOG_FILE" 2>&1 < /dev/null &

echo $! > "$PID_FILE"
log "Started ComfyUI on ${LISTEN_ADDR}:${PORT} with PID $(cat "$PID_FILE")"

for i in $(seq 1 180); do
  if is_healthy; then
    log "ComfyUI is healthy on ${LISTEN_ADDR}:${PORT}"
    exit 0
  fi

  if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    log "ComfyUI exited before becoming healthy"
    tail -n 120 "$LOG_FILE" || true
    exit 1
  fi

  sleep 1
done

log "ComfyUI did not become healthy in time"
tail -n 120 "$LOG_FILE" || true
exit 1
