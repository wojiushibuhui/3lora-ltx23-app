#!/bin/bash

# ComfyUI 启动脚本 (改进版)
# 确保使用正确的 Python 路径和环境变量
# 添加错误处理和日志输出0116
# 
# 注意：此文件包含修复 libtinfo 版本警告的更新
# 如果 start-comfyui.sh 是只读的，请用此文件替换它

set -e  # 遇到错误立即退出

# 日志函数
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 设置环境变量
export PATH="/usr/local/bin:/root/miniconda3/bin:$PATH"
log_info "设置 PATH: $PATH"

# 修复 libgomp: Invalid value for environment variable OMP_NUM_THREADS
# OMP_NUM_THREADS=0 会导致 libgomp 报错，必须为正整数
if [ "${OMP_NUM_THREADS}" = "0" ]; then
  export OMP_NUM_THREADS=1
  log_info "修复 OMP_NUM_THREADS: 0 -> 1（避免 libgomp 报错）"
fi

# 修复 Numba "Attempted to fork from a non-main thread" + CUDA invalid resource handle
# 使用 workqueue 替代 TBB，避免 fork 时 TBB 状态异常导致子进程崩溃
export NUMBA_THREADING_LAYER=workqueue
log_info "设置 NUMBA_THREADING_LAYER=workqueue（避免 Numba/TBB fork 与 CUDA 冲突）"

# 明确清理可能继承自环境的本地网络变量（127.0.0.1:7890），但保留非本地网络（如 network_turbo）
# 这可以防止 ComfyUI-Manager 在网络服务未启动时尝试连接 127.0.0.1:7890
# 注意：如果使用了 network_turbo（通过 source /etc/network_turbo），其地址不是 127.0.0.1，不会被清理
# 这样可以适应 network_turbo 地址的变化（不依赖硬编码地址）
# 优先检查代理服务是否正在运行（通过检查端口和进程）
# 如果代理服务未开启或程序不存在，会正常跳过，不会影响脚本执行
# 优先检查端口监听状态（更可靠），因为端口监听才是真正可用的代理服务
CLASH_SERVICE_RUNNING=false
set +e  # 临时禁用错误退出，确保检查失败不会导致脚本退出

# 优先检查常见代理端口是否在监听（7890, 7891）- 这是最可靠的指标
if command -v lsof >/dev/null 2>&1; then
    if lsof -Pi :7890 -sTCP:LISTEN -t >/dev/null 2>&1 || lsof -Pi :7891 -sTCP:LISTEN -t >/dev/null 2>&1; then
        CLASH_SERVICE_RUNNING=true
        log_info "检测到代理端口正在监听（7890 或 7891）"
    fi
elif command -v ss >/dev/null 2>&1; then
    if ss -tlnp 2>/dev/null | grep -qE ":(7890|7891) "; then
        CLASH_SERVICE_RUNNING=true
        log_info "检测到代理端口正在监听（7890 或 7891）"
    fi
elif command -v netstat >/dev/null 2>&1; then
    if netstat -tlnp 2>/dev/null | grep -qE ":(7890|7891) "; then
        CLASH_SERVICE_RUNNING=true
        log_info "检测到代理端口正在监听（7890 或 7891）"
    fi
fi

# 如果端口检查未发现服务，再检查代理进程是否在运行（作为备选检查）
if [ "$CLASH_SERVICE_RUNNING" = "false" ] && command -v pgrep >/dev/null 2>&1; then
    if pgrep -f "mihomo|clash" >/dev/null 2>&1; then
        CLASH_SERVICE_RUNNING=true
        log_info "检测到代理进程正在运行"
    fi
fi

set -e  # 恢复错误退出

# 处理代理环境变量：
# 1. 如果代理地址是 127.0.0.1 或 localhost：
#    - 代理服务运行中 → 保留代理环境变量
#    - 代理服务未运行 → 清理代理环境变量（防止连接错误）
# 2. 如果代理地址不是本地地址 → 保留（可能是 network_turbo 等有效代理）
# 3. 如果没有代理环境变量 → 不做任何操作
if [[ "$http_proxy" == *"127.0.0.1"* ]] || [[ "$http_proxy" == *"localhost"* ]] || [[ "$HTTP_PROXY" == *"127.0.0.1"* ]] || [[ "$HTTP_PROXY" == *"localhost"* ]]; then
    if [ "$CLASH_SERVICE_RUNNING" = "true" ]; then
        # 代理服务正在运行，保留代理环境变量
        log_info "检测到代理服务正在运行，保留代理环境变量: ${http_proxy:-${HTTP_PROXY}}"
    else
        # 代理服务未运行或不存在，清理本地代理环境变量
        # 这样可以防止 ComfyUI-Manager 等组件尝试连接不存在的代理服务
        log_warn "检测到本地网络环境变量（127.0.0.1），但代理服务未运行，正在清理以防止连接错误..."
        unset http_proxy
        unset HTTP_PROXY
        unset https_proxy
        unset HTTPS_PROXY
        unset all_proxy
        unset ALL_PROXY
    fi
elif [[ -n "$http_proxy" ]] || [[ -n "$HTTP_PROXY" ]]; then
    # 如果网络不是本地地址，说明可能是 network_turbo 或其他有效网络，保留
    log_info "检测到非本地网络设置，保留: ${http_proxy:-${HTTP_PROXY}}"
fi

# 自动检测并使用代理服务（如果管理员已手动启动，如通过 clashon）
# 如果代理服务正在运行且已有代理环境变量，使用现有代理
if [ "$CLASH_SERVICE_RUNNING" = "true" ] && ([[ -n "$http_proxy" ]] || [[ -n "$HTTP_PROXY" ]]); then
    log_info "检测到代理服务正在运行且已有代理环境变量，使用现有代理: ${http_proxy:-${HTTP_PROXY}}"
    # 确保 no_proxy 已设置
    if [[ -z "$no_proxy" ]] && [[ -z "$NO_PROXY" ]]; then
        export no_proxy="localhost,127.0.0.1,::1"
        export NO_PROXY="$no_proxy"
    fi
elif [ "$CLASH_SERVICE_RUNNING" = "true" ]; then
    # 代理服务正在运行但没有代理环境变量，自动设置以便 ComfyUI-Manager 等使用
    PROXY_URL="http://127.0.0.1:7890"
    export http_proxy="$PROXY_URL"
    export HTTP_PROXY="$PROXY_URL"
    export https_proxy="$PROXY_URL"
    export HTTPS_PROXY="$PROXY_URL"
    export all_proxy="socks5://127.0.0.1:7890"
    export ALL_PROXY="socks5://127.0.0.1:7890"
    export no_proxy="localhost,127.0.0.1,::1"
    export NO_PROXY="$no_proxy"
    log_info "检测到代理服务正在运行，已自动设置代理环境变量: $PROXY_URL"
elif [[ -n "$http_proxy" ]] || [[ -n "$HTTP_PROXY" ]]; then
    # 有代理环境变量但本地代理服务未运行，可能是外部代理（如 network_turbo）
    log_info "检测到外部代理设置，将使用代理: ${http_proxy:-${HTTP_PROXY}}"
    # 确保 no_proxy 已设置（如果 network_turbo 已设置，则使用其设置）
    if [[ -z "$no_proxy" ]] && [[ -z "$NO_PROXY" ]]; then
        export no_proxy="localhost,127.0.0.1,::1"
        export NO_PROXY="$no_proxy"
    fi
else
    log_info "未检测到代理服务或代理环境变量，将不使用代理"
fi

# 设置库路径，优先使用 conda 环境中的 TBB（版本 2022.3.0，满足 Numba 要求）
# 这可以解决 Numba TBB 线程层警告：TBB_INTERFACE_VERSION >= 12060
if [ -z "$LD_LIBRARY_PATH" ]; then
    export LD_LIBRARY_PATH="/root/miniconda3/lib"
else
    export LD_LIBRARY_PATH="/root/miniconda3/lib:$LD_LIBRARY_PATH"
fi
log_info "设置 LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

# 检查 Python 是否存在
if [ ! -f "/root/miniconda3/bin/python" ]; then
    log_error "Python 未找到: /root/miniconda3/bin/python"
    exit 1
fi

# 检查 ComfyUI 目录是否存在
if [ ! -d "/root/ComfyUI" ]; then
    log_error "ComfyUI 目录不存在: /root/ComfyUI"
    exit 1
fi

# 进入 ComfyUI 目录
cd /root/ComfyUI || {
    log_error "无法进入 ComfyUI 目录"
    exit 1
}
log_info "当前工作目录: $(pwd)"

# 检查 main.py 是否存在
if [ ! -f "main.py" ]; then
    log_error "main.py 文件不存在"
    exit 1
fi

# 清理可能存在的 .ipynb_checkpoints 目录（Jupyter notebook 检查点）
# 用户安装插件时可能会自动产生此目录，需要清理以避免问题
if [ -d "custom_nodes/.ipynb_checkpoints" ]; then
    log_info "清理 .ipynb_checkpoints 目录..."
    rm -rf custom_nodes/.ipynb_checkpoints
fi


# 注意：模型和插件目录已经挂载，无需创建符号链接或修改插件目录
# 更新模型符号链接（如果更新脚本存在）
if [ -f "/.autodl/users/9/98101/update-symlinks.sh" ]; then
    log_info "更新模型符号链接..."
    set +e  # 临时禁用错误退出，确保符号链接更新失败不影响 ComfyUI 启动
    # 临时调整 LD_LIBRARY_PATH，优先使用系统库，避免 libtinfo 版本警告
    # 修复：bash: /root/miniconda3/lib/libtinfo.so.6: no version information available
    OLD_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
    export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH#/root/miniconda3/lib:}"
    # 过滤掉 libtinfo 版本警告信息
    bash /.autodl/users/9/98101/update-symlinks.sh 2>&1 | grep -v "no version information available" || true
    SYMLINK_EXIT_CODE=${PIPESTATUS[0]}  # 获取 bash 命令的退出码，而不是 grep 的
    export LD_LIBRARY_PATH="$OLD_LD_LIBRARY_PATH"
    set -e
    if [ $SYMLINK_EXIT_CODE -eq 0 ]; then
        log_info "模型符号链接更新完成"
    else
        log_warn "模型符号链接更新过程中出现错误，但继续启动 ComfyUI"
    fi
else
    log_info "模型符号链接更新脚本不存在，跳过: /.autodl/users/9/98101/update-symlinks.sh"
fi

# 检查端口是否被占用
PORT=6006
# 临时禁用 set -e，检查端口占用情况
set +e
PORT_IN_USE=$(lsof -Pi :$PORT -sTCP:LISTEN -t 2>/dev/null)
PORT_CHECK_EXIT=$?
set -e

if [ $PORT_CHECK_EXIT -eq 0 ] && [ -n "$PORT_IN_USE" ]; then
    log_warn "端口 $PORT 已被占用，尝试终止占用进程..."
    set +e
    echo "$PORT_IN_USE" | xargs kill -9 2>/dev/null || true
    set -e
    sleep 2
fi

# 启动 ComfyUI
log_info "启动 ComfyUI..."
log_info "Python 版本: $(/root/miniconda3/bin/python --version)"
log_info "监听地址: 127.0.0.1:$PORT"

# 使用 nohup 在后台运行，并重定向输出到日志文件
LOG_FILE="/root/ComfyUI/user/comfyui-startup.log"
log_info "日志文件: $LOG_FILE"

# 启动 ComfyUI（前台运行，便于查看输出）
# 注意：如果需要后台运行，请使用 nohup 或 systemd 服务
# 使用 set +e 确保即使 tee 或 Python 进程退出也不会导致脚本立即退出
set +e
/root/miniconda3/bin/python main.py --port $PORT --listen 127.0.0.1 --enable-cors-header "*" 2>&1 | tee -a "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}
set -e

if [ $EXIT_CODE -ne 0 ]; then
    log_error "ComfyUI 启动失败，退出码: $EXIT_CODE"
    exit $EXIT_CODE
fi
