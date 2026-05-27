#!/usr/bin/env bash
# scripts/enter.sh —— 进入已经运行的容器
set -euo pipefail

PROJECT_ROOT="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
cd "$PROJECT_ROOT"

if [ ! -f .env ]; then
    echo "[enter] 未找到 .env" >&2
    exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

CONTAINER_NAME="${CONTAINER_NAME:-ros2_humble_dev}"

# 检查容器是否在运行
if ! docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
    echo "[enter] 容器 '${CONTAINER_NAME}' 未运行，请先执行 ./scripts/run.sh" >&2
    exit 1
fi

# 顺手 xhost（如果你只用 enter.sh 直接进入，不一定运行过 run.sh）
if command -v xhost >/dev/null 2>&1; then
    xhost +local:docker >/dev/null 2>&1 || true
fi

docker exec -it "${CONTAINER_NAME}" bash
