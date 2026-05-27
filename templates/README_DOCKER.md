# {{PROJECT_NAME}} — ROS2 Humble Docker 开发环境

> 本文件由 `ros2-humble-docker-project` skill 自动生成。
> 描述如何在 Ubuntu 24.04（或其它无法直接装 Humble 的系统）上，通过 Docker 长期开发 ROS2 Humble 项目。

---

## 1. 为什么 Ubuntu 24.04 推荐用 Docker 跑 ROS2 Humble

ROS2 Humble 是 LTS 版本，但官方主要适配 Ubuntu **22.04**。Ubuntu 24.04 的 GLIBC、Python 等系统库与 Humble 默认依赖**不完全匹配**，直接 `apt install ros-humble-*` 通常会出现：

- 找不到 `humble` 的 apt 源（22.04 jammy 仓库不能简单移植到 24.04 noble）
- Python 3.12 与 ROS2 Humble 的若干 setup.py / ament 工具链不兼容
- 个别二进制包链接失败、动态库版本错位

因此推荐做法：**主机保持纯净，所有 Humble 开发都跑在 Docker 容器里**。本项目即为这种工作流的长期模板：

- 镜像基于官方 `osrf/ros:humble-desktop`（Ubuntu 22.04 + ROS2 Humble desktop）
- 工作区 `ros2_ws/` 通过 bind mount 映射进容器，**源码改动实时同步，无需重建镜像**
- 数据目录 `data/` 同样 bind mount，便于跨容器/重建持久化
- GUI（rviz2、rqt）直通宿主 X server
- USB / 串口 / CAN / 摄像头通过 `/dev:/dev` + `privileged: true` 直通

---

## 2. 项目目录结构

```
{{PROJECT_NAME}}/
├── docker/
│   ├── Dockerfile            # 镜像定义（基于 osrf/ros:humble-desktop）
│   ├── compose.yaml          # docker compose 配置
│   └── entrypoint.sh         # 容器入口：source ROS2 + 工作区 overlay
├── ros2_ws/
│   └── src/                  # 你的 ROS2 包（colcon 工作区）
├── scripts/
│   ├── build.sh              # 构建镜像
│   ├── run.sh                # 启动并进入容器（首次/平常使用）
│   ├── enter.sh              # 进入已运行的容器
│   ├── stop.sh               # 停止并移除容器
│   └── clean_ws.sh           # 清理 colcon 编译产物（不动 src/）
├── data/                     # 数据集 / bag / 输出 等（容器内 /workspace/data）
├── README_DOCKER.md          # 本文件
├── .env                      # 项目级配置（PROJECT_NAME / ROS_DOMAIN_ID 等）
└── .gitignore
```

> **attach 模式**下，如果原项目只有 `src/` 没有 `ros2_ws/src/`，
> 则 `src/` 会被映射到容器内 `/workspace/ros2_ws/src`，
> 而 `build/install/log` 会落到宿主 `ros2_ws/` 下，不会污染源码目录。

---

## 3. 第一次使用流程

```bash
cd {{PROJECT_NAME}}
./scripts/build.sh     # 构建镜像（首次较慢，需要拉 osrf/ros:humble-desktop）
./scripts/run.sh       # 启动容器并进入
```

进入容器后：

```bash
# 容器内
cd /workspace/ros2_ws
colcon build --symlink-install
source install/setup.bash
```

退出容器（不停止）：直接 `exit` 或 `Ctrl+D`，容器仍在后台运行。
要停止容器：在宿主执行 `./scripts/stop.sh`。

---

## 4. 如何构建镜像

```bash
./scripts/build.sh
```

等价于：

```bash
docker compose -f docker/compose.yaml --env-file .env build
```

修改了 `docker/Dockerfile`（例如新增 apt 包）后，需要重新执行此命令。
对于纯源码改动，**不需要重建镜像**——`ros2_ws/` 是 bind mount，容器内可直接 `colcon build`。

---

## 5. 如何启动并进入容器

```bash
./scripts/run.sh
```

该脚本会：

1. `xhost +local:docker`，允许容器使用宿主 X server（rviz2 / rqt）
2. `docker compose ... up -d` 后台启动容器
3. `docker exec -it ${CONTAINER_NAME} bash` 进入交互 shell

---

## 6. 如何进入已经运行的容器

新开一个终端窗口：

```bash
./scripts/enter.sh
```

会自动用 `.env` 里的 `CONTAINER_NAME` 进入正在运行的容器。可以同时开多个终端。

---

## 7. 如何停止容器

```bash
./scripts/stop.sh
```

会执行 `docker compose ... down`，停止并移除容器（**镜像保留**，下次 `run.sh` 几秒钟即可起来）。

---

## 8. 如何编译 ROS2 工作区

容器内：

```bash
cd /workspace/ros2_ws
colcon build --symlink-install
source install/setup.bash
```

后续在同一个 shell 中直接 `ros2 run ...` / `ros2 launch ...` 即可。
新开 shell 进入容器时（`enter.sh`），`/root/.bashrc` 已经自动 source 了 base + overlay。

要清理编译产物：宿主上执行 `./scripts/clean_ws.sh`，只删除 `build/ install/ log/`，**不动 `src/`**。

---

## 9. 如何运行 talker / listener 测试

容器内开两个 shell（或两个终端各自 `enter.sh`）：

```bash
# Shell A
ros2 run demo_nodes_cpp talker

# Shell B
ros2 run demo_nodes_cpp listener
```

应当看到 listener 持续打印来自 talker 的字符串。
如果听不到消息，先看 §15「ROS2 节点互相发现不了」。

---

## 10. 如何运行 rviz2 / rqt

容器内：

```bash
rviz2
# 或
rqt
```

如果第一次报错 `Authorization required, but no authorization protocol specified` 或者窗口打不开：

宿主执行：

```bash
xhost +local:docker
```

然后重新进入容器再试。`scripts/run.sh` 已经自动做过这步，但如果你直接用 `docker exec` 进容器，可能要手动跑一次。

---

## 11. 如何使用 USB / 串口 / CAN / 摄像头

由于 `compose.yaml` 已经：

- 挂载 `/dev:/dev`
- `privileged: true`
- 加入 `dialout / plugdev / video` 组

所以容器内看到的设备节点跟宿主一致。

**串口示例**（USB 转串口在宿主显示为 `/dev/ttyUSB0`）：

容器内：

```bash
ls -l /dev/ttyUSB0
python3 -c "import serial; s=serial.Serial('/dev/ttyUSB0', 115200); print(s)"
```

**CAN 示例**（如使用 SocketCAN，例如 `can0`）：

宿主先把接口拉起来（一次即可，重启失效）：

```bash
sudo ip link set can0 up type can bitrate 500000
```

容器内：

```bash
candump can0
cansend can0 123#DEADBEEF
```

**摄像头示例**（USB UVC 相机，宿主 `/dev/video0`）：

```bash
ls /dev/video*
ros2 run image_tools cam2image   # 需要安装 image_tools 等
```

---

## 12. 如何修改 ROS_DOMAIN_ID

编辑项目根目录的 `.env`：

```env
ROS_DOMAIN_ID=42
```

然后重启容器：

```bash
./scripts/stop.sh
./scripts/run.sh
```

> 同一局域网内不同 `ROS_DOMAIN_ID` 的节点互不发现。多人/多机器调试时常用。

也可以在容器内**临时**改：

```bash
export ROS_DOMAIN_ID=42
```

但这种方式只在当前 shell 有效。

---

## 13. 如何添加新的 apt 依赖

编辑 `docker/Dockerfile`，在 `apt-get install -y --no-install-recommends \` 块中加入你的包，例如：

```dockerfile
        ros-humble-nav2-bringup \
        ros-humble-slam-toolbox \
```

然后重建镜像：

```bash
./scripts/build.sh
./scripts/stop.sh
./scripts/run.sh
```

> 规则：**镜像层依赖（apt）改动 → 重建镜像；源码（src/）改动 → 不需要重建**。

---

## 14. 修改 Dockerfile 后如何 rebuild

```bash
./scripts/build.sh        # 重建镜像
./scripts/stop.sh         # 停旧容器
./scripts/run.sh          # 起新容器
```

如果想强制无缓存重建：

```bash
docker compose -f docker/compose.yaml --env-file .env build --no-cache
```

---

## 15. 常见问题

### 15.1 `docker pull` 慢或 timeout

为 Docker 配置国内镜像加速。编辑（无则创建）：

```
/etc/docker/daemon.json
```

例：

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

> 镜像加速服务可能随时变动，请按当时可用的源调整。

### 15.2 rviz2 打不开

按顺序排查：

1. 宿主先跑：`xhost +local:docker`
2. 检查 `DISPLAY` 是否传进容器：在容器里 `echo $DISPLAY`，应非空（通常 `:0` 或 `:1`）
3. SSH 远程登录的宿主：需要 `ssh -X` 并且宿主 `/etc/ssh/sshd_config` 启用 `X11Forwarding yes`
4. Wayland 用户：登录会话切换为 "Ubuntu on Xorg" 后再试
5. NVIDIA 显卡：可能需要装 `nvidia-container-toolkit` 并在 `compose.yaml` 加 `runtime: nvidia`

### 15.3 没有 `/dev/ttyUSB0` 权限

容器已是 `privileged: true` 且加入 `dialout` 组，正常情况下不会有权限问题。
若仍报权限错误：

```bash
# 宿主
sudo usermod -aG dialout $USER     # 注销重登
ls -l /dev/ttyUSB0                 # 应属于 dialout 组
```

如果是 `/dev/ttyACM0` 等其它节点，原理相同。

### 15.4 ROS2 节点互相发现不了

排查清单：

- 宿主与容器内 `ROS_DOMAIN_ID` 是否一致？（容器内 `echo $ROS_DOMAIN_ID`）
- `RMW_IMPLEMENTATION` 是否一致？混用 Fast DDS / Cyclone DDS 会发现不到
- 容器是否使用了 `network_mode: host`？本模板默认是
- 防火墙：`sudo ufw status`，必要时关闭或放行 multicast
- 跨主机：检查路由器是否屏蔽组播；可改用 Discovery Server / FastDDS unicast 配置

### 15.5 `colcon build` 后找不到包

记得：

```bash
source /workspace/ros2_ws/install/setup.bash
```

新进入容器（`enter.sh`）已自动 source。但**当前 shell 在 build 之前已存在**时，install 还没生成，需要 build 完后手动 source 一次。

或：`exit` 退出后 `enter.sh` 重新进入即可自动 source。

---

## 16. new 与 attach 的区别

| | **new 模式** | **attach 模式** |
|---|---|---|
| 命令 | `bash init_ros2_humble_docker.sh new <name>` | `cd existing_project && bash init_ros2_humble_docker.sh attach` |
| 目标目录 | 新建 `<name>/` 子目录 | 当前目录 |
| 适用场景 | 全新项目 | 已有源码、想加 Docker 化开发环境 |
| `ros2_ws/src` | 必然新建空工作区 | 优先复用现有 `ros2_ws/src`；否则用 `src/`；否则新建 |
| `docker/` 已存在 | 不会发生（目录是新的） | 备份为 `docker.bak_<时间戳>` 后重新生成 |
| `scripts/*.sh` 已存在 | 不会发生 | 跳过同名脚本，仅补缺失项 |
| `.gitignore` 已存在 | 不会发生 | 仅追加缺失行，不破坏原有内容 |
| `.env` 已存在 | 不会发生 | 不覆盖，仅提示用户检查 |
| 用户源码 | 无 | **绝不删除、绝不移动**，只挂载 |

---

## 17. 后续可扩展方向

本模板刻意保持精简。常见的后续扩展：

- **自动创建 ROS2 package**：`ros2 pkg create --build-type ament_cmake my_pkg`
- **三件套脚手架**：`bringup` / `description` / `interfaces` 包自动生成
- **仿真**：在 Dockerfile 加入 `ros-humble-gazebo-ros-pkgs` 或集成 MuJoCo
- **CAN 调试模板**：示例节点 + launch 文件，封装 `cansend/candump` 的 ROS2 桥接
- **VS Code devcontainer**：在项目下加 `.devcontainer/devcontainer.json` 复用本 compose
- **GPU 支持**：`nvidia-container-toolkit` + `runtime: nvidia` + `gpus: all`
- **非 root 用户**：在 Dockerfile 中创建与宿主 UID 对齐的用户，解决 bind mount 文件 ownership 问题
- **多 profile**：不同 `ROS_DOMAIN_ID` / `RMW_IMPLEMENTATION` 一键切换
