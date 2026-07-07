# MedSquad — 急诊科多智能体模拟

Godot 4.7 2D 俯视角医院模拟。NPC 由 LLM (DeepSeek-V4-Flash) 实时驱动对话与决策。

**核心架构：Godot → Gitee AI (HTTP)。无 Python 后端，无进程管理。**

---

## 启动

```bash
# 直接打开 project.godot，按 F5 运行
godot project.godot
```

Godot 内建的 `NPC_FSM` 通过 `HTTPRequest` 直连 Gitee AI，不需要额外启动任何服务。

### 网页版

```bash
godot --headless --audio-driver Dummy --export-release Web build/web/index.html
cd build\web && python -m http.server 8080
# → http://localhost:8080
```

在线版：https://so-cean.github.io/MedSquad-/

---

## 架构

```
Godot F5
  └─ DialogueTest.tscn (测试场景)
       ├─ NpcManager (autoload) — 自动发现场景NPC + 动态添加/移除
       ├─ ConversationContext — 多对一对话编排 (prompt构建 + 记忆路由)
       │    ├─ 患者: tick_npc() → 路由prompt (描述症状)
       │    └─ 护士: player_talk() → 对话prompt (回应患者)
       ├─ NPC_FSM (无状态) — request(id, prompt) → action_ready 信号
       │    └─ HTTPRequest → Gitee AI (DeepSeek-V4-4-Flash)
       ├─ MemoryStore (per-NPC) — 对话历史 + 按对话伙伴分组检索
       └─ DialogueManager (autoload) — 气泡池 + NPC轮询 + 自动显示
```

### 四层分离

| 层 | 组件 | 职责 |
|---|---|---|
| **调度层** | `ConversationContext` | 构建prompt、路由response到记忆、追踪对话状态 |
| **LLM层** | `npc_fsm.gd` (无状态) | HTTP调用 + JSON解析，不持有NPC数据 |
| **记忆层** | `MemoryStore` (class_name) | per-NPC对话历史，按对话伙伴分组检索，磁盘持久化 |
| **显示层** | `DialogueManager` + `DialogueBubble` | 气泡池管理、THINK→UTTERANCE状态机、自动轮询NPC |

### Autoload

| 名称 | 文件 | 职责 |
|---|---|---|
| `DialogueManager` | `scripts/dialogue/dialogue_manager.gd` | 气泡池 + NPC注册 |
| `NpcManager` | `scripts/edmas/npc_manager.gd` | 上帝视角管理所有NPC，动态添加/移除患者 |
| `HospitalMapData` | `scripts/edmas/hospital_map_data.gd` | 命名位置→Vector2，3个楼层坐标 |

### LLM 模型

| 场景 | 模型 | 速度 |
|---|---|---|
| 所有NPC对话 | DeepSeek-V4-Flash | ~2-5s |

### 多对一对话架构

护士一次LLM调用处理多个患者，返回结构化response：

```json
{
  "think": "腹痛2级危重，头痛3级急症，优先处理P2",
  "responses": [
    {"target": "patient_001", "utterances": ["您先在候诊区等"], "conversation_done": false},
    {"target": "patient_002", "utterances": ["马上跟我进抢救室"], "conversation_done": true}
  ],
  "deferred": []
}
```

- **target字段** — 每条response路由到对应患者
- **conversation_done** — 对话完成标记，自动切换下一个患者
- **记忆按对话伙伴分组** — 护士记忆中P1/P2的对话独立存储

### 管道模式

LLM调用和气泡显示重叠：

```
response到达 → 显示bubble + 立即发下一个LLM调用
  ↓ bubble播放中     ↓ LLM在飞
  bubble完 → 下个response已到 → 直接显示
```

用户感知等待时间 ≈ max(LLM延迟, 显示时间)。

### API Key 轮询

两个 Gitee AI key 自动轮询。

---

## 对话系统

```
show_entry(entry)
  ├─ THINK: 🤔 蓝色文字 typewriter (0.04s/字)
  │          → 完成后暂停 0.5s → 淡出 0.25s
  └─ UTTERANCE: 🗣 utterances[] 逐条播放
                 → 每条显示时间 = max(字数/10, 1.5s)
                 → 全部播完 → done() 信号
```

API 超时或失败时自动显示后备内容。JSON解析失败时智能提取think+utterances。

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

跨NPC记忆路由：
- 患者发言 → 存入护士记忆（标注"patient_001"/"patient_002"）
- 护士回应 → 按target路由到对应患者记忆

---

## 地图系统

```
HospitalMapData (autoload)
  ├─ 命名位置: TRIAGE→Vector2(830,470), ED_RESUS→Vector2(340,200), ...
  ├─ 3个楼层: ED_CORE / DIAGNOSTICS / DOWNSTREAM
  └─ get_location_name(pos) — 反查最近的位置名
```

NPC导航（需要NavigationAgent2D子节点）：
```gdscript
npc.walk_to("TRIAGE")  # 自动寻路
```

---

## NPC状态机

```
BaseNpc.NpcState:
  ARRIVED → WAITING → GOING_TO_ROOM → BEING_EXAMINED → DISCHARGED
```

- `get_state_name()` — 返回中文状态描述（用于LLM prompt）
- `set_state(WAITING, "候诊区")` — 设置状态 + 自动walk_to

---

## 测试场景

`scens/edmas/DialogueTest.tscn` — 分诊对话测试

```
P1: "护士，我头疼得厉害"           ← 只说主诉
护士: "头痛多久了？还有恶心怕光吗？" ← 追问
P1: "三天了，前额胀痛，见光就恶心"   ← 被问到才补充
护士: "需马上请医生评估" (done=true) ← 判断+指示+结束
→ 切换P2，重复流程
→ 全部完成 → 测试结束
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
│   ├── npc_fsm.gd              无状态LLM代理 (HTTP + JSON)
│   ├── conversation_context.gd 多对一对话编排 (prompt + 记忆路由)
│   ├── npc_manager.gd          上帝视角NPC管理 (autoload)
│   ├── hospital_map_data.gd    命名位置 + 楼层 (autoload)
│   ├── main_edmas.gd           主场景
│   ├── map_npc.gd              楼层NPC (支持walk_to)
│   └── managers/
├── dialogue/
│   ├── dialogue_manager.gd     气泡池管理 (autoload)
│   ├── dialogue_bubble.gd      气泡UI (THINK→UTTERANCE状态机)
│   ├── dialogue_entry.gd       数据格式 (think + utterances[])
│   ├── memory_store.gd         per-NPC记忆 (class_name)
│   └── conversation_manager.gd (备用)
└── ui/virtual_joystick.gd      触控摇杆
scens/edmas/
├── Main_EDMAS.tscn             主场景
├── Floor_*.tscn                楼层场景
└── DialogueTest.tscn           测试场景
assets/maps/
├── normalized/                 地图图
└── collision/                  墙体碰撞
```
