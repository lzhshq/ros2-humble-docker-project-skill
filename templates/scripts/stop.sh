#!/usr/bin/env bash
# scripts/stop.sh —— 停止并移除容器（保留镜像）
set -euo pipefail

PROJECT_ROOT="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
cd "$PROJECT_ROOT"

echo "[stop] 停止容器 ..."
docker compose -f docker/compose.yaml --env-file .env down
echo "[stop] 已停止。"
