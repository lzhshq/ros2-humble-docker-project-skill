#!/usr/bin/env bash
# scripts/build.sh —— 构建 Docker 镜像
set -euo pipefail

PROJECT_ROOT="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
cd "$PROJECT_ROOT"

if [ ! -f .env ]; then
    echo "[build] 未找到 .env，请先运行 init_ros2_humble_docker.sh" >&2
    exit 1
fi

echo "[build] 项目根: $PROJECT_ROOT"
echo "[build] 开始构建镜像（首次较慢，请耐心）..."
docker compose -f docker/compose.yaml --env-file .env build "$@"
echo "[build] 镜像构建完成。"
