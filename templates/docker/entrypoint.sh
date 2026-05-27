#!/usr/bin/env bash
# ============================================================================
# docker/entrypoint.sh
# 容器入口脚本：
#   1. source /opt/ros/humble/setup.bash
#   2. 若存在工作区 install/setup.bash，则 source 之
#   3. exec "$@"
# ============================================================================
set -e

# 1) source ROS2 base
if [ -f /opt/ros/humble/setup.bash ]; then
    # shellcheck disable=SC1091
    source /opt/ros/humble/setup.bash
fi

# 2) source workspace overlay（若已 colcon build 过）
if [ -f /workspace/ros2_ws/install/setup.bash ]; then
    # shellcheck disable=SC1091
    source /workspace/ros2_ws/install/setup.bash
fi

# 3) ROS_DOMAIN_ID 兜底
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_fastrtps_cpp}"

exec "$@"
