#!/bin/bash

# 模型符号链接更新脚本（简洁版）
# 使用方法：在下方直接添加符号链接命令，格式如下：
# ln -s <源路径> <目标路径>
# 脚本会自动检查并创建；若目标已是正确符号链接则跳过；若存在但指向不同目标则先 rm 再 ln -s

# 日志函数
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# 重定义 ln 命令，自动添加检查和日志
ln() {
    # 只处理 ln -s 命令
    if [ "$1" != "-s" ] || [ -z "$2" ] || [ -z "$3" ]; then
        # 如果不是 ln -s 格式，调用原始命令
        command ln "$@"
        return $?
    fi
    
    local source_path="$2"
    local target_path="$3"
    
    # 检查源文件是否存在
    if [ ! -e "$source_path" ]; then
        log_warn "源文件不存在，跳过: $source_path -> $target_path"
        skipped_count=$((skipped_count + 1))
        return 0
    fi
    
    # 检查目标路径是否已存在
    if [ -e "$target_path" ]; then
        if [ -L "$target_path" ]; then
            # 检查符号链接是否指向正确的源（readlink -f 比较真实文件路径）
            set +e
            current_target=$(readlink -f "$target_path" 2>/dev/null)
            source_real=$(readlink -f "$source_path" 2>/dev/null)
            set -e
            
            if [ "$current_target" = "$source_real" ] && [ -n "$current_target" ] && [ -n "$source_real" ]; then
                log_info "符号链接已存在且正确，跳过: $target_path"
                skipped_count=$((skipped_count + 1))
                return 0
            else
                log_info "符号链接指向不同目标，先 rm 再 ln: $target_path"
                rm -f "$target_path"
                # 继续下方创建新链接
            fi
        else
            log_warn "目标路径已存在但不是符号链接，跳过: $target_path"
            skipped_count=$((skipped_count + 1))
            return 0
        fi
    fi
    
    # 创建目标目录（如果不存在）
    target_dir=$(dirname "$target_path")
    if [ ! -d "$target_dir" ]; then
        log_info "创建目录: $target_dir"
        mkdir -p "$target_dir"
    fi
    
    # 创建符号链接
    log_info "创建符号链接: $source_path -> $target_path"
    if command ln -s "$source_path" "$target_path" 2>/dev/null; then
        created_count=$((created_count + 1))
        return 0
    else
        log_error "创建符号链接失败: $source_path -> $target_path"
        error_count=$((error_count + 1))
        return 1
    fi
}

log_info "开始更新模型符号链接..."

# 计数器
created_count=0
skipped_count=0
error_count=0

# ============================================
# 在此处添加符号链接，格式：ln -s <源路径> <目标路径>
# 只需复制下面的行，修改路径即可
# ============================================

# 示例：添加新符号链接时，只需复制下面这行并修改路径
# ln -s /.autodl/1c/ec/f7/1cecf7098c7b1f10482b522cdede3fc6 /root/ComfyUI/models/loras/Aura_Phantasy_illu.safetensors

# 当前无待创建的符号链接（含 LTX2.3 Kijai 5 项已在本机正确创建，已从脚本移除）
# 完整模型 ln 列表见 modellink/user_models.json；新增时在下方添加 ln -s 行即可
# 如需添加新的符号链接，请在上方添加 ln -s 命令

# ============================================
# 符号链接列表结束
# ============================================

# 输出统计信息
log_info "符号链接更新完成"
log_info "创建: $created_count 个"
log_info "跳过: $skipped_count 个"
log_info "错误: $error_count 个"

exit 0
