# MedSquad — 急诊科多智能体模拟

Godot 4.7 前端 + Python LLM 后端。模拟急诊科多智能体协作，NPC 由 LLM (DeepSeek-V4-Flash / HealthGPT-L14) 驱动实时决策。

---

## 启动

### 方法一：完整模式（Godot + Backend）

```bash
# 终端 1: 启动 Python LLM 后端
cd backend
pip install -r requirements.txt 2>nul || pip install openai pydantic
python -m app.services.backend_server

# 终端 2: 启动 Godot
godot project.godot
```

BackendBridge (autoload) 会自动连接 `localhost:8651` 上的后端服务。

### 方法二：离线 Mock 模式（无需 Backend）

直接打开 `project.godot` 按 F5 运行。MockDialogueSystem 提供 7 个预设对话流。

### 方法三：网页版

构建 Web 导出：
```bash
godot --headless --audio-driver Dummy --export-release Web build/web/index.html
cd build\web && python -m http.server 8080
# → http://localhost:8080
```

在线版：https://so-cean.github.io/MedSquad-/

---

## 架构

```
┌──────────────────────────────────────────────────────────────┐
│  Godot 前端 (可视化 + 交互)                                   │
│  ┌──────────────┐ ┌──────────────┐ ┌───────────────────┐    │
│  │ FloorContainer│ │ TimelinePlayer│ │ Dialogue Bubble   │    │
│  │ (楼层场景)    │ │ (动作执行器)  │ │ (气泡对话)        │    │
│  └──────────────┘ └──────────────┘ └───────────────────┘    │
│  ┌──────────────┐ ┌──────────────┐ ┌───────────────────┐    │
│  │ SimClient    │ │ BackendBridge│ │ VirtualJoystick   │    │
│  │ (HTTP 通信)  │ │ (进程管理)   │ │ (触控支持)        │    │
│  └──────┬───────┘ └──────────────┘ └───────────────────┘    │
└─────────┼────────────────────────────────────────────────────┘
          │ HTTP POST (JSON)
┌─────────▼────────────────────────────────────────────────────┐
│  Python Backend (NPC 决策引擎)                                │
│  ┌────────────────────────────┐ ┌────────────────────────┐   │
│  │ SimulationEngine           │ │ FSM per NPC            │   │
│  │  ├─ tick() → 并发决策      │ │  ├─ IDLE → DECIDING    │   │
│  │  ├─ report_complete()      │ │  ├─ LLM call (concurrent)│  │
│  │  └─ key rotation           │ │  └─ SPEAKING / MOVING  │   │
│  └────────────────────────────┘ └────────────────────────┘   │
│                        │                                      │
│               ┌────────▼────────┐                             │
│               │ Gitee AI API     │                             │
│               │ DeepSeek-V4-Flash│                             │
│               │ HealthGPT-L14    │                             │
│               └─────────────────┘                             │
└──────────────────────────────────────────────────────────────┘
```

### 数据流

```
Godot 启动 → BackendBridge 拉起 Python 服务
  → SimClient POST /api/sim/init (注册 NPC)
  → 每轮: POST /api/sim/tick
  → NPC FSM 并发调 Gitee AI LLM
  → 返回 actions[] → TimelinePlayer 执行
  → 气泡/移动完成后 → POST /api/sim/complete
  → 下一轮
```

### LLM 模型路由

| 场景 | 模型 | 速度 |
|---|---|---|
| NPC 快速决策 (下一步去哪/做什么) | DeepSeek-V4-Flash | ~2.7s |
| 医学分诊/诊断 | HealthGPT-L14 | ~2.3s |
| 对话生成 (含 think 背景知识) | DeepSeek-V4-Flash | ~2.7s |

所有 NPC 的 LLM 调用**并发执行**（3 个 NPC 同时决策 ≈ 2.7s，非串行 8s）。

---

## 楼层场景

| 楼层 | 场景文件 | NPC |
|---|---|---|
| 1F 急诊接入区 | `Floor_ED_Core.tscn` | 分诊护士、急救护士、患者×2 |
| 2F 检查诊断区 | `Floor_Diagnostics.tscn` | 手术医生、检验科护士 |
| 3F 转归下游区 | `Floor_Downstream.tscn` | 住院护士 |

按 **E** 上楼、**Q** 下楼。每层独立场景，NPC 属于各自楼层。

---

## 交互

| 操作 | 桌面 | 移动端 |
|---|---|---|
| 移动 | WASD | 屏幕左半触摸摇杆 |
| 缩放 | 鼠标滚轮 | 双指捏合 |
| 平移 | 鼠标中键拖拽 | 单指拖拽 |
| 与 NPC 对话 | 走近按 E | 走近按 E |
| 地图总览 | M | M |
| 电梯 | 走近按 E/Q | 走近按 E/Q |

---

## 对话气泡

```
Phase 1: 🤔 [蓝色] 思考内容 (逐字打字效果)
               ↓  完成后暂停 0.5s
Phase 2: 🗣 [深色] 实际对话 (淡入)
               ↓  停留后自动淡化消失
```

- 对话气泡由 DialogueManager (autoload) 管理 6 个气泡池
- 支持 1v1 对话配对 + 优先级打断
- NPC 对话中的 `think` 内容展示 LLM 的推理过程

---

## 项目结构

```
├── project.godot             项目配置 (含 autoload ×4)
├── backend/                   Python LLM 后端
│   └── app/
│       ├── agents/            LLM Agent (step/plan/mock/scenario)
│       ├── services/
│       │   ├── npc_fsm.py     NPC 状态机引擎 (并发决策)
│       │   ├── backend_server.py  HTTP 服务器 (端口 8651)
│       │   └── ...
│       └── schemas/           数据模型
├── scripts/
│   ├── base_npc.gd            NPC 基类
│   ├── edmas/
│   │   ├── main_edmas.gd      主场景编排
│   │   ├── backend_bridge.gd  Autoload (启动后端进程)
│   │   ├── sim_client.gd      后端 HTTP 客户端
│   │   ├── map_npc.gd         楼层 NPC
│   │   ├── managers/
│   │   │   └── timeline_player.gd  动作执行器
│   │   └── mock/              Mock 数据
│   ├── dialogue/              对话系统
│   └── ui/virtual_joystick.gd 触控摇杆
├── scens/edmas/
│   ├── Main_EDMAS.tscn        主场景
│   ├── Floor_ED_Core.tscn     1F 急诊接入区
│   ├── Floor_Diagnostics.tscn 2F 检查诊断区
│   └── Floor_Downstream.tscn  3F 转归下游区
├── assets/maps/               医院地图 (3 张 + 碰撞体)
│   ├── normalized/            规范化地图图
│   └── collision/             自动生成墙体碰撞
└── data/                      NPC 知识库 (JSON)
```

---

## 角色归属

- 护士和医生精灵图：Jephed (Game Between The Lines)
- LLM 引擎：DeepSeek-V4-Flash / HealthGPT-L14 via Gitee AI
