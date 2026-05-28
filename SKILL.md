---
name: ros2-humble-docker-project
description: >
  Scaffold or attach a complete Docker-based ROS 2 Humble development environment
  for long-term robotics projects on any host OS (Linux, macOS, Windows/WSL2).
  Generates Dockerfile, compose.yaml, entrypoint, management scripts
  (build/run/enter/stop/clean), .env config, and documentation in one shot.
  Use this skill whenever the user mentions: ROS2 Humble in Docker, containerized
  colcon workspace, ROS2 container with GUI (rviz2/rqt), USB/serial/CAN device
  passthrough, creating a new ROS2 project template, attaching Docker to an
  existing ROS2 workspace, running Humble on Ubuntu 24.04/23.10/Fedora/Arch/macOS
  where native install is unavailable or undesirable, or any variant of "I need a
  container-based ROS2 Humble dev setup". Also trigger when the user references
  init_ros2_humble_docker.sh, or asks about Docker ROS2 with host networking,
  device access, or X11/Wayland forwarding.
---

# ros2-humble-docker-project — 执行指引

本 skill 提供一个 bash 脚本 `init_ros2_humble_docker.sh`，一键为用户生成（或接入）一套完整的 ROS2 Humble Docker 开发环境。适用于任何安装了 Docker 的系统（Linux 各发行版、macOS、Windows WSL2）——容器内始终是 Ubuntu 22.04 + ROS2 Humble，与宿主系统无关。

## 调用流程

当用户的意图匹配时，按以下步骤执行：

### 1. 确认参数

| 参数 | 如何获取 |
|---|---|
| 模式 | 问用户：新建项目（`new`）还是接入已有项目（`attach`）？ |
| 项目名 | `new` 模式必须提供，仅允许 `[A-Za-z0-9_-]` |
| 目标目录 | `new` 默认在 CWD 下创建子目录；`attach` 默认当前目录 |

如果用户意图明确（如"帮我在当前目录加 ROS2 Docker 环境"），可直接推断模式，无需反复确认。

### 2. 执行脚本

找到本 skill 目录下的 `scripts/init_ros2_humble_docker.sh`，用 shell 工具执行：

```bash
# new 模式
bash <skill_dir>/scripts/init_ros2_humble_docker.sh new <project_name>

# attach 模式
cd <target_dir> && bash <skill_dir>/scripts/init_ros2_humble_docker.sh attach
```

将脚本的 stdout/stderr 原样展示给用户。

### 3. 引导后续操作

脚本成功后，提示用户：

```bash
cd <project>              # new 模式才需要
./scripts/build.sh        # 构建镜像（首次 5-15 分钟）
./scripts/run.sh          # 启动并进入容器
```

容器内首次编译：

```bash
cd /workspace/ros2_ws
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
source install/setup.bash
```

### 4. 常见后续需求的引导

| 用户想做的 | 引导 |
|---|---|
| 改 ROS_DOMAIN_ID / RMW | 编辑项目根 `.env` |
| 加 apt 依赖 | 编辑 `docker/Dockerfile`，重跑 `./scripts/build.sh` |
| 加 pip 依赖 | 同上，在 Dockerfile 加 `RUN pip3 install ...` |
| 多终端进容器 | `./scripts/enter.sh` |
| 清理编译产物 | `./scripts/clean_ws.sh`（只删 build/install/log，不动 src） |
| 停止容器 | `./scripts/stop.sh` |

---

## 两种模式速查

### new — 全新项目

在 CWD 下创建 `<name>/` 目录，包含完整骨架：`docker/`、`ros2_ws/src/`、`scripts/`、`data/`、`.env`、`.gitignore`、`README_DOCKER.md`。

### attach — 接入已有项目

在当前目录注入 Docker 环境，**绝不破坏已有文件**：

- `docker/` 已存在 → 备份为 `docker.bak_<timestamp>` 后再生成
- `scripts/<x>.sh` 已存在 → 跳过不覆盖
- `.gitignore` 已存在 → 仅追加缺失行
- `.env` 已存在 → 不覆盖，提示用户检查
- `ros2_ws/src/` 已存在 → 直接使用
- 仅有 `src/`（无 `ros2_ws/`）→ 把 `src/` 挂载到容器内 `/workspace/ros2_ws/src`

---

## 安全约束

- 不覆盖用户已有的 `docker/`、`scripts/*.sh`、`.gitignore`、`.env`
- 不删除用户源码
- `clean_ws.sh` 只清理 `build/install/log`
- 所有路径使用相对路径，不写死用户名
- 使用 `docker compose`（v2），不使用旧版 `docker-compose`

---

## 前置条件

用户主机需要：Docker Engine 20.10+、Docker Compose v2 插件。Linux 用户需在 docker 组中。
如果用户遇到权限问题，引导执行 `sudo usermod -aG docker $USER && newgrp docker`。

> **GUI 说明**：默认配置通过 X11 socket 直通 GUI（rviz2/rqt），适用于大多数 Linux 桌面。
> Wayland 宿主需确保 XWayland 可用；macOS 需安装 XQuartz；WSL2 需 WSLg。
> 无头服务器可忽略 GUI 相关配置。

---

## 文件清单

```
ros2-humble-docker-project/
├── SKILL.md                          # 本文件
├── README.md                         # 仓库说明
├── LICENSE
├── install.sh                        # 一键安装（curl | bash）
├── uninstall.sh                      # 一键卸载
├── scripts/
│   └── init_ros2_humble_docker.sh    # 主入口脚本
├── references/
│   └── USAGE.md                      # 完整使用手册（故障排查、维护、扩展方向）
├── assets/
│   └── templates/
│       ├── docker/{Dockerfile, compose.yaml, entrypoint.sh}
│       ├── scripts/{build, run, enter, stop, clean_ws}.sh
│       ├── env.template
│       ├── gitignore.template
│       └── README_DOCKER.md
└── evals/
    └── evals.json                    # 触发测试用例
```

> 📖 详细使用说明、故障排查 12 例、维护与迁移见 [references/USAGE.md](./references/USAGE.md)
