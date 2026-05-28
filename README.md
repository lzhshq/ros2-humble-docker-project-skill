# ros2-humble-docker-project

[![Skill Format](https://img.shields.io/badge/format-Claude%20Skill-blue)](#)
[![ROS 2](https://img.shields.io/badge/ROS%202-Humble-22314e)](https://docs.ros.org/en/humble/)
[![Base Image](https://img.shields.io/badge/base-osrf%2Fros%3Ahumble--desktop-2496ed)](https://hub.docker.com/r/osrf/ros)
[![Host OS](https://img.shields.io/badge/host-any%20Docker%20host-orange)](#)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](./LICENSE)

> One-shot **Claude skill** that scaffolds or attaches a **Docker-based ROS 2 Humble** development environment for **long-term** robotics projects on any host that has Docker — Linux (Ubuntu, Fedora, Arch…), macOS, or Windows/WSL2.

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

支持两种模式（由 AI 自动选择，你只要描述需求）：

| 模式 | 适用 |
|---|---|
| **`new`** | 全新项目 |
| **`attach`** | 已有源码，想加 Docker 化开发环境 |

`attach` 模式的核心承诺：**绝不破坏用户已有内容**。详细行为表见 [references/USAGE.md §7](./references/USAGE.md#7-attach-模式详解)。

---

## 一键安装

让 AI agent（Kiro / Cursor / Claude Code 等）能"看到"这个 skill 并自动触发。**装一次，以后只用对 AI 说话**：

```bash
curl -fsSL https://raw.githubusercontent.com/lzhshq/ros2-humble-docker-project-skill/main/install.sh | bash
```

安装脚本做的事：

1. clone 仓库到 `~/.local/share/agent-skills/ros2-humble-docker-project`
2. **自动探测**已有的 agent skill 目录（`~/.kiro/skills`、`~/.cursor/skills`、`~/.claude/skills`、`~/.config/claude/skills`），把 skill **软链**进去
3. 如果都不存在，默认创建 `~/.kiro/skills`
4. 幂等：重复执行只会更新仓库，不会破坏已有链接

装完后，**完全不用碰命令行**，直接在 AI 对话框里说：

> "在当前目录加 ROS2 Humble 的 Docker 环境"
> "帮我新建一个叫 `my_robot` 的 ROS2 项目"
> "我电脑是 Fedora，用 Docker 跑 ROS2 Humble"

AI 会自动调用 skill 完成模板生成、构建、进容器、编译……整个流程你只要回答它的几个确认问题。

**更新**：再跑一次同一条 `curl ... | bash` 即可（幂等）。

**卸载**：

```bash
curl -fsSL https://raw.githubusercontent.com/lzhshq/ros2-humble-docker-project-skill/main/uninstall.sh | bash
```

<details>
<summary>高级：自定义安装位置（可选）</summary>

```bash
# 改安装路径
SKILL_INSTALL_DIR=$HOME/dev/skills/ros2-humble-docker-project \
    bash <(curl -fsSL https://raw.githubusercontent.com/lzhshq/ros2-humble-docker-project-skill/main/install.sh)

# 只装到指定 agent
SKILL_TARGET_DIRS="$HOME/.cursor/skills" \
    bash <(curl -fsSL https://raw.githubusercontent.com/lzhshq/ros2-humble-docker-project-skill/main/install.sh)

# 强制重装
SKILL_FORCE=1 \
    bash <(curl -fsSL https://raw.githubusercontent.com/lzhshq/ros2-humble-docker-project-skill/main/install.sh)
```

</details>

详细使用说明、故障排查 12 例、维护与迁移见 **[references/USAGE.md](./references/USAGE.md)**。

---

## 文档

| 文件 | 用途 |
|---|---|
| [`SKILL.md`](./SKILL.md) | Claude Skill 元信息 + 调用流程 |
| [`references/USAGE.md`](./references/USAGE.md) | 完整使用手册（**首选阅读**，16 章） |
| `assets/templates/README_DOCKER.md` | 每个生成的项目里都会有一份的中文项目级说明（17 节） |

---

## 项目结构

```
ros2-humble-docker-project/
├── SKILL.md                          # Skill 元信息
├── README.md                         # 本文件
├── LICENSE                           # MIT
├── install.sh                        # 一键安装（curl | bash）
├── uninstall.sh                      # 一键卸载
├── scripts/
│   └── init_ros2_humble_docker.sh    # 主入口脚本
├── references/
│   └── USAGE.md                      # 完整使用手册
├── assets/
│   └── templates/
│       ├── docker/{Dockerfile, compose.yaml, entrypoint.sh}
│       ├── scripts/{build, run, enter, stop, clean_ws}.sh
│       ├── README_DOCKER.md
│       ├── env.template
│       └── gitignore.template
└── evals/
    └── evals.json                    # 触发测试用例
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

扩展方向（GPU / 非 root 用户 / Gazebo / VS Code devcontainer / CI 离线镜像 等）见 [references/USAGE.md §16](./references/USAGE.md#16-扩展方向)。

---

## License

[MIT](./LICENSE) © 2026 lzhshq
