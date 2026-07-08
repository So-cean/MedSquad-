# MedSquad — 急诊科多智能体模拟

Godot 4.7 2D 俯视角医院模拟。NPC 由 LLM (DeepSeek-V4-Flash) 实时驱动对话、分诊、移动。玩家自主操控角色在急诊科探索。

**核心架构：Godot → Gitee AI (HTTP)。无 Python 后端，无进程管理。**

---

## 启动

```bash
# 直接打开 project.godot，按 F5 运行
godot project.godot
```

NPC 自主对话、移动、分诊，不需要手动启动任何服务。

### 网页版

```bash
godot --headless --audio-driver Dummy --export-release Web build/web/index.html
cd build\web && python -m http.server 8080
```

在线版：https://so-cean.github.io/MedSquad-/

---

## 游戏大纲

玩家扮演来急诊就诊的患者，在真实医院流程中被分诊、检查、治疗、转归。所有医护人员由 LLM 驱动，有独立人格、专业知识和记忆。

```
玩家到达急诊
  ↓
护士分诊问诊（LLM对话：问症状→追问→判断→指示）
  ↓
按护士指示去对应区域（NPC自主寻路）
  ↓
医生检查问诊（LLM对话：查体→开检查）
  ↓
去检查科室（CT/检验/影像）
  ↓
回诊室看结果（LLM对话：诊断→治疗方案）
  ↓
转归：住院/出院/留观
```

**多对一**：护士同时处理多个AI患者NPC，按病情优先级排序。NPC完全自主——对话、移动、状态切换不需要玩家干预。

---

## 操作指南

| 操作 | 按键 | 说明 |
|---|---|---|
| 移动 | WASD/方向键 | 玩家角色移动 |
| 互动 | E | 与NPC对话/进入电梯 |
| 下楼 | Q | 电梯下楼 |
| 暂停 | Esc | 暂停菜单 |

---

## 架构

```
Godot F5
  └─ DialogueTest.tscn (测试场景，含完整地图+碰撞+NPC)
       ├─ NpcManager (autoload) — 上帝视角：自动发现NPC + 自主对话循环 + 动态spawn/discharged
       │    ├─ ConversationContext — 多对一对话编排 (prompt + 记忆路由 + conversation_done)
       │    └─ NPC_FSM (无状态) — request(id, prompt) → action_ready
       │         └─ HTTPRequest → Gitee AI (DeepSeek-V4-Flash)
       ├─ MapSystem (autoload) — NavigationRegion2D + 路径查询 + 区域触发器
       ├─ HospitalMapData (autoload) — 命名位置→Vector2，3个楼层
       ├─ MemoryStore (per-NPC, class_name) — 对话历史 + 按伙伴分组检索 + 磁盘持久化
       └─ DialogueManager (autoload) — 气泡池 + 自动轮询 + 气泡不重叠 + 播完自动销毁
```

### 四层分离

| 层 | 组件 | 职责 |
|---|---|---|
| **调度层** | `NpcManager` + `ConversationContext` | 自主对话循环、prompt构建、记忆路由、对话状态追踪、事件总线 |
| **LLM层** | `npc_fsm.gd` (无状态) | HTTP调用 + JSON解析 + 智能fallback，不持有NPC数据 |
| **记忆层** | `MemoryStore` (class_name) | per-NPC对话历史，按对话伙伴分组检索，磁盘持久化 |
| **显示层** | `DialogueManager` + `DialogueBubble` | 气泡池、think+utterance共用窗口、最多3行滚动、播完自动fade |
| **地图层** | `MapSystem` + `HospitalMapData` | NavigationRegion2D、路径查询、区域触发器、楼层切换 |

### Autoload

| 名称 | 文件 | 职责 |
|---|---|---|
| `DialogueManager` | `scripts/dialogue/dialogue_manager.gd` | 气泡池 + NPC注册 + 气泡不重叠 |
| `NpcManager` | `scripts/edmas/npc_manager.gd` | 上帝视角NPC管理 + 自主对话循环 + 事件总线 |
| `MapSystem` | `scripts/edmas/map_system.gd` | NavigationRegion2D + 路径查询 + 区域触发器 |
| `HospitalMapData` | `scripts/edmas/hospital_map_data.gd` | 命名位置→Vector2，3个楼层坐标 |

### LLM 模型

| 场景 | 模型 | 速度 |
|---|---|---|
| 所有NPC对话 | DeepSeek-V4-Flash | ~2-5s |

---

## 多对一对话

护士一次LLM调用处理多个患者，返回结构化response：

```json
{
  "think": "腹痛2级危重，头痛3级急症，优先处理P2",
  "responses": [
    {"target": "patient_001", "utterances": ["您先在候诊区等"], "conversation_done": false},
    {"target": "patient_002", "utterances": ["马上跟我进抢救室"], "conversation_done": true}
  ]
}
```

- **target字段** — 每条response路由到对应患者记忆
- **conversation_done** — 对话完成标记，自动切换下一个患者
- **记忆按对话伙伴分组** — 护士用 `get_context_for_partner(patient_id)` 只看跟某患者的对话

### 分诊问诊流程

```
患者走近护士（approach_and_face → walk_to + 到达后面对面）
  ↓
患者说主诉 → 护士追问 → 患者补充 → 护士判断 → 给指示 → conversation_done
  ↓
患者walk_to目标房间（候诊区/抢救室/诊室）
  ↓
护士切换下一个患者
```

### 管道模式

LLM调用和气泡显示重叠：

```
response到达 → 显示bubble + 立即发下一个LLM调用
  ↓ bubble播放中     ↓ LLM在飞
  bubble完 → 下个response已到 → 直接显示
```

---

## 对话系统

```
show_entry(entry)
  ├─ THINK: 蓝色文字 typewriter (0.035s/字)
  │          → 完成后暂停0.4s → 颜色过渡到黑色
  └─ UTTERANCE: utterances[] 逐条追加显示
                 → 每条显示时间 = max(字数/10, 1.2s)
                 → 全部播完 → done() → 自动fade_out
```

- think和utterance共用一个窗口，最多3行可见，超出滚动
- 多个NPC气泡不重叠（Y轴错开）
- 气泡在NPC头顶上方20px，不挡住NPC
- 播完自动fade_out + DialogueManager自动回收
- JSON解析失败时智能提取think+utterances

详见 `scripts/dialogue/README.md`。

---

## 记忆系统

```
MemoryStore (class_name, per-NPC)
  ├─ add_dialogue(speaker, listener, think, text, importance, keywords)
  ├─ get_context_str(count) — 最近N条格式化字符串
  ├─ get_context_for_partner(partner_id, count) — 按对话伙伴过滤
  └─ 磁盘持久化: user://npc_memories/{node_name}/nodes.json
```

**重要**：用节点名（唯一）做文件路径，不用display_name。两个同名NPC不会共享记忆。

跨NPC记忆路由：患者发言→存入护士记忆（标注patient_id），护士回应→按target路由到对应患者。

---

## 地图系统

```
MapSystem (autoload, 解耦)
  ├─ NavigationRegion2D — 从墙体CollisionPolygon自动构建navmesh
  ├─ query_path(from, location) — 路径查询
  ├─ ensure_nav_agent(body) — 给任意CharacterBody2D自动创建NavigationAgent2D
  ├─ Area触发器 — 从Marker2D自动生成Area2D (60px半径)
  │    ├─ body_entered → npc_arrived信号
  │    └─ body_exited → npc_left_area信号
  └─ change_floor(id) — 切换楼层场景
```

**不依赖任何其他系统** — 不知道NpcManager、ConversationContext、DialogueSystem、LLM。

NPC导航：`npc.walk_to("TRIAGE")` → 自动创建NavAgent + 寻路 + 沿路径移动 + 到达信号。
NPC不做物理碰撞（穿墙移动），导航路径基于碰撞体绕墙。

---

## NPC状态机

```
BaseNpc.NpcState:
  ARRIVED → WAITING → GOING_TO_ROOM → BEING_EXAMINED → DISCHARGED
```

- `get_state_name()` — 返回中文状态描述（用于LLM prompt）
- `set_state(GOING_TO_ROOM, "候诊区")` — 设置状态 + 自动walk_to
- `face_toward(pos)` — 面朝某方向（对话时用）
- `approach_and_face(npc, 60)` — 走近NPC + 到达后面朝ta
- `arrived_at` 信号 — 到达命名位置时发射

NPC移动速度90px/s，无物理碰撞，沿navmesh路径移动。

---

## 事件总线

NpcManager发射的事件信号：

| 信号 | 触发时机 |
|---|---|
| `patient_arrived` | 患者注册/spawn |
| `triage_started` | 开始分诊某患者 |
| `triage_done` | 分诊完成（含目标房间） |
| `npc_arrived_at` | NPC到达某命名位置 |
| `all_triage_done` | 所有患者分诊完成 |
| `patient_discharged` | 患者出院 |

---

## 测试场景

`scens/edmas/DialogueTest.tscn` — 完整地图 + 碰撞 + NPC自主分诊

```
NpcManager自动发现3个NPC → start_auto_loop()
  ↓
P1走近护士 → 对话 → 分诊完成 → P1 walk_to候诊区
  ↓
P2走近护士 → 对话 → 分诊完成 → P2 walk_to诊室
  ↓
全部分诊完成 → print_status() → 测试结束
```

打开 `project.godot` 按 F5 运行。

---

## 楼层场景

| 楼层 | 场景 | NPC |
|---|---|---|
| 1F 急诊 | `Floor_ED_Core.tscn` | 分诊护士、急救护士、患者×2 |
| 2F 检查 | `Floor_Diagnostics.tscn` | 手术医生、检验科护士 |
| 3F 转归 | `Floor_Downstream.tscn` | 住院护士 |

按 **E** 上楼、**Q** 下楼。

---

## 项目结构

```
scripts/
├── edmas/
│   ├── npc_fsm.gd              无状态LLM代理 (HTTP + JSON + 智能fallback)
│   ├── conversation_context.gd 多对一对话编排 (prompt + 记忆路由 + conversation_done)
│   ├── npc_manager.gd          上帝视角NPC管理 + 自主对话循环 + 事件总线 (autoload)
│   ├── map_system.gd           NavigationRegion2D + 路径查询 + 区域触发器 (autoload)
│   ├── hospital_map_data.gd    命名位置 + 楼层坐标 (autoload)
│   ├── main_edmas.gd           主场景
│   ├── map_npc.gd              楼层NPC (支持walk_to + can_wander)
│   └── managers/
├── dialogue/
│   ├── dialogue_manager.gd     气泡池 + 不重叠 + 自动回收 (autoload)
│   ├── dialogue_bubble.gd      气泡UI (think+utterance共用, 3行滚动, 自动fade)
│   ├── dialogue_entry.gd       数据格式 (think + utterances[])
│   ├── memory_store.gd         per-NPC记忆 (class_name, 按伙伴分组, 磁盘持久化)
│   └── conversation_manager.gd (备用)
└── ui/virtual_joystick.gd      触控摇杆
scens/edmas/
├── Main_EDMAS.tscn             主场景
├── Floor_*.tscn                楼层场景
└── DialogueTest.tscn           测试场景 (完整地图+碰撞+NPC)
assets/maps/
├── normalized/                 地图图 (1672×941)
├── collision/                  墙体碰撞多边形
└── masks/                      可走区域mask
```
