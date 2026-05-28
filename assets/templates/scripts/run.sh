#!/usr/bin/env bash
# scripts/run.sh —— 启动容器并进入
set -euo pipefail

PROJECT_ROOT="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
cd "$PROJECT_ROOT"

if [ ! -f .env ]; then
    echo "[run] 未找到 .env，请先运行 init_ros2_humble_docker.sh" >&2
    exit 1
fi

# 加载 .env 中的变量到当前 shell（用于 CONTAINER_NAME 等）
set -a
# shellcheck disable=SC1091
source .env
set +a

CONTAINER_NAME="${CONTAINER_NAME:-ros2_humble_dev}"

# 允许容器访问 X server（GUI: rviz2 / rqt）
if command -v xhost >/dev/null 2>&1; then
    xhost +local:docker >/dev/null 2>&1 || true
    xhost +local:root   >/dev/null 2>&1 || true
fi

echo "[run] 启动容器: ${CONTAINER_NAME}"
docker compose -f docker/compose.yaml --env-file .env up -d

echo "[run] 进入容器: ${CONTAINER_NAME}"
docker exec -it "${CONTAINER_NAME}" bash
