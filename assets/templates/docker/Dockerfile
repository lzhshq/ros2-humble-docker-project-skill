## ===========================================================================
## ROS2 Humble Docker image for long-term development on Ubuntu 24.04 hosts.
## Base: osrf/ros:humble-desktop  (Ubuntu 22.04 + ROS2 Humble desktop)
## ===========================================================================
FROM osrf/ros:humble-desktop

ARG DEBIAN_FRONTEND=noninteractive

## 基础工具 + ROS2 开发依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3-pip \
        python3-colcon-common-extensions \
        python3-rosdep \
        python3-vcstool \
        python3-serial \
        git \
        nano \
        vim \
        tmux \
        htop \
        net-tools \
        iputils-ping \
        usbutils \
        can-utils \
        sudo \
        locales \
        ca-certificates \
        wget \
        curl \
        ros-humble-rviz2 \
        ros-humble-rqt \
        ros-humble-rqt-common-plugins \
        ros-humble-xacro \
        ros-humble-robot-state-publisher \
        ros-humble-joint-state-publisher \
        ros-humble-joint-state-publisher-gui \
        ros-humble-demo-nodes-cpp \
        ros-humble-demo-nodes-py \
    && rm -rf /var/lib/apt/lists/*

## locale（避免某些 ROS2 工具 locale warning）
RUN locale-gen en_US en_US.UTF-8 \
 && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

## rosdep（osrf 镜像里通常已 init 过；update 失败不致命）
RUN rosdep update 2>/dev/null || true

## 在 root 的 bashrc 中自动 source ROS2 环境
## 这样 `docker exec -it ... bash` 进入时也带上环境
RUN { \
        echo "source /opt/ros/humble/setup.bash"; \
        echo "[ -f /workspace/ros2_ws/install/setup.bash ] && source /workspace/ros2_ws/install/setup.bash"; \
        echo "export ROS_DOMAIN_ID=\${ROS_DOMAIN_ID:-0}"; \
        echo "cd /workspace/ros2_ws"; \
    } >> /root/.bashrc

## 工作目录
WORKDIR /workspace/ros2_ws

## 入口脚本
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
