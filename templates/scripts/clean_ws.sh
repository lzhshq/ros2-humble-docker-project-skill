#!/usr/bin/env bash
# scripts/clean_ws.sh —— 清理 ROS2 colcon 编译产物
# 安全约束：只删 build/ install/ log/，绝不动 src/
set -euo pipefail

PROJECT_ROOT="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
cd "$PROJECT_ROOT"

WS_DIR="${PROJECT_ROOT}/ros2_ws"

if [ ! -d "$WS_DIR" ]; then
    echo "[clean_ws] 未找到 ros2_ws/，无需清理。"
    exit 0
fi

removed_any=0
for d in build install log; do
    target="${WS_DIR}/${d}"
    if [ -d "$target" ]; then
        echo "[clean_ws] 删除 ${target}"
        rm -rf "$target"
        removed_any=1
    fi
done

if [ "$removed_any" -eq 0 ]; then
    echo "[clean_ws] 没有需要清理的产物（build/install/log 均不存在）。"
else
    echo "[clean_ws] 完成。源码 src/ 未被触碰。"
fi
