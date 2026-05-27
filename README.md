# ros2-humble-docker-project

[![Skill Format](https://img.shields.io/badge/format-Claude%20Skill-blue)](#)
[![ROS 2](https://img.shields.io/badge/ROS%202-Humble-22314e)](https://docs.ros.org/en/humble/)
[![Base Image](https://img.shields.io/badge/base-osrf%2Fros%3Ahumble--desktop-2496ed)](https://hub.docker.com/r/osrf/ros)
[![Host OS](https://img.shields.io/badge/host-Ubuntu%2024.04%20%2F%2022.04-orange)](#)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](./LICENSE)

> One-shot **Claude skill** that scaffolds or attaches a **Docker-based ROS 2 Humble** development environment for **long-term** robotics projects on hosts that can't (or shouldn't) install Humble natively — typically Ubuntu 24.04.

---

## 这是什么

`ros2-humble-docker-project` 是一个 **Claude Skill**，目标是让一个新 / 已有项目**几分钟内**拥有：

- `Dockerfile`（基于 `osrf/ros:humble-desktop`，预装 colcon / rosdep / rviz2 / rqt / can-utils / serial 等开发常用包）
- `compose.yaml`（host 网络 + ipc + privileged + GUI + USB/串口/CAN/摄像头一次配齐）
- `entrypoint.sh`（自动 source ROS2 base + 工作区 overlay）
- `scripts/`（5 个薄包装：`build / run / enter / stop / clean_ws`）
- `.env`（项目级配置：`PROJECT_NAME / ROS_DOMAIN_ID / RMW_IMPLEMENTATION / CONTAINER_NAME / IMAGE_NAME`）
- `README_DOCKER.md`（17 节中文项目级文档）
- `.gitignore`（ROS2 + Docker 常用忽略项）

支持两种模式：

| 模式 | 用法 | 适用 |
|---|---|---|
| **`new`** | `bash init_ros2_humble_docker.sh new <name>` | 全新项目 |
| **`attach`** | `cd <existing_project> && bash init_ros2_humble_docker.sh attach` | 已有源码、想加 Docker 化开发环境 |

`attach` 模式的核心承诺：**绝不破坏用户已有内容**。详细行为表见 [USAGE.md §7](./USAGE.md#7-attach-模式详解)。

---

## 快速开始

```bash
# 1. clone skill
git clone git@github.com:lzhshq/ros2-humble-docker-project-skill-.git ~/ros2-humble-docker-project
chmod +x ~/ros2-humble-docker-project/init_ros2_humble_docker.sh

# 2. 准备 Docker 权限（首次配机器才需要，已配好可跳过）
sudo usermod -aG docker $USER
newgrp docker          # 当前 shell 立即生效

# 3. 接入已有项目（或新建）
cd ~/my_robot_project
bash ~/ros2-humble-docker-project/init_ros2_humble_docker.sh attach
# 或全新：
# bash ~/ros2-humble-docker-project/init_ros2_humble_docker.sh new my_robot_project

# 4. 构建并进入容器
./scripts/build.sh         # 首次较慢（拉镜像 + 装 ROS2 包，约 5–15 分钟）
./scripts/run.sh

# 5. 容器内编译
cd /workspace/ros2_ws
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
source install/setup.bash
ros2 pkg list
```

详细使用说明、故障排查 12 例、维护与迁移见 **[USAGE.md](./USAGE.md)**。

---

## 文档

| 文件 | 用途 |
|---|---|
| [`SKILL.md`](./SKILL.md) | Claude Skill 元信息 + 调用流程 |
| [`USAGE.md`](./USAGE.md) | 完整使用手册（**首选阅读**，994 行 / 16 章 + 2 附录） |
| `templates/README_DOCKER.md` | 每个生成的项目里都会有一份的中文项目级说明（17 节） |

---

## 项目结构

```
ros2-humble-docker-project/
├── SKILL.md                          # Skill 元信息
├── USAGE.md                          # 完整使用手册
├── README.md                         # 本文件
├── LICENSE                           # MIT
├── init_ros2_humble_docker.sh        # 主入口脚本
└── templates/
    ├── docker/{Dockerfile, compose.yaml, entrypoint.sh}
    ├── scripts/{build, run, enter, stop, clean_ws}.sh
    ├── README_DOCKER.md
    ├── env.template
    └── gitignore.template
```

---

## 设计要点

- **长期项目导向**：不是临时跑容器，而是稳定 / 可复用 / 可迁移的项目模板。
- **Bind mount 工作区**：源码改动**实时生效**，无需重建镜像。
- **设备直通**：`/dev:/dev` + `privileged: true` + `dialout/plugdev/video` 组，USB / 串口 / CAN / 摄像头开箱即用。
- **GUI 直通**：X11 socket + `xhost +local:docker` 自动化，rviz2 / rqt 直接可用。
- **`.env` 单一事实源**：项目级配置集中管理，`compose.yaml` 通过 `env_file` 引用。
- **冲突保护**：attach 模式下对 `docker/` / `scripts/<x>.sh` / `.gitignore` / `.env` / `README_DOCKER.md` 全套保护（备份 / skip / append-only / 不覆盖）。
- **不写死用户名 / 路径**：所有脚本通过 `BASH_SOURCE` 自检 PROJECT_ROOT；compose 用 `..` 相对路径。

---

## 已知不做

- 不创建 ROS2 package（`ros2 pkg create` 已经够好用）
- 不写业务代码
- 不替你装 GPU 驱动 / `nvidia-container-toolkit`
- 不替你拉起 SocketCAN 接口（内核操作必须在宿主跑）

扩展方向（GPU / 非 root 用户 / Gazebo / VS Code devcontainer / CI 离线镜像 等）见 [USAGE.md §16](./USAGE.md#16-扩展方向)。

---

## License

[MIT](./LICENSE) © 2026 lzhshq
