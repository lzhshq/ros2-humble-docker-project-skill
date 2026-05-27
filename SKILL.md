---
name: ros2-humble-docker-project
description: 在 Ubuntu 24.04 主机上一键创建或接入基于 Docker 的 ROS2 Humble 长期开发项目模板，包含 Dockerfile、compose、工作区挂载、GUI、USB/串口/CAN 设备映射、管理脚本和文档。当用户需要新建 ROS2 Humble Docker 项目，或希望把 Docker + ROS2 Humble 环境接入到已有项目目录时使用本 Skill。
---

# ros2-humble-docker-project

> 📖 **完整使用手册**：见 [USAGE.md](./USAGE.md)（含 Docker 权限准备、两种模式详解、日常 workflow、故障排查 12 例、维护与迁移）

## 作用

为 Ubuntu 24.04（或其它无法直接装 ROS2 Humble 的系统）的开发者，一键生成或接入一套**长期可用、可迁移、可复用**的 ROS2 Humble Docker 项目模板。

不是临时跑一个容器，而是一整套项目结构：
- `docker/`：Dockerfile / compose / entrypoint
- `ros2_ws/`：colcon 工作区
- `scripts/`：build / run / enter / stop / clean_ws
- `data/`：数据挂载点
- `README_DOCKER.md`：中文使用说明
- `.env`：项目级配置
- `.gitignore`：ROS2 + Docker 常用忽略项

## 何时使用

当用户出现以下意图之一，应当使用本 Skill：

1. "我在 Ubuntu 24.04 上想用 Docker 跑 ROS2 Humble"
2. "帮我创建一个 ROS2 Humble Docker 项目模板"
3. "把这个已有项目接入 ROS2 Humble Docker 环境"
4. "给我一个长期开发用的 ROS2 容器结构"
5. 用户提到 `init_ros2_humble_docker.sh`、`new` / `attach` 模式

## 两种模式

### 一、new 模式（新建项目）

```bash
bash <skill_dir>/init_ros2_humble_docker.sh new my_robot_project
```

生成全新项目目录 `my_robot_project/`，结构完整，开箱即用。

### 二、attach 模式（接入已有项目）

```bash
cd existing_project
bash <skill_dir>/init_ros2_humble_docker.sh attach
```

在当前目录注入 Docker + ROS2 Humble 环境，**不会破坏用户已有文件**：

| 已有内容 | 行为 |
|---|---|
| `ros2_ws/src/` | 直接使用作为工作区 |
| 仅有 `src/`（无 `ros2_ws/src`） | 把 `src/` 挂载到容器内 `/workspace/ros2_ws/src` |
| 都没有 | 自动创建 `ros2_ws/src/` |
| `docker/` 已存在 | 备份为 `docker.bak_<时间戳>` 后再生成 |
| `scripts/<name>.sh` 已存在 | 跳过该脚本，不覆盖 |
| `.gitignore` 已存在 | 仅追加缺失行，不破坏已有内容 |
| `.env` 已存在 | 不覆盖，提示用户检查 |

## 调用流程（给模型的指引）

当用户请求创建或接入 ROS2 Humble Docker 项目时：

1. 询问或确认：
   - 模式：`new` 还是 `attach`
   - 如果是 `new`，项目名（仅允许字母/数字/下划线/短横线）
   - 目标目录（默认当前工作目录）
2. 找到本 Skill 所在目录中的 `init_ros2_humble_docker.sh`
3. 用 shell 工具执行：
   - `bash <skill_dir>/init_ros2_humble_docker.sh new <name>`
   - 或 `cd <existing_project> && bash <skill_dir>/init_ros2_humble_docker.sh attach`
4. 把脚本输出原样反馈给用户
5. 提示后续命令：
   - `cd <project>`（new 模式）
   - `./scripts/build.sh`
   - `./scripts/run.sh`
6. 如用户希望修改 ROS_DOMAIN_ID、镜像名等，引导其编辑项目根目录 `.env`。
7. 如用户希望增加 apt 依赖，引导其修改 `docker/Dockerfile` 后执行 `./scripts/build.sh`。

## 文件清单

```
ros2-humble-docker-project/
├── SKILL.md                          # 本文件
├── USAGE.md                          # 完整使用手册（推荐先读）
├── init_ros2_humble_docker.sh        # 主入口脚本（new / attach）
└── templates/
    ├── docker/
    │   ├── Dockerfile
    │   ├── compose.yaml
    │   └── entrypoint.sh
    ├── scripts/
    │   ├── build.sh
    │   ├── run.sh
    │   ├── enter.sh
    │   ├── stop.sh
    │   └── clean_ws.sh
    ├── README_DOCKER.md
    ├── env.template
    └── gitignore.template
```

## 安全约束

- 不得直接覆盖用户已有 `docker/`、`scripts/*.sh`、`.gitignore`、`.env`、`README_DOCKER.md`
- 不得删除用户源码（`src/` / `ros2_ws/src/`）
- `clean_ws.sh` 只清理 `ros2_ws/{build,install,log}`
- 所有路径使用相对路径，不写死任何用户名
- Docker compose 命令统一使用新版 `docker compose`，不使用旧版 `docker-compose`

## 后续可扩展方向

- 自动创建 ROS2 package（`ros2 pkg create` 包装）
- 自动初始化 `bringup` / `description` / `interfaces` 三件套
- 加入 Gazebo / Ignition / MuJoCo 仿真层
- 加入 CAN / SocketCAN 调试模板
- 加入 VS Code `.devcontainer` 集成
- 增加 nvidia-runtime / `--gpus all` 选项分支
- 容器内创建非 root 用户（与宿主 UID 对齐，解决文件 ownership 问题）
- 多机房部署模板（不同 `ROS_DOMAIN_ID` 配置 profile）
