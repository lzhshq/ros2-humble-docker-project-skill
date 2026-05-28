#!/usr/bin/env bash
# =============================================================================
# install.sh — One-line installer for ros2-humble-docker-project skill
#
# Usage (any of these):
#
#   # Recommended (no git needed on the user's machine):
#   curl -fsSL https://raw.githubusercontent.com/lzhshq/ros2-humble-docker-project-skill/main/install.sh | bash
#
#   # If GitHub is unstable for you (e.g., from China mainland), try jsDelivr:
#   curl -fsSL https://cdn.jsdelivr.net/gh/lzhshq/ros2-humble-docker-project-skill@main/install.sh | bash
#   # …and if `git clone github.com` is also blocked, override the repo URL:
#   curl -fsSL https://cdn.jsdelivr.net/gh/lzhshq/ros2-humble-docker-project-skill@main/install.sh | \
#       SKILL_REPO=https://ghproxy.com/https://github.com/lzhshq/ros2-humble-docker-project-skill.git bash
#
#   # Explicit branch / tag:
#   curl -fsSL https://raw.githubusercontent.com/lzhshq/ros2-humble-docker-project-skill/main/install.sh \
#       | SKILL_REF=main bash
#
#   # If you've already cloned the repo locally:
#   bash install.sh
#
# Environment variables (all optional):
#   SKILL_INSTALL_DIR   Where the repo lives on disk.
#                       Default: $HOME/.local/share/agent-skills/ros2-humble-docker-project
#   SKILL_TARGET_DIRS   Space-separated list of agent skill dirs to symlink into.
#                       Default: auto-detect from
#                         ~/.kiro/skills  ~/.cursor/skills  ~/.claude/skills
#                         ~/.config/claude/skills
#                       If none exist, ~/.kiro/skills is created.
#   SKILL_REF           Git ref / branch / tag (default: main)
#   SKILL_REPO          Git repo URL (override only if you fork it)
#                       Default: https://github.com/lzhshq/ros2-humble-docker-project-skill.git
#   SKILL_TARBALL_URL   Tarball URL used when git is unavailable
#                       Default: https://codeload.github.com/lzhshq/ros2-humble-docker-project-skill/tar.gz/$SKILL_REF
#   SKILL_FORCE         "1" to force re-download (delete existing install dir first)
# =============================================================================

set -euo pipefail

# ---------- defaults ----------
SKILL_NAME="ros2-humble-docker-project"
SKILL_REPO_DEFAULT="https://github.com/lzhshq/ros2-humble-docker-project-skill.git"
SKILL_REF="${SKILL_REF:-main}"
SKILL_REPO="${SKILL_REPO:-$SKILL_REPO_DEFAULT}"
SKILL_TARBALL_URL="${SKILL_TARBALL_URL:-https://codeload.github.com/lzhshq/ros2-humble-docker-project-skill/tar.gz/${SKILL_REF}}"
SKILL_INSTALL_DIR_DEFAULT="${HOME}/.local/share/agent-skills/${SKILL_NAME}"
SKILL_INSTALL_DIR="${SKILL_INSTALL_DIR:-$SKILL_INSTALL_DIR_DEFAULT}"
SKILL_FORCE="${SKILL_FORCE:-0}"

# ---------- pretty logging ----------
if [ -t 1 ]; then
    C_RESET="\033[0m"; C_GREEN="\033[1;32m"; C_YELLOW="\033[1;33m"; C_RED="\033[1;31m"; C_CYAN="\033[1;36m"; C_DIM="\033[2m"
else
    C_RESET=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_CYAN=""; C_DIM=""
fi
log()  { printf "%b[INFO]%b  %s\n" "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf "%b[WARN]%b  %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
err()  { printf "%b[ERROR]%b %s\n" "$C_RED"    "$C_RESET" "$*" >&2; }
note() { printf "%b[NEXT]%b  %s\n" "$C_CYAN"   "$C_RESET" "$*"; }
dim()  { printf "%b%s%b\n"        "$C_DIM"    "$*"      "$C_RESET"; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---------- 1) fetch / update repo ----------
fetch_repo() {
    if [ "$SKILL_FORCE" = "1" ] && [ -e "$SKILL_INSTALL_DIR" ]; then
        warn "SKILL_FORCE=1, removing $SKILL_INSTALL_DIR"
        rm -rf "$SKILL_INSTALL_DIR"
    fi

    mkdir -p "$(dirname "$SKILL_INSTALL_DIR")"

    if [ -d "$SKILL_INSTALL_DIR/.git" ]; then
        log "已存在仓库, 更新到最新: $SKILL_INSTALL_DIR"
        if ! have git; then
            warn "本地仓库存在但系统没有 git, 跳过更新（如需更新请安装 git 或设 SKILL_FORCE=1 重装）"
        else
            git -C "$SKILL_INSTALL_DIR" fetch --depth 1 origin "$SKILL_REF" || {
                warn "git fetch 失败, 继续使用现有版本"
                return 0
            }
            git -C "$SKILL_INSTALL_DIR" checkout -q "$SKILL_REF" || true
            git -C "$SKILL_INSTALL_DIR" reset --hard "origin/$SKILL_REF" 2>/dev/null \
                || git -C "$SKILL_INSTALL_DIR" reset --hard "$SKILL_REF" 2>/dev/null \
                || true
        fi
        return 0
    fi

    if [ -e "$SKILL_INSTALL_DIR" ]; then
        err "目标已存在但不是 git 仓库: $SKILL_INSTALL_DIR"
        err "请删除它或设 SKILL_FORCE=1 后重试。"
        exit 1
    fi

    if have git; then
        log "用 git 克隆: $SKILL_REPO ($SKILL_REF) -> $SKILL_INSTALL_DIR"
        git clone --depth 1 --branch "$SKILL_REF" "$SKILL_REPO" "$SKILL_INSTALL_DIR"
    else
        warn "系统未安装 git, 改用 tarball 下载: $SKILL_TARBALL_URL"
        local tmpdir
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        if have curl; then
            curl -fsSL "$SKILL_TARBALL_URL" -o "$tmpdir/skill.tar.gz"
        elif have wget; then
            wget -q "$SKILL_TARBALL_URL" -O "$tmpdir/skill.tar.gz"
        else
            err "需要 git 或 curl 或 wget 之一"
            exit 1
        fi
        if ! have tar; then
            err "需要 tar 命令来解压"
            exit 1
        fi
        mkdir -p "$SKILL_INSTALL_DIR"
        tar -xzf "$tmpdir/skill.tar.gz" -C "$tmpdir"
        # 解压后通常是 <repo>-<ref>/ 这一层目录
        local extracted
        extracted="$(find "$tmpdir" -maxdepth 1 -mindepth 1 -type d ! -name "$(basename "$SKILL_INSTALL_DIR")" | head -n1)"
        if [ -z "$extracted" ]; then
            err "解压失败: 找不到顶层目录"
            exit 1
        fi
        cp -a "$extracted"/. "$SKILL_INSTALL_DIR"/
    fi
}

# ---------- 2) detect target skill dirs ----------
detect_targets() {
    if [ -n "${SKILL_TARGET_DIRS:-}" ]; then
        echo "$SKILL_TARGET_DIRS"
        return 0
    fi
    local candidates=(
        "$HOME/.kiro/skills"
        "$HOME/.cursor/skills"
        "$HOME/.claude/skills"
        "$HOME/.config/claude/skills"
    )
    local found=()
    local d
    for d in "${candidates[@]}"; do
        if [ -d "$d" ]; then
            found+=("$d")
        fi
    done
    if [ "${#found[@]}" -eq 0 ]; then
        # 默认创建 Kiro 的位置
        mkdir -p "$HOME/.kiro/skills"
        found+=("$HOME/.kiro/skills")
    fi
    printf '%s\n' "${found[@]}"
}

# ---------- 3) symlink skill into each target dir ----------
link_into() {
    local target_dir="$1"
    local link_path="$target_dir/$SKILL_NAME"

    mkdir -p "$target_dir"

    if [ -L "$link_path" ]; then
        local current
        current="$(readlink "$link_path")"
        if [ "$current" = "$SKILL_INSTALL_DIR" ]; then
            log "已链接（跳过）: $link_path -> $current"
            return 0
        fi
        warn "已有不同链接, 覆盖: $link_path ($current -> $SKILL_INSTALL_DIR)"
        rm -f "$link_path"
    elif [ -e "$link_path" ]; then
        warn "目标位置已有真实目录/文件, 备份: $link_path -> ${link_path}.bak_$(date +%Y%m%d_%H%M%S)"
        mv "$link_path" "${link_path}.bak_$(date +%Y%m%d_%H%M%S)"
    fi

    ln -s "$SKILL_INSTALL_DIR" "$link_path"
    log "已链接: $link_path -> $SKILL_INSTALL_DIR"
}

# ---------- 4) sanity checks ----------
verify_install() {
    local must_have=(
        "$SKILL_INSTALL_DIR/SKILL.md"
        "$SKILL_INSTALL_DIR/scripts/init_ros2_humble_docker.sh"
        "$SKILL_INSTALL_DIR/assets/templates/docker/Dockerfile"
    )
    local f
    for f in "${must_have[@]}"; do
        if [ ! -e "$f" ]; then
            err "安装校验失败, 缺少: $f"
            exit 1
        fi
    done
    chmod +x "$SKILL_INSTALL_DIR/scripts/init_ros2_humble_docker.sh" 2>/dev/null || true
}

# ---------- main ----------
main() {
    log "安装 skill: $SKILL_NAME"
    dim   "  install dir : $SKILL_INSTALL_DIR"
    dim   "  repo        : $SKILL_REPO"
    dim   "  ref         : $SKILL_REF"

    fetch_repo
    verify_install

    local targets
    targets="$(detect_targets)"
    log "目标 skill 目录:"
    while IFS= read -r d; do
        [ -z "$d" ] && continue
        dim "  - $d"
    done <<< "$targets"

    while IFS= read -r d; do
        [ -z "$d" ] && continue
        link_into "$d"
    done <<< "$targets"

    echo
    printf "%b===========================================================%b\n" "$C_GREEN" "$C_RESET"
    log "安装完成"
    printf "%b===========================================================%b\n" "$C_GREEN" "$C_RESET"
    note "现在你可以直接在 AI agent 里说:"
    note "  \"在当前目录加 ROS2 Humble 的 Docker 环境\""
    note "  \"帮我新建一个叫 my_robot 的 ROS2 项目\""
    echo
    note "也可以直接用 CLI:"
    note "  bash $SKILL_INSTALL_DIR/scripts/init_ros2_humble_docker.sh attach"
    note "  bash $SKILL_INSTALL_DIR/scripts/init_ros2_humble_docker.sh new my_robot"
    echo
    dim   "卸载: rm -f ~/.kiro/skills/$SKILL_NAME ~/.cursor/skills/$SKILL_NAME ~/.claude/skills/$SKILL_NAME ~/.config/claude/skills/$SKILL_NAME && rm -rf $SKILL_INSTALL_DIR"
}

main "$@"
