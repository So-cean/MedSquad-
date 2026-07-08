# Dialogue System — API Reference

## 架构

```
NpcManager (autoload)
  ├─ ConversationContext — 对话编排
  │    ├─ tick(npc_id) → 构建prompt → FSM.request
  │    └─ on_response(npc_id, action) → 路由到记忆
  ├─ NPC_FSM (无状态) — request(id, prompt) → action_ready信号
  └─ DialogueManager (autoload) — 气泡池 + 自动显示

NPC (BaseNpc)
  └─ speak(entry: DialogueEntry)
       → DialogueManager 发现 → 分配 DialogueBubble
       → think(蓝色typewriter) → utterance(黑色) → done() → 自动fade_out
```

### 四层分离

| 层 | 组件 | 职责 |
|---|---|---|
| **调度层** | `NpcManager` + `ConversationContext` | 自主对话循环、prompt构建、记忆路由、对话状态 |
| **LLM层** | `npc_fsm.gd` (无状态) | HTTP调用 + JSON解析 + 智能fallback |
| **记忆层** | `MemoryStore` (class_name) | per-NPC对话历史，按对话伙伴分组 |
| **显示层** | `DialogueManager` + `DialogueBubble` | 气泡池 + 共用窗口 + 3行滚动 + 自动销毁 |

## DialogueEntry

```gdscript
DialogueEntry.new(
    speaker: String,        # 显示名
    think: String,          # 推理/思考 (蓝色typewriter阶段)
    dialogue: String,       # 旧格式单句 (后备)
    target: String = "",    # 说话对象
    utterances: Array = []  # 多条短句
)
```

### 方法

```gdscript
is_empty() -> bool              # think + dialogue + utterances 全空
utterance_count() -> int        # 条数
get_utterance(idx) -> String    # 获取第 idx 条
```

## DialogueBubble

think和utterance共用一个RichTextLabel窗口。最多3行可见，超出ScrollContainer滚动。

```
show_entry(entry)
  ├─ THINK 阶段
  │   蓝色文字 typewriter (0.035s/字)
  │   → 完成后暂停0.4s → 颜色过渡到黑色
  │
  └─ UTTERANCE 阶段
      utterances[0] (max(字数/10, 1.2s))
      utterances[1] 追加换行显示
      ... 直至全部播完
      → done() 信号
      → 等0.5s → 自动 fade_out (0.3s)
```

### 特性

- **共用窗口**：think(蓝色) → utterance(黑色) 在同一个label里
- **最多3行**：MAX_HEIGHT = LINE_HEIGHT × 3，超出滚动
- **自动滚动**：`scroll_following = true` 跟最底部
- **播完自动销毁**：`_auto_fade_out()` 在done后0.5s触发
- **不重叠**：DialogueManager跟踪Y位置，重叠时往上移
- **不挡NPC**：气泡在NPC头顶上方20px
- **序列计数器**：`show_entry()` 再次调用时丢弃旧async回调
- **JSON fallback**：解析失败时智能提取think+utterances

## DialogueManager

Autoload。管理6个气泡池。

```gdscript
DialogueManager.register(npc)           # 注册NPC
DialogueManager.unregister(npc)          # 注销NPC
DialogueManager.get_bubble_for_npc(npc)  # 获取已分配的气泡
```

每帧：
1. 遍历注册NPC → 有entry则`_ensure_bubble`
2. 检查已完成气泡 → `_release_bubble` → `fade_out`
3. 定位气泡在NPC头顶 → Y轴错开避免重叠

## MemoryStore

`class_name MemoryStore` — per-NPC记忆，磁盘持久化。

```gdscript
var mem = MemoryStore.new(npc_node.name, npc.get_npc_name())

# 记录对话
mem.add_dialogue(speaker, listener, think, text, importance, keywords)

# 检索
mem.get_context_str(5)                       # 最近5条格式化字符串
mem.get_context_for_partner("patient_001", 5) # 只看跟某患者的对话
mem.get_recent(10)                             # 最近10条原始数据
```

### 磁盘存储

```
user://npc_memories/{node_name}/nodes.json
```

用节点名（唯一）做文件路径。两个同名NPC不会共享记忆。

### 跨NPC记忆路由

```
患者说话 → 存入自己MemoryStore + 存入护士MemoryStore（标注patient_id）
护士回应 → 存入自己MemoryStore + 按target路由到对应患者MemoryStore
```

护士检索时用 `get_context_for_partner(patient_id)` 只看跟某患者的对话。

## ConversationContext

多对一对话编排。构建prompt + 路由response + 追踪对话状态。

```gdscript
var ctx = ConversationContext.new(fsm)
ctx.register("nurse_001", npc_node, "nurse", knowledge_array)
ctx.register("patient_001", npc_node, "patient", knowledge_array)

# 触发LLM调用
ctx.tick("patient_001")  # 患者prompt
ctx.tick("nurse_001")    # 护士prompt（含当前患者上下文）

# 处理response
ctx.on_response(npc_id, action)  # 自动路由到记忆

# 对话状态
ctx.set_active_patient("patient_001")
ctx.is_conversation_done("patient_001")  # 该患者对话完成？
ctx.get_next_undone_patient()             # 下一个未完成的患者
ctx.all_conversations_done()               # 全部完成？

# 信号
ctx.conversation_done  # 某患者对话完成
ctx.response_received  # 收到response
```

### 护士返回格式

```json
{
  "think": "分诊判断30字内",
  "responses": [
    {"target": "patient_001", "utterances": ["对患者1说的话"], "conversation_done": false}
  ],
  "deferred": []
}
```

## NPC_FSM (无状态LLM代理)

```gdscript
var fsm = preload("res://scripts/edmas/npc_fsm.gd").new()
add_child(fsm)
fsm.action_ready.connect(_on_action)

fsm.request(npc_id, prompt)  # → action_ready信号
```

action格式（患者）：
```json
{"think": "心里想什么", "utterances": ["1-2句话"]}
```

action格式（护士）：
```json
{"think": "分诊判断", "responses": [{"target": "...", "utterances": [...], "conversation_done": false}]}
```

JSON解析失败时自动提取think+utterances（支持 `think:` / `思考：` 前缀）。

## NPC → 对话系统集成

```gdscript
extends BaseNpc
# 自动获得:
#   speak(entry)                      — 发言
#   stop_speaking()                   — 停止 + 气泡fade
#   get_dialogue_entry()              — DialogueManager调用
#   get_memory()                      — 获取MemoryStore
#   get_state_name()                  — 状态描述（中文）
#   set_state(WAITING, "候诊区")      — 状态机 + 自动walk_to
#   walk_to("TRIAGE")                 — 导航到命名位置
#   walk_to_pos(Vector2)              — 导航到坐标
#   approach_and_face(npc, 60)        — 走近NPC + 到达后面朝ta
#   face_toward(pos)                  — 面朝某方向
#   arrived_at 信号                   — 到达命名位置
```

### NPC状态机

```
ARRIVED → WAITING → GOING_TO_ROOM → BEING_EXAMINED → DISCHARGED
```

### NPC移动

- 速度90px/s
- 无物理碰撞（穿墙移动，导航路径绕墙）
- `walk_to` / `walk_to_pos` 自动创建NavigationAgent2D
- 沿navmesh路径移动，到达后`_on_nav_target_reached` + `face_toward`
- 走路动画自动播放（4方向：up/down/left/right）
