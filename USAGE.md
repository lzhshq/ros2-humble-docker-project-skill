# ros2-humble-docker-project — 使用说明

> 这份文档是 `ros2-humble-docker-project` skill 的**完整使用手册**。比每个项目里生成的 `README_DOCKER.md` 更上一层：它讲的是 **skill 本身怎么装、怎么用、Docker 怎么准备、踩了坑怎么修**。
>
> 如果你只是想用一个已经接入了 skill 的项目，看那个项目下的 `README_DOCKER.md` 就够了。
> 如果你要给一个新项目接入或想理解整个机制，请读本文。

---

## 目录

1. [背景与定位](#1-背景与定位)
2. [前置条件](#2-前置条件)
3. [Docker 权限准备（关键）](#3-docker-权限准备关键)
4. [Skill 的安装与目录布局](#4-skill-的安装与目录布局)
5. [两种使用模式概览](#5-两种使用模式概览)
6. [`new` 模式详解](#6-new-模式详解)
7. [`attach` 模式详解](#7-attach-模式详解)
8. [生成产物逐项说明](#8-生成产物逐项说明)
9. [日常工作流：build / run / enter / stop / clean_ws](#9-日常工作流build--run--enter--stop--clean_ws)
10. [容器内开发 ROS2 包](#10-容器内开发-ros2-包)
11. [设备 / GUI / 网络](#11-设备--gui--网络)
12. [`.env` 调优](#12-env-调优)
13. [修改 Dockerfile 与依赖管理](#13-修改-dockerfile-与依赖管理)
14. [故障排查（含真实案例）](#14-故障排查含真实案例)
15. [维护：升级、清理、备份、迁移](#15-维护升级清理备份迁移)
16. [扩展方向](#16-扩展方向)

---

## 1. 背景与定位

### 1.1 解决什么问题

ROS2 Humble 是 LTS 版本，但官方主要适配 **Ubuntu 22.04**。在 Ubuntu 24.04 上直接 `apt install ros-humble-*` 通常会出现：

- 22.04 jammy 的 ROS2 仓库不能简单移植到 24.04 noble
- Python 3.12 与 Humble 的若干 setup.py / ament 工具链不兼容
- 个别二进制包链接失败、动态库版本错位

因此 24.04 用户的标准做法是：**主机保持纯净，所有 Humble 开发都跑在 Docker 容器里**。

### 1.2 这个 skill 不只是“跑一个容器”

容器命令网上一搜一大把，但**长期项目开发**需要的是一整套**目录结构 + 配置 + 管理脚本 + 文档**：

- 工作区源码必须 bind mount，**改完代码立刻生效**，不重建镜像
- 数据、build 产物各有归属，互不污染
- USB / 串口 / CAN / 摄像头 / GUI 一次配齐，不再每次复制粘贴一长串 `--device`
- 多终端调试时进入的是**同一个**容器
- `.env` 把项目参数集中管理，迁移到别的机器只需改这一个文件

这个 skill 的目的就是**一键生成或接入这套结构**，让一个新项目从零到能 `colcon build` 只需几分钟。

### 1.3 这个 skill 不做什么

- 不创建 ROS2 package（这件事 `ros2 pkg create` 已经够好用）
- 不写业务代码
- 不替你装 GPU 驱动 / nvidia-container-toolkit
- 不替你拉起 SocketCAN 接口（需要内核操作，必须在宿主跑）

---

## 2. 前置条件

| 组件 | 最低要求 | 验证命令 |
|---|---|---|
| 操作系统 | Linux（推荐 Ubuntu 22.04 / 24.04） | `uname -a` |
| Bash | 4.0+ | `bash --version` |
| Docker Engine | 20.10+ | `docker --version` |
| Docker Compose 插件 | v2+（即 `docker compose`，不是旧 `docker-compose`） | `docker compose version` |
| 磁盘空间 | 至少 10 GB（镜像 + 你的工作区） | `df -h /` |

> **如果还没装 Docker**：
> ```bash
> # Ubuntu 24.04 官方仓库（推荐）
> sudo apt-get update
> sudo apt-get install -y docker.io docker-compose-v2
> sudo systemctl enable --now docker
> ```
> 或者按 [docs.docker.com/engine/install](https://docs.docker.com/engine/install/) 装官方源。

---

## 3. Docker 权限准备（关键）

### 3.1 把当前用户加进 `docker` 组

第一次装完 Docker 后，普通用户跑 `docker ps` 会得到：

```
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
```

因为 `/var/run/docker.sock` 属于 `root:docker`，权限 `srw-rw----`。修复：

```bash
sudo usermod -aG docker $USER
```

### 3.2 让组成员关系**当前 shell 立即生效**（最容易踩的坑）

`usermod` 之后，**已经打开的所有 shell 都不会自动获得新组**——因为 Linux 进程的组列表是它启动时由父进程传下来的，运行期不会重新查询 `/etc/group`。这意味着：

- 你**关掉当前终端窗口再开新窗口** → 仍然不行（GNOME Terminal 共用一个 `gnome-terminal-server` 守护进程，新窗口是它的子进程，继承的还是登录时的组列表）
- 必须 **完全注销并重新登录 GUI 会话**，或用 `newgrp docker`

**当下立即生效的办法**：

```bash
newgrp docker          # 进入一个新 sub-shell，组列表已含 docker
groups                 # 确认能看到 docker
```

注意 `newgrp` 进入的是 **sub-shell**，`exit` 后会回到没有 docker 组的旧 shell。要永久生效，登录会话级注销重登一次即可。

### 3.3 安全权衡

`docker` 组成员**事实上等同于 root**：可以启动特权容器、挂载宿主任意路径、读取宿主文件系统。这是单机开发机的标准做法，但不要在多人共用的服务器上随便加人进 docker 组。

### 3.4 验证

```bash
docker run --rm hello-world
```

打印 `Hello from Docker!` 即代表整套（守护进程 + socket 权限 + 网络）都 OK。

---

## 4. Skill 的安装与目录布局

### 4.1 安装位置

Skill 本身就是一个目录。你可以放在任何地方，常见三个位置：

| 位置 | 适用场景 |
|---|---|
| `~/ros2-humble-docker-project/` | 个人开发机，最简单 |
| `~/.claude/skills/ros2-humble-docker-project/` | Claude / Anthropic 工具链规范位置 |
| 团队共享 git 仓库 | 多人协作，clone 后用 |

下文统一假设安装在 `~/ros2-humble-docker-project/`。

### 4.2 目录布局

```
ros2-humble-docker-project/
├── SKILL.md                          # 元信息（YAML frontmatter + 描述）
├── USAGE.md                          # 本文件
├── init_ros2_humble_docker.sh        # 主入口脚本（new / attach）
└── templates/
    ├── docker/
    │   ├── Dockerfile                # 镜像定义
    │   ├── compose.yaml              # docker compose 配置
    │   └── entrypoint.sh             # 容器入口
    ├── scripts/
    │   ├── build.sh                  # 构建镜像
    │   ├── run.sh                    # 启动并进入容器
    │   ├── enter.sh                  # 进入已运行容器
    │   ├── stop.sh                   # 停止并移除容器
    │   └── clean_ws.sh               # 清理 colcon 产物（不动 src/）
    ├── README_DOCKER.md              # 项目级中文说明（17 节）
    ├── env.template                  # .env 模板
    └── gitignore.template            # .gitignore 模板
```

### 4.3 给入口脚本可执行权限

```bash
chmod +x ~/ros2-humble-docker-project/init_ros2_humble_docker.sh
chmod +x ~/ros2-humble-docker-project/templates/docker/entrypoint.sh
chmod +x ~/ros2-humble-docker-project/templates/scripts/*.sh
```

> 仓库克隆方式安装的话，文件权限取决于 git 配置，必要时手动 chmod。

### 4.4 验证

```bash
bash ~/ros2-humble-docker-project/init_ros2_humble_docker.sh --help
```

应当看到 new / attach 用法说明。

---

## 5. 两种使用模式概览

| | **`new` 模式** | **`attach` 模式** |
|---|---|---|
| 命令 | `bash init_ros2_humble_docker.sh new <name>` | `cd <existing_project> && bash init_ros2_humble_docker.sh attach` |
| 适用 | 全新项目 | 已有源码、想加 Docker 化开发环境 |
| 目标目录 | 新建 `<name>/` 子目录 | 当前目录 |
| 工作区 | 必然新建空 `ros2_ws/src/` | 智能识别（详见 §7） |
| 冲突保护 | 不需要（目录是新的） | 全套备份 / skip / append（详见 §7） |
| 用户源码 | 无 | **绝不删除、绝不移动** |

---

## 6. `new` 模式详解

### 6.1 命令

```bash
bash ~/ros2-humble-docker-project/init_ros2_humble_docker.sh new my_robot_project
```

### 6.2 项目名规则

只允许 `[A-Za-z0-9_-]`，否则报错退出。例：

```bash
# ✅ 合法
bash init_... new my_robot
bash init_... new robot-v2
bash init_... new robot_arm_2024

# ❌ 非法
bash init_... new "my robot"     # 含空格
bash init_... new robot.v2       # 含点
bash init_... new 机器人          # 含中文
```

项目名会被同时用作：

- 目录名：`my_robot_project/`
- `.env` 中 `PROJECT_NAME=my_robot_project`
- `.env` 中 `CONTAINER_NAME=my_robot_project_ros2_humble`
- `.env` 中 `IMAGE_NAME=esd/my_robot_project_ros2_humble:latest`

> `IMAGE_NAME` 默认前缀是 `esd/`（见 `templates/env.template`），是命名前缀不是真实 docker registry 账号，可在 `.env` 里随便改。

### 6.3 生成结构

```
my_robot_project/
├── docker/
│   ├── Dockerfile
│   ├── compose.yaml
│   └── entrypoint.sh
├── ros2_ws/
│   └── src/
│       └── .gitkeep
├── scripts/
│   ├── build.sh
│   ├── run.sh
│   ├── enter.sh
│   ├── stop.sh
│   └── clean_ws.sh
├── data/
│   └── .gitkeep
├── README_DOCKER.md
├── .env
└── .gitignore
```

### 6.4 之后做什么

```bash
cd my_robot_project
./scripts/build.sh           # 首次较慢
./scripts/run.sh             # 启动并进入容器
# 容器内：写 / 克隆你的 ROS2 包到 src/，然后 colcon build
```

---

## 7. `attach` 模式详解

### 7.1 命令

```bash
cd <existing_project>
bash ~/ros2-humble-docker-project/init_ros2_humble_docker.sh attach
```

`PROJECT_NAME` 从当前目录名自动推断（非法字符替换为 `_`）。

### 7.2 工作区智能识别

| 当前目录情况 | attach 行为 | 容器内挂载关系 |
|---|---|---|
| 已有 `ros2_ws/src/` | 直接复用 | `<root>/ros2_ws` ↔ `/workspace/ros2_ws` |
| 仅有 `src/`（无 `ros2_ws`） | 把 `src/` 作为工作区 src，build 产物落在新建的 `ros2_ws/` | `<root>/ros2_ws` ↔ `/workspace/ros2_ws`，外加 `<root>/src` ↔ `/workspace/ros2_ws/src`（嵌套覆盖挂载） |
| 都没有 | 新建空 `ros2_ws/src/` | `<root>/ros2_ws` ↔ `/workspace/ros2_ws` |

> 第二种情况的妙处：源码留在原 `src/`（很多老项目就是这种结构，且已被 git 跟踪），但 `build/install/log` 写到独立 `ros2_ws/` 下，**不污染 src/**。

### 7.3 文件冲突保护

attach 的核心承诺：**绝不破坏用户已有内容**。

| 已有内容 | 行为 |
|---|---|
| `docker/` | 整个目录备份为 `docker.bak_<时间戳>`，重新生成 |
| `scripts/<name>.sh` 同名 | 跳过该脚本，仅补缺失项；用户自有的脚本（不同名）不受影响 |
| `.gitignore` | 仅追加缺失行；带 `# === appended by ros2-humble-docker-project skill ===` 注释头便于审查 / 回滚 |
| `.env` | 不覆盖；提示用户检查是否包含必要变量 |
| `README_DOCKER.md` | 备份为 `README_DOCKER.md.bak_<时间戳>`，重新生成 |
| `data/` | 不存在则创建；存在则不动 |
| `README.md` / `AGENTS.md` / 其它任何文件 | **完全不动** |

### 7.4 真实案例：`old_dandan` 项目

> 下面是一个真实接入流程，用作参考。

接入前：

```
old_dandan/
├── ros2_ws/src/                          # 已有 3 个 ROS2 包
│   ├── el05_motor/
│   ├── elrs_crsf_receiver/
│   └── pca9685_servo/
├── scripts/                              # 已有 3 个机器人启动脚本
│   ├── install-robot-autostart.sh
│   ├── generate-udev-rule-canable.sh
│   └── robot-can0-up.sh
├── deploy/{udev,systemd}/
├── docs/
├── .gitignore                            # 70+ 行已有规则
├── README.md
└── ...
```

执行 `bash ~/ros2-humble-docker-project/init_ros2_humble_docker.sh attach`，输出：

```
[INFO]  把 ROS2 Humble Docker 环境接入当前目录: /home/esd/old_dandan
[INFO]  推断 PROJECT_NAME = old_dandan
[INFO]  检测到 ros2_ws/src，作为 colcon 工作区
[INFO]  生成 docker/Dockerfile, docker/compose.yaml, docker/entrypoint.sh
[INFO]  生成 scripts/build.sh
[INFO]  生成 scripts/run.sh
[INFO]  生成 scripts/enter.sh
[INFO]  生成 scripts/stop.sh
[INFO]  生成 scripts/clean_ws.sh
[INFO]  生成 README_DOCKER.md
[INFO]  生成 .env (PROJECT_NAME=old_dandan)
[INFO]  .gitignore 已存在，仅追加缺失项
[INFO]  向 .gitignore 追加了 22 行
```

接入后 `git status -s`：

```
 M .gitignore                  # append-only
?? .env
?? README_DOCKER.md
?? docker/
?? scripts/build.sh
?? scripts/clean_ws.sh
?? scripts/enter.sh
?? scripts/run.sh
?? scripts/stop.sh
```

观察：

- 3 个 ROS2 包、3 个原脚本、`README.md`、`docs/`、`deploy/` 全部完好
- 用户原有的 `scripts/install-robot-autostart.sh` 等不重名，与模板的 `build.sh` 等共存于 `scripts/` 下
- `.gitignore` 在末尾追加 22 行，原 70+ 行规则一字未改

---

## 8. 生成产物逐项说明

### 8.1 `docker/Dockerfile`

- 基础镜像：`osrf/ros:humble-desktop`（Ubuntu 22.04 + ROS2 Humble desktop）
- 默认安装：colcon、rosdep、vcstool、git、nano/vim/tmux/htop、串口/USB/CAN 工具、rviz2 / rqt / rqt-common-plugins / xacro / robot_state_publisher / joint_state_publisher / demo_nodes_cpp / demo_nodes_py
- 自动给 `/root/.bashrc` 写入 ROS2 环境的 source 命令，并 `cd /workspace/ros2_ws`
- `ENTRYPOINT ["/entrypoint.sh"]`，`CMD ["bash"]`

修改这个文件 → 必须 `./scripts/build.sh` rebuild 镜像。

### 8.2 `docker/compose.yaml`

关键设置：

| 配置 | 值 | 作用 |
|---|---|---|
| `network_mode` | `host` | ROS2 DDS 自动发现最稳的方式 |
| `ipc` | `host` | DDS 共享内存传输 |
| `privileged` | `true` | 设备访问 |
| `working_dir` | `/workspace/ros2_ws` | 进容器默认目录 |
| `env_file` | `../.env` | 项目级配置集中加载 |
| `volumes` | `/dev:/dev`、`/tmp/.X11-unix`、`/etc/localtime`、`../ros2_ws:/workspace/ros2_ws`、`../data:/workspace/data` | 设备 + GUI + 时区 + 工作区 + 数据 |
| `group_add` | `dialout / plugdev / video` | 串口 / USB / 摄像头 |
| `restart` | `unless-stopped` | 开发期一直保活 |

修改这个文件 → 通常只需 `./scripts/stop.sh && ./scripts/run.sh`，**无需 rebuild 镜像**。

### 8.3 `docker/entrypoint.sh`

执行三件事：

1. `source /opt/ros/humble/setup.bash`
2. 若 `/workspace/ros2_ws/install/setup.bash` 存在则 source
3. `exec "$@"`

> ⚠️ 注意：`docker exec` **不走 entrypoint**。所以从外部 `docker exec ... ros2 ...` 直接调用会找不到 `ros2`。要么显式 `bash -c "source ... && cmd"`，要么用 `./scripts/enter.sh` 进交互 shell（会读 `.bashrc`）。

### 8.4 `scripts/`

5 个脚本都是约 10–30 行的薄包装。详见 §9。

### 8.5 `.env`

```env
PROJECT_NAME=<name>
ROS_DOMAIN_ID=0
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
ROS_WS=ros2_ws
CONTAINER_NAME=<name>_ros2_humble
IMAGE_NAME=esd/<name>_ros2_humble:latest
```

`compose.yaml` 通过 `env_file: ../.env` 加载，所有脚本通过 `source .env` 读 `CONTAINER_NAME` 等。这是项目级**唯一事实源**，迁移到别的机器只需复制项目目录（含 `.env`）。

### 8.6 `.gitignore`

- 默认覆盖：colcon 产物 (`build/install/log`)、Python 缓存、C++ 产物、编辑器/IDE、OS 临时文件、Docker 临时、`data/*` 但保留 `.gitkeep`、`*.bak_*` 备份
- attach 模式下采用 append-only 模式，仅追加缺失行

### 8.7 `README_DOCKER.md`

每个项目里都有一份 17 节中文文档，回答：为什么用 Docker、目录结构、首次流程、build/run/enter/stop、talker-listener、rviz2/rqt、USB/CAN/串口/摄像头、`ROS_DOMAIN_ID`、加 apt 依赖、rebuild、5 个常见问题、new vs attach、扩展方向。

---

## 9. 日常工作流：build / run / enter / stop / clean_ws

### 9.1 命令矩阵

| 脚本 | 调用 | 等价 docker 命令 | 何时用 |
|---|---|---|---|
| `./scripts/build.sh` | `docker compose build` | 同 | 首次；改了 Dockerfile 后 |
| `./scripts/run.sh` | `xhost +local:docker` + `docker compose up -d` + `docker exec -it … bash` | 三步合一 | 启动并进入容器（最常用） |
| `./scripts/enter.sh` | `docker exec -it $CONTAINER_NAME bash` | 同 | 已经 `run` 过一次，开第二/第三个终端 |
| `./scripts/stop.sh` | `docker compose down` | 同 | 关机前 / 切项目 |
| `./scripts/clean_ws.sh` | 删 `ros2_ws/{build,install,log}` | 同 | colcon build 卡住 / 想干净重编 |

### 9.2 推荐节奏

```
[一次性]      build.sh
[每天工作开始] run.sh    (在容器内开发)
[多终端]      enter.sh × N
[当天结束]    Ctrl+D 退出 shell （容器仍在后台跑，无需 stop）
[长期不用]    stop.sh
[重编]        clean_ws.sh + 容器内 colcon build
```

容器后台跑不消耗 CPU，可以一直保留；`stop.sh` 主要用于换项目、释放端口或 `ROS_DOMAIN_ID` 冲突时。

### 9.3 build.sh 增量与无缓存

```bash
./scripts/build.sh                        # 增量 build（默认）
./scripts/build.sh --no-cache             # 强制全量 rebuild
docker compose -f docker/compose.yaml --env-file .env build --no-cache  # 等价
```

### 9.4 多个项目怎么办

每个项目都有自己独立的 `CONTAINER_NAME` 和 `IMAGE_NAME`（来自 `.env`），互不冲突。可以同时跑：

```bash
cd ~/proj_a && ./scripts/run.sh      # 容器：proj_a_ros2_humble
cd ~/proj_b && ./scripts/run.sh      # 容器：proj_b_ros2_humble
```

但是它们都用 `network_mode: host`，所以 ROS2 节点在同一个 `ROS_DOMAIN_ID` 下会互相看到。要隔离，请在每个项目的 `.env` 里设不同的 `ROS_DOMAIN_ID`。

---

## 10. 容器内开发 ROS2 包

### 10.1 一个完整示例

进入容器后第一次跑（容器内）：

```bash
# 你已经在 /workspace/ros2_ws（compose 的 working_dir）
pwd                                          # /workspace/ros2_ws
echo $ROS_DISTRO                             # humble

# 装包级依赖（rosdep 读所有 package.xml）
rosdep install --from-paths src --ignore-src -r -y

# 编译
colcon build --symlink-install

# source overlay
source install/setup.bash

# 验证
ros2 pkg list | grep <你的包名>
```

`--symlink-install` 让 Python 节点改源码后**不必再 build**，直接重启节点即可生效（C++ 仍需 build）。

### 10.2 之后每次 `enter.sh`

`/root/.bashrc` 已经自动 source `humble/setup.bash` 和 `install/setup.bash`，并 `cd /workspace/ros2_ws`。新 shell 一进来就能直接 `ros2 run ...`。

### 10.3 多终端调试模式

打开宿主上多个终端，各自跑 `./scripts/enter.sh`，进入的是**同一个**容器：

```
终端 1: ros2 launch my_pkg main.launch.py
终端 2: ros2 topic echo /chatter
终端 3: ros2 topic hz /imu/data
终端 4: candump can0
终端 5: rqt_graph
```

### 10.4 创建新包

容器内：

```bash
cd /workspace/ros2_ws/src
ros2 pkg create --build-type ament_cmake my_cpp_pkg
ros2 pkg create --build-type ament_python my_py_pkg
```

`src/` 是 bind mount，宿主上 `git status` 会立刻看到新建的包。

### 10.5 talker / listener smoke test

如果想验证容器自身的 ROS2 是否正常（与你的代码无关）：

```bash
# 终端 1（容器内）
ros2 run demo_nodes_cpp talker

# 终端 2（容器内）
ros2 run demo_nodes_cpp listener
```

应该看到 listener 持续打印 `[INFO] [listener]: I heard: [Hello World: N]`。

---

## 11. 设备 / GUI / 网络

### 11.1 GUI（rviz2 / rqt）

`compose.yaml` 已配 `DISPLAY` + `/tmp/.X11-unix` 挂载。`run.sh` 自动跑 `xhost +local:docker`。所以容器里直接 `rviz2` / `rqt` 即可。

如果窗口打不开：

1. 宿主跑 `xhost +local:docker`
2. 容器内 `echo $DISPLAY` 应非空（通常 `:0` 或 `:1`）
3. 远程 SSH：`ssh -X` + 宿主 `/etc/ssh/sshd_config` 启用 `X11Forwarding yes`
4. Wayland 用户：登录会话切换 "Ubuntu on Xorg" 后再试
5. NVIDIA：装 `nvidia-container-toolkit`，在 `compose.yaml` 加 `runtime: nvidia`

### 11.2 USB / 串口

容器已挂 `/dev:/dev` + `privileged: true` + `dialout/plugdev` 组。直接：

```bash
# 容器内
ls /dev/ttyUSB* /dev/ttyACM*
python3 -c "import serial; print(serial.Serial('/dev/ttyUSB0', 115200))"
```

宿主上确保用户也在 `dialout`：

```bash
sudo usermod -aG dialout $USER     # 同样需要重登才生效
```

### 11.3 CAN（SocketCAN）

**关键点**：`ip link set can0 up` 是内核操作，**必须在宿主跑**，容器没办法配置 CAN 接口。流程：

```bash
# 宿主（一次即可，重启失效；想持久化用 systemd）
sudo ip link set can0 up type can bitrate 500000

# 容器内（直接可见）
candump can0
cansend can0 123#DEADBEEF
```

### 11.4 摄像头

```bash
ls /dev/video*
ros2 run image_tools cam2image                 # 需先装 ros-humble-image-tools
```

### 11.5 ROS2 网络（DDS）

`network_mode: host` + `ipc: host` 让容器和宿主共享网络栈，最大化 DDS 自动发现。但要注意：

- 同主机上多个容器都是 `host` 网络 → 节点会互相看到（同一个 `ROS_DOMAIN_ID` 下）
- 跨主机：检查防火墙、路由器组播、`RMW_IMPLEMENTATION` 是否一致

---

## 12. `.env` 调优

| 变量 | 默认 | 何时改 |
|---|---|---|
| `PROJECT_NAME` | 项目目录名 | 一般不改；改了要同步改 `CONTAINER_NAME` / `IMAGE_NAME` |
| `ROS_DOMAIN_ID` | `0` | 多人 / 多机器调试，避免互扰 |
| `RMW_IMPLEMENTATION` | `rmw_fastrtps_cpp` | 想试 Cyclone DDS / Zenoh：先 `apt install ros-humble-rmw-cyclonedds-cpp` 再改 |
| `ROS_WS` | `ros2_ws` | 一般不改 |
| `CONTAINER_NAME` | `<name>_ros2_humble` | 自定义命名 |
| `IMAGE_NAME` | `esd/<name>_ros2_humble:latest` | 推到 registry 时改成你的命名空间 |

改完 `.env` 后重启容器：

```bash
./scripts/stop.sh
./scripts/run.sh
```

> 容器内**临时**改 `ROS_DOMAIN_ID`：`export ROS_DOMAIN_ID=42`，仅当前 shell 有效。

---

## 13. 修改 Dockerfile 与依赖管理

### 13.1 三类依赖三种处理

| 依赖类型 | 例子 | 处理方式 |
|---|---|---|
| 镜像层 apt 包 | `python3-smbus`、`ros-humble-nav2-bringup` | 加进 `docker/Dockerfile`，`build.sh` rebuild |
| 包级 ROS2 依赖 | 各 `package.xml` 里的 `<depend>` | 容器内 `rosdep install --from-paths src --ignore-src -r -y` |
| 临时调试包 | 试一下某个 ROS2 包 | 容器内 `apt-get update && apt-get install -y …`（容器删除后丢失） |

### 13.2 加 apt 依赖示例

编辑 `docker/Dockerfile`：

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3-pip \
        python3-colcon-common-extensions \
        ...
        python3-smbus \                    # ← 新增
        i2c-tools \                        # ← 新增
        ros-humble-nav2-bringup \          # ← 新增
        ros-humble-slam-toolbox \          # ← 新增
    && rm -rf /var/lib/apt/lists/*
```

宿主上：

```bash
./scripts/stop.sh
./scripts/build.sh           # 改了 apt 那层，会重跑该层
./scripts/run.sh
```

### 13.3 临时装一下别的包

```bash
# 容器内
apt-get update && apt-get install -y <pkg>
```

容器**重建**（`stop.sh` + `run.sh`）后会丢失。要长期就写进 Dockerfile。

> ⚠️ Dockerfile 末尾有 `rm -rf /var/lib/apt/lists/*`，这是缩小镜像的标准做法。所以容器里第一次 `apt-get install` 都必须先 `apt-get update`。

### 13.4 pip 依赖

如果 ROS2 包用了 `requirements.txt`：

```bash
# 容器内
pip3 install -r requirements.txt
```

长期化：在 Dockerfile 里 `COPY requirements.txt /tmp/ && pip3 install -r /tmp/requirements.txt`。

### 13.5 vcs 工具

容器内已装 `python3-vcstool`，可以批量 clone：

```bash
# repos.yaml
repositories:
  some_pkg:
    type: git
    url: https://github.com/...
    version: humble
```

```bash
vcs import src < repos.yaml
```

---

## 14. 故障排查（含真实案例）

### 14.1 `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`

**症状**：`./scripts/build.sh` 或任何 `docker` 命令报这行错。

**原因**：当前用户不在 `docker` 组，或在 `docker` 组但当前 shell 还没刷新组列表。

**修复**：

```bash
# 1. 加入组
sudo usermod -aG docker $USER

# 2. 让 shell 立即拿到新组（任选其一）
newgrp docker          # 当前窗口启动 sub-shell（最快）
# 或者：完全注销 GUI 会话再登录
```

**真实踩坑**：用户已经执行了 `usermod`，并以为"开新终端窗口"就能生效。但 GNOME Terminal 共用 `gnome-terminal-server` 守护进程，新窗口只是它的子进程，组列表还是登录时锁定的旧值。所以**关闭并重开终端窗口不够**，必须 `newgrp` 或注销重登。

验证：

```bash
groups | tr ' ' '\n' | grep -x docker && echo "OK"
```

### 14.2 容器内 `bash: ros2: command not found`（外部 docker exec 调用）

**症状**：宿主上 `docker exec <container> bash -c 'ros2 pkg list'` 报 `ros2: command not found`。

**原因**：

- `docker exec` 不走 `ENTRYPOINT`，所以 entrypoint.sh 里的 `source` 不生效
- 非交互 shell（`bash -c`）不读 `~/.bashrc`，即使我们在 `.bashrc` 里 source 了 ROS2

**修复**：在外部调用要显式 source：

```bash
docker exec <container> bash -c "
  source /opt/ros/humble/setup.bash &&
  source /workspace/ros2_ws/install/setup.bash &&
  ros2 pkg list
"
```

或者用 `./scripts/enter.sh` 进入交互 shell（会读 `.bashrc`，自动 source）。

### 14.3 `rosdep` 抱怨 `Cannot locate rosdep definition for [ament_python]`

**症状**：

```
ERROR: the following packages/stacks could not have their rosdep keys resolved:
my_pkg: Cannot locate rosdep definition for [ament_python]
```

**原因**：`my_pkg/package.xml` 把 `ament_python` 写成了 `<depend>` 或 `<buildtool_depend>`。它不是 rosdep key，是 build_type，应该写在 `<export>` 块：

```xml
<export>
  <build_type>ament_python</build_type>
</export>
```

把错误写法删掉、保留 `<export>` 那行即可。

**注意**：这个错误**不影响 colcon build**，只是 `rosdep install` 抱怨。

### 14.4 `apt-get install` 报 `Unable to locate package <name>`（容器内）

**原因**：Dockerfile 末尾有 `rm -rf /var/lib/apt/lists/*` 来减小镜像体积，所以容器里第一次 apt 操作要先更新缓存。

**修复**：

```bash
apt-get update
apt-get install -y <pkg>
```

要长期持有该包，请加进 Dockerfile 重 build。

### 14.5 `docker pull` 慢 / 超时

**修复**：配置镜像加速器。`/etc/docker/daemon.json`（无则创建）：

```json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1panel.live"
  ]
}
```

```bash
sudo systemctl restart docker
```

> 镜像源可能随时变动，按当时可用的源调整。

### 14.6 `rviz2` / GUI 打不开

按顺序排查：

1. 宿主跑 `xhost +local:docker`
2. 容器内 `echo $DISPLAY`，应非空
3. SSH 连接：`ssh -X` + 服务端 `X11Forwarding yes`
4. Wayland：登录会话切到 "Ubuntu on Xorg"
5. NVIDIA：装 `nvidia-container-toolkit` + `compose.yaml` 加 `runtime: nvidia`

### 14.7 ROS2 节点互相发现不了

| 检查项 | 命令 |
|---|---|
| `ROS_DOMAIN_ID` 一致？ | `echo $ROS_DOMAIN_ID`（双方） |
| `RMW_IMPLEMENTATION` 一致？ | `echo $RMW_IMPLEMENTATION` |
| 容器是 host 网络？ | `docker inspect <c> | grep NetworkMode` 应为 `host` |
| 防火墙 | `sudo ufw status`，必要时关闭 / 放行组播 |
| 路由器组播 | 跨主机时检查 |

### 14.8 `colcon build` 通过但 `ros2 run` 找不到节点

**原因**：当前 shell 在 build 之前已经存在，没 source 新的 install。

```bash
source /workspace/ros2_ws/install/setup.bash
```

或者退出当前 shell，`./scripts/enter.sh` 重进，新 shell 的 `.bashrc` 会自动 source。

### 14.9 `clean_ws.sh` 担心误删源码

不会。脚本只删 `ros2_ws/{build,install,log}` 三个固定目录名，不递归 `src/`。源代码看完整脚本：

```bash
cat scripts/clean_ws.sh
```

attach 模式下若用户源码在 `src/`（不是 `ros2_ws/src/`），那 build 产物在新建的 `ros2_ws/{build,install,log}` 下，src 永远不会被脚本碰到。

### 14.10 `docker.sock` 在改组之后还是不行 + 什么 `groups` 都没变

参见 §14.1。要点：进程组列表运行时不刷新，只能 `newgrp docker` 或注销重登 GUI 会话；**关闭 GNOME Terminal 窗口再打开不算注销**。

### 14.11 `./scripts/run.sh` 报 `xhost: command not found`

宿主没装 `xhost`：

```bash
sudo apt-get install -y x11-xserver-utils
```

或者忽略——`run.sh` 用的是 `command -v xhost ... || true`，不会因此 fail，只是 GUI 会启不来。

### 14.12 镜像太大占空间

```bash
docker system df                  # 看占用
docker image prune                # 删悬挂镜像
docker builder prune              # 删 build 缓存
docker system prune -a            # 删所有未使用的镜像/容器/网络（小心）
```

---

## 15. 维护：升级、清理、备份、迁移

### 15.1 升级 skill 自身

skill 是个普通目录，直接 `git pull`（如用 git 管理）或重新拷贝即可。**已经接入的项目不会自动升级**，因为 skill 只是生成器，生成的项目是各自独立的副本。要把改动同步到老项目：手动 diff `templates/` 与项目里的对应文件。

### 15.2 升级镜像（拉新版 osrf/ros:humble-desktop）

```bash
docker pull osrf/ros:humble-desktop
cd <project>
./scripts/build.sh --no-cache
./scripts/stop.sh
./scripts/run.sh
```

### 15.3 清理 colcon 产物

```bash
./scripts/clean_ws.sh        # 安全
```

### 15.4 完全重置

```bash
./scripts/stop.sh
docker rmi $(grep IMAGE_NAME .env | cut -d= -f2)
./scripts/clean_ws.sh
./scripts/build.sh           # 全新 build
./scripts/run.sh
```

### 15.5 备份 / 迁移项目到另一台机

只需复制项目目录（含 `.env`）。新机上：

```bash
# 1. 装 Docker + 加入 docker 组（见 §2-3）
# 2. 把 ~/ros2-humble-docker-project/ 也复制过去（其实并不必要，
#    项目里已经有 docker/、scripts/ 自包含，可以独立运行）
# 3. 在新机
cd <project>
./scripts/build.sh
./scripts/run.sh
```

> 注意：build 产物（`ros2_ws/build/install/log`）是宿主架构相关的，不要把别人机器上 build 出来的产物拷过来用，本机重 build。

### 15.6 备份镜像（无网环境 / 离线交付）

```bash
docker save -o my_robot_humble.tar esd/<name>_ros2_humble:latest
# 拿到目标机
docker load -i my_robot_humble.tar
```

---

## 16. 扩展方向

短期可加的能力：

| 方向 | 怎么做 |
|---|---|
| 自动 `ros2 pkg create` | 在 skill 加 `init_pkg.sh`，包装 `ros2 pkg create` 并写默认骨架 |
| 三件套脚手架 | 一键生成 `<name>_bringup` / `<name>_description` / `<name>_interfaces` 包 |
| Gazebo / Ignition | Dockerfile 加 `ros-humble-gazebo-ros-pkgs` |
| MuJoCo | Dockerfile 加 `pip install mujoco`，挂载渲染设备 |
| CAN 调试模板 | 提供示例节点 + launch + `cansend/candump` 的 ROS2 桥接 |
| VS Code devcontainer | 在项目下加 `.devcontainer/devcontainer.json` 复用本 compose |
| GPU 支持 | 配 `nvidia-container-toolkit` + `runtime: nvidia` + `gpus: all` |
| 非 root 用户 | Dockerfile 中创建与宿主 UID 对齐的用户，解决 bind mount 文件 ownership |
| 多 profile | 不同 `ROS_DOMAIN_ID` / `RMW_IMPLEMENTATION` 一键切换（compose profiles） |
| 离线镜像 | CI 自动 `docker save` 到产物，离线机加载 |

---

## 附录 A. 命令速查（最常用 10 条）

```bash
# 接入新项目
cd ~/my_proj && bash ~/ros2-humble-docker-project/init_ros2_humble_docker.sh attach

# 构建镜像
./scripts/build.sh

# 启动并进入
./scripts/run.sh

# 多终端进容器
./scripts/enter.sh

# 停止
./scripts/stop.sh

# 容器内：装包级依赖
rosdep install --from-paths src --ignore-src -r -y

# 容器内：编译
colcon build --symlink-install

# 容器内：source overlay
source install/setup.bash

# 改 ROS_DOMAIN_ID 后重启
sed -i 's/^ROS_DOMAIN_ID=.*/ROS_DOMAIN_ID=42/' .env && ./scripts/stop.sh && ./scripts/run.sh

# 完全清理 + 重 build
./scripts/clean_ws.sh && ./scripts/stop.sh && ./scripts/build.sh --no-cache && ./scripts/run.sh
```

## 附录 B. 重要文件位置一览

| 文件 | 位置 | 说明 |
|---|---|---|
| Skill 入口 | `~/ros2-humble-docker-project/init_ros2_humble_docker.sh` | new / attach |
| Skill 模板 | `~/ros2-humble-docker-project/templates/` | 改这里影响**未来**生成的项目 |
| 项目 Dockerfile | `<project>/docker/Dockerfile` | 改这里只影响当前项目 |
| 项目 compose | `<project>/docker/compose.yaml` | 同上 |
| 项目环境变量 | `<project>/.env` | 项目级配置 |
| 工作区 | `<project>/ros2_ws/` | bind mount 到容器 `/workspace/ros2_ws` |
| 数据目录 | `<project>/data/` | bind mount 到容器 `/workspace/data` |
| 项目级文档 | `<project>/README_DOCKER.md` | 17 节中文 |
| 本文档 | `~/ros2-humble-docker-project/USAGE.md` | skill 总文档 |
