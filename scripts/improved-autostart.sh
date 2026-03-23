#!/bin/bash
# 3lora LTX2.3 AutoDL 自动启动脚本
# ?????????????????

set -e

# ?? PATH ??????? Node.js
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# ????
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
NC='[0m'

print_message() {
    echo -e "${1}${2}${NC}"
}

APP_DIR="${APP_DIR:-/root/3lora-ltx23-app}"
LOG_FILE="/tmp/3lora-ltx23-improved-autostart.log"
LOCK_FILE="/tmp/3lora-ltx23-improved-autostart.lock"

# ????
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
    print_message $BLUE "$1"
}

# ????????
check_service() {
    if lsof -i :6008 >/dev/null 2>&1; then
        # ??????????
        if pgrep -f "node server.js" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# ??????
update_frontend() {
    log_message "?? ??????..."

    if [ -f "$APP_DIR/scripts/update-frontend-on-boot.sh" ]; then
        bash "$APP_DIR/scripts/update-frontend-on-boot.sh" >> "$LOG_FILE" 2>&1
        if [ $? -eq 0 ]; then
            log_message "? ????????"
        else
            log_message "??  ???????????????"
        fi
    else
        log_message "??  ??????????????"
    fi
}

# ????
start_service() {
    log_message "?? ?? 3lora LTX2.3 ??..."

    # ?????????
    cd "$APP_DIR"

    # ????
    ./start-services.sh >> "$LOG_FILE" 2>&1

    # ??????
    local attempts=0
    local max_attempts=30

    while [ $attempts -lt $max_attempts ]; do
        if check_service; then
            log_message "? ??????"
            return 0
        fi
        sleep 1
        attempts=$((attempts + 1))
    done

    log_message "? ?????? - ??"
    return 1
}

# ???? ComfyUI ?????????????
ensure_comfyui_started() {
    if [ -x "$APP_DIR/start-comfyui.sh" ]; then
        log_message "?? ???? ComfyUI ????..."
        nohup "$APP_DIR/start-comfyui.sh" >> "$LOG_FILE" 2>&1 &
    else
        log_message "??  ComfyUI ??????????: $APP_DIR/start-comfyui.sh"
    fi
}

# ???
main() {
    # ?????
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
            log_message "?? ???????? (PID: $lock_pid)???"
            exit 0
        else
            rm -f "$LOCK_FILE"
        fi
    fi

    # ?????
    echo $$ > "$LOCK_FILE"

    # ????
    cleanup() {
        rm -f "$LOCK_FILE"
        exit $?
    }
    trap cleanup EXIT INT TERM

    # ??????
    if check_service; then
        log_message "? ??????"
        ensure_comfyui_started
        exit 0
    fi

    # ???????????
    # update_frontend

    # ????
    start_service
    ensure_comfyui_started
}

# ?????
main "$@"
