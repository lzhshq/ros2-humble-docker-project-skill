#!/usr/bin/env bash
# ============================================================================
# init_ros2_humble_docker.sh
# Skill: ros2-humble-docker-project
#
# 用法:
#   bash init_ros2_humble_docker.sh new <project_name>
#   bash init_ros2_humble_docker.sh attach
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

# ---------- 颜色日志 ----------
if [ -t 1 ]; then
    C_RESET="\033[0m"; C_GREEN="\033[1;32m"; C_YELLOW="\033[1;33m"; C_RED="\033[1;31m"; C_CYAN="\033[1;36m"
else
    C_RESET=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_CYAN=""
fi

log()  { printf "%b[INFO]%b  %s\n" "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf "%b[WARN]%b  %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
err()  { printf "%b[ERROR]%b %s\n" "$C_RED"    "$C_RESET" "$*" >&2; }
note() { printf "%b[NEXT]%b  %s\n" "$C_CYAN"   "$C_RESET" "$*"; }

usage() {
    cat <<EOF
Usage:
  $0 new <project_name>     新建一个完整 ROS2 Humble Docker 项目
  $0 attach                 把 ROS2 Humble Docker 环境接入到当前目录已有项目

示例:
  $0 new my_robot_project
  cd existing_project && $0 attach
EOF
    exit 1
}

# ---------- 工具函数 ----------
validate_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
        err "非法项目名: '$name'"
        err "只允许字母、数字、下划线 (_) 和短横线 (-)。"
        exit 1
    fi
}

require_templates() {
    if [ ! -d "$TEMPLATES_DIR" ]; then
        err "找不到模板目录: $TEMPLATES_DIR"
        err "请确保本脚本与 templates/ 目录处于同一 Skill 根目录下。"
        exit 1
    fi
    local must_have=(
        "docker/Dockerfile"
        "docker/compose.yaml"
        "docker/entrypoint.sh"
        "scripts/build.sh"
        "scripts/run.sh"
        "scripts/enter.sh"
        "scripts/stop.sh"
        "scripts/clean_ws.sh"
        "README_DOCKER.md"
        "env.template"
        "gitignore.template"
    )
    local f
    for f in "${must_have[@]}"; do
        if [ ! -f "$TEMPLATES_DIR/$f" ]; then
            err "模板文件缺失: templates/$f"
            exit 1
        fi
    done
}

substitute_vars() {
    # 在文件中替换 {{PROJECT_NAME}}
    local file="$1"
    local project_name="$2"
    # 用 # 作为分隔符，避免项目名里出现 / 时报错
    sed -i "s#{{PROJECT_NAME}}#${project_name}#g" "$file"
}

backup_path() {
    local path="$1"
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    local backup="${path}.bak_${ts}"
    warn "备份 $path -> $backup"
    mv "$path" "$backup"
}

ensure_dir() {
    local d="$1"
    if [ ! -d "$d" ]; then
        mkdir -p "$d"
    fi
}

copy_template() {
    local rel="$1"
    local dst="$2"
    cp "$TEMPLATES_DIR/$rel" "$dst"
}

# 把 templates/scripts/<name>.sh 拷到目标 scripts/，已有则跳过
copy_script_if_missing() {
    local script_name="$1"
    local target_dir="$2"
    local src="$TEMPLATES_DIR/scripts/${script_name}"
    local dst="${target_dir}/${script_name}"
    if [ -f "$dst" ]; then
        warn "scripts/${script_name} 已存在，跳过（不覆盖）"
    else
        cp "$src" "$dst"
        chmod +x "$dst"
        log "生成 scripts/${script_name}"
    fi
}

# 安装 docker/ 全套模板（处理已存在情况）
install_docker_dir() {
    local target="$1"        # 目标项目根目录
    local extra_volume="$2"  # 形如 "  - ../src:/workspace/ros2_ws/src" 或空
    if [ -d "${target}/docker" ]; then
        backup_path "${target}/docker"
    fi
    mkdir -p "${target}/docker"
    copy_template "docker/Dockerfile"   "${target}/docker/Dockerfile"
    copy_template "docker/compose.yaml" "${target}/docker/compose.yaml"
    copy_template "docker/entrypoint.sh" "${target}/docker/entrypoint.sh"

    if [ -n "$extra_volume" ]; then
        # 用 awk 替换占位行（避免 sed 在多行内容时的转义麻烦）
        local tmp
        tmp="$(mktemp)"
        awk -v repl="$extra_volume" '
            { if ($0 ~ /^[[:space:]]*#[[:space:]]*\{\{EXTRA_VOLUMES\}\}/) print repl; else print $0 }
        ' "${target}/docker/compose.yaml" > "$tmp"
        mv "$tmp" "${target}/docker/compose.yaml"
    else
        # 删除占位行
        sed -i '/{{EXTRA_VOLUMES}}/d' "${target}/docker/compose.yaml"
    fi

    chmod +x "${target}/docker/entrypoint.sh"
    log "生成 docker/Dockerfile, docker/compose.yaml, docker/entrypoint.sh"
}

# .gitignore: 文件存在则只追加缺失行
install_gitignore() {
    local target="$1"
    local src="$TEMPLATES_DIR/gitignore.template"
    local dst="${target}/.gitignore"
    if [ ! -f "$dst" ]; then
        cp "$src" "$dst"
        log "生成 .gitignore"
        return
    fi
    log ".gitignore 已存在，仅追加缺失项"
    local added=0
    # 在文件末尾保证有换行
    if [ -s "$dst" ] && [ "$(tail -c 1 "$dst" | xxd -p)" != "0a" ]; then
        echo "" >> "$dst"
    fi
    local first_append=1
    while IFS= read -r line || [ -n "$line" ]; do
        # 跳过空行
        [ -z "$line" ] && continue
        if ! grep -Fxq -- "$line" "$dst"; then
            if [ "$first_append" -eq 1 ]; then
                echo "" >> "$dst"
                echo "# === appended by ros2-humble-docker-project skill ===" >> "$dst"
                first_append=0
            fi
            echo "$line" >> "$dst"
            added=$((added+1))
        fi
    done < "$src"
    if [ "$added" -gt 0 ]; then
        log "向 .gitignore 追加了 ${added} 行"
    else
        log ".gitignore 已包含全部需要的忽略项，未做修改"
    fi
}

# .env: 不覆盖已存在的
install_env() {
    local target="$1"
    local project_name="$2"
    local dst="${target}/.env"
    if [ -f "$dst" ]; then
        warn ".env 已存在，未覆盖。请确认其中包含 PROJECT_NAME / CONTAINER_NAME / IMAGE_NAME / ROS_DOMAIN_ID 等变量。"
        return
    fi
    cp "$TEMPLATES_DIR/env.template" "$dst"
    substitute_vars "$dst" "$project_name"
    log "生成 .env (PROJECT_NAME=${project_name})"
}

# README_DOCKER.md: 已存在则备份
install_readme() {
    local target="$1"
    local project_name="$2"
    local dst="${target}/README_DOCKER.md"
    if [ -f "$dst" ]; then
        backup_path "$dst"
    fi
    cp "$TEMPLATES_DIR/README_DOCKER.md" "$dst"
    substitute_vars "$dst" "$project_name"
    log "生成 README_DOCKER.md"
}

# ============================================================================
# new 模式
# ============================================================================
do_new() {
    local project_name="$1"
    validate_name "$project_name"
    require_templates

    local target="${PWD}/${project_name}"
    if [ -e "$target" ]; then
        err "目标目录已存在: $target"
        err "请删除/重命名后再试，或改用 attach 模式接入已有项目。"
        exit 1
    fi

    log "新建 ROS2 Humble Docker 项目: ${project_name}"
    mkdir -p "$target"

    # 目录骨架
    ensure_dir "${target}/ros2_ws/src"
    ensure_dir "${target}/data"
    ensure_dir "${target}/scripts"

    # docker/
    install_docker_dir "$target" ""

    # scripts/
    local s
    for s in build.sh run.sh enter.sh stop.sh clean_ws.sh; do
        copy_script_if_missing "$s" "${target}/scripts"
    done

    # README / .env / .gitignore
    install_readme   "$target" "$project_name"
    install_env      "$target" "$project_name"
    install_gitignore "$target"

    # 占位 .gitkeep 以便提交空目录
    : > "${target}/ros2_ws/src/.gitkeep"
    : > "${target}/data/.gitkeep"

    chmod +x "${target}/scripts/"*.sh 2>/dev/null || true

    cat <<EOF

$(printf "%b" "$C_GREEN")===========================================================
[OK] 项目 '${project_name}' 已创建于: ${target}
===========================================================$(printf "%b" "$C_RESET")
EOF

    note "下一步:"
    note "  cd ${project_name}"
    note "  ./scripts/build.sh    # 构建镜像（首次较慢，请耐心）"
    note "  ./scripts/run.sh      # 启动并进入容器"
    note "进入容器后："
    note "  cd /workspace/ros2_ws && colcon build --symlink-install"
    note "  source install/setup.bash"
}

# ============================================================================
# attach 模式
# ============================================================================
do_attach() {
    require_templates
    local target="${PWD}"
    local raw_name
    raw_name="$(basename "$target")"

    # 把目录名清洗为合法 PROJECT_NAME
    local project_name
    project_name="$(echo "$raw_name" | tr -c 'A-Za-z0-9_-' '_' | sed 's/^_*//; s/_*$//')"
    if [ -z "$project_name" ]; then
        project_name="ros2_project"
    fi

    log "把 ROS2 Humble Docker 环境接入当前目录: ${target}"
    log "推断 PROJECT_NAME = ${project_name}"

    # ------ 工作区识别 ------
    local extra_volume=""
    if [ -d "${target}/ros2_ws/src" ]; then
        log "检测到 ros2_ws/src，作为 colcon 工作区"
    elif [ -d "${target}/src" ]; then
        log "检测到 src/（无 ros2_ws/src），将把 src/ 挂载为容器内 /workspace/ros2_ws/src"
        ensure_dir "${target}/ros2_ws"   # 用于持久化 build/install/log
        extra_volume="      - ../src:/workspace/ros2_ws/src"
    else
        log "未检测到工作区，自动创建 ros2_ws/src"
        ensure_dir "${target}/ros2_ws/src"
    fi

    # ------ data ------
    ensure_dir "${target}/data"

    # ------ docker/ ------
    install_docker_dir "$target" "$extra_volume"

    # ------ scripts/ ------
    ensure_dir "${target}/scripts"
    local s
    for s in build.sh run.sh enter.sh stop.sh clean_ws.sh; do
        copy_script_if_missing "$s" "${target}/scripts"
    done
    chmod +x "${target}/scripts/"*.sh 2>/dev/null || true

    # ------ README / .env / .gitignore ------
    install_readme   "$target" "$project_name"
    install_env      "$target" "$project_name"
    install_gitignore "$target"

    cat <<EOF

$(printf "%b" "$C_GREEN")===========================================================
[OK] 当前项目已接入 ROS2 Humble Docker 环境
     项目根: ${target}
===========================================================$(printf "%b" "$C_RESET")
EOF

    note "下一步:"
    note "  ./scripts/build.sh    # 构建镜像"
    note "  ./scripts/run.sh      # 启动并进入容器"

    if [ -n "$extra_volume" ]; then
        warn "提示：当前为 attach + src 模式，src/ 已映射到容器内 /workspace/ros2_ws/src"
        warn "      build/install/log 会写到 ./ros2_ws/ 下，不会污染你的 src/"
    fi
}

# ============================================================================
# 入口
# ============================================================================
main() {
    if [ $# -lt 1 ]; then
        usage
    fi
    local mode="$1"
    case "$mode" in
        new)
            if [ $# -lt 2 ]; then
                err "new 模式需要项目名"
                usage
            fi
            do_new "$2"
            ;;
        attach)
            do_attach
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            err "未知模式: $mode"
            usage
            ;;
    esac
}

main "$@"
