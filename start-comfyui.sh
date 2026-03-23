#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/root/3lora-ltx23-app}"
exec "${APP_DIR}/scripts/start-comfyui-stable.sh" "$@"
