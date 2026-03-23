#!/bin/bash
# 3lora LTX2.3 后台守护进程
# 持续监控服务状态,自动重启

# 设置 PATH 确保使用系统级 Node.js
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

APP_DIR="${APP_DIR:-/root/3lora-ltx23-app}"
LOG_FILE="/tmp/3lora-ltx23-daemon.log"

echo "$(date): 守护进程启动" >> "$LOG_FILE"

while true; do
    # 检查服务是否运行
    if ! lsof -i :6008 >/dev/null 2>&1; then
        echo "$(date): 服务未运行,尝试启动..." >> "$LOG_FILE"
        "$APP_DIR/scripts/improved-autostart.sh" >> "$LOG_FILE" 2>&1
    fi
    
    # 每5分钟检查一次
    sleep 300
done
