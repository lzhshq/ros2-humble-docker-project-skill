#!/usr/bin/env bash
# =============================================================================
# uninstall.sh — Remove ros2-humble-docker-project skill
# =============================================================================
set -euo pipefail

SKILL_NAME="ros2-humble-docker-project"
SKILL_INSTALL_DIR="${SKILL_INSTALL_DIR:-$HOME/.local/share/agent-skills/$SKILL_NAME}"

if [ -t 1 ]; then
    C_RESET="\033[0m"; C_GREEN="\033[1;32m"; C_YELLOW="\033[1;33m"
else
    C_RESET=""; C_GREEN=""; C_YELLOW=""
fi
log()  { printf "%b[INFO]%b  %s\n" "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf "%b[WARN]%b  %s\n" "$C_YELLOW" "$C_RESET" "$*"; }

candidates=(
    "$HOME/.kiro/skills/$SKILL_NAME"
    "$HOME/.cursor/skills/$SKILL_NAME"
    "$HOME/.claude/skills/$SKILL_NAME"
    "$HOME/.config/claude/skills/$SKILL_NAME"
)
for p in "${candidates[@]}"; do
    if [ -L "$p" ] || [ -e "$p" ]; then
        rm -rf "$p"
        log "已删除链接/目录: $p"
    fi
done

if [ -d "$SKILL_INSTALL_DIR" ]; then
    rm -rf "$SKILL_INSTALL_DIR"
    log "已删除安装目录: $SKILL_INSTALL_DIR"
else
    warn "安装目录不存在: $SKILL_INSTALL_DIR"
fi

log "卸载完成"
