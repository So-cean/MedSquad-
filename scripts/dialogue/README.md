# Dialogue System — API Reference

## 架构

```
NPC (BaseNpc)
  └─ speak(entry: DialogueEntry)
       → DialogueManager (autoload) 发现
       → 分配 DialogueBubble (池中复用)
       → 显示 THINK→UTTERANCE 状态机
       → NPC stop_speaking() → 气泡 fade_out
```

### 四层分离

| 层 | 组件 | 职责 |
|---|---|---|
| **调度层** | `ConversationContext` | 构建prompt、路由response到记忆、追踪对话状态 |
| **LLM层** | `npc_fsm.gd` (无状态) | HTTP调用 + JSON解析 |
| **记忆层** | `MemoryStore` (class_name) | per-NPC对话历史，按对话伙伴分组 |
| **显示层** | `DialogueManager` + `DialogueBubble` | 气泡池 + THINK→UTTERANCE |

## DialogueEntry

数据容器。一次 NPC 发言的所有内容。

```gdscript
DialogueEntry.new(
    speaker: String,        # 显示名
    think: String,          # 推理/思考 (🤔 阶段)
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

不直接调用。生命周期：

```
show_entry()
  ├─ THINK 阶段
  │   🤔 蓝色文字 typewriter (0.04s/字)
  │   → 暂停 0.5s → 淡出 (0.25s)
  │
  └─ UTTERANCE 阶段
      🗣 utterances[0] (max(字数/10, 1.5s))
      🗣 utterances[1] (max(字数/10, 1.5s))
      ... 直至全部播完 → done() 信号
```

### Robust

- 序列计数器：`show_entry()` 再次调用时丢弃旧 async 回调
- Null 守卫：每个节点操作前检查
- Typewriter 在 fade_out 时自动停止
- API 超时/失败 → 后备内容
- JSON解析失败 → 智能提取think+utterances

## DialogueManager

Autoload。管理 6 个气泡池。每帧遍历 NPC，有 entry → 显示，无 → 回收。

```gdscript
DialogueManager.register(npc)           # 注册NPC
DialogueManager.unregister(npc)          # 注销NPC
DialogueManager.get_bubble_for_npc(npc)  # 获取已分配的气泡
```

## MemoryStore

`class_name MemoryStore` — per-NPC记忆，磁盘持久化。

```gdscript
var mem = MemoryStore.new(npc_node.name, npc.get_npc_name())

# 记录对话
mem.add_dialogue(speaker, listener, think, text, importance, keywords)

# 检索
mem.get_context_str(5)                    # 最近5条格式化字符串
mem.get_context_for_partner("nurse_001", 5)  # 只看跟护士的对话
mem.get_recent(10)                        # 最近10条原始数据
```

### 磁盘存储

```
user://npc_memories/{node_name}/nodes.json
```

**重要**：用节点名（唯一）做文件路径，不用display_name。两个display_name相同的NPC不会共享记忆。

### 跨NPC记忆路由

```
患者说话 → 存入自己MemoryStore + 存入护士MemoryStore（标注patient_001）
护士回应 → 存入自己MemoryStore + 按target路由到对应患者MemoryStore
```

护士检索时用 `get_context_for_partner(patient_id)` 只看跟某个患者的对话。

## ConversationContext

多对一对话编排。构建prompt + 路由response + 追踪对话状态。

```gdscript
var ctx = ConversationContext.new(fsm)
ctx.register("nurse_001", npc_node, "nurse", knowledge_array)
ctx.register("patient_001", npc_node, "patient", knowledge_array)

# 触发LLM调用
ctx.tick("patient_001")  # 患者用路由prompt
ctx.tick("nurse_001")    # 护士用对话prompt（含所有患者上下文）

# 处理response
ctx.on_response(npc_id, action)  # 自动路由到记忆

# 对话状态
ctx.set_active_patient("patient_001")
ctx.is_conversation_done("patient_001")  # 该患者对话是否完成
ctx.get_next_undone_patient()             # 下一个未完成的患者
ctx.all_conversations_done()               # 全部完成？
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

`scripts/edmas/npc_fsm.gd` — 只做HTTP + JSON，不持有NPC数据。

```gdscript
var fsm = preload("res://scripts/edmas/npc_fsm.gd").new()
add_child(fsm)
fsm.action_ready.connect(_on_action)

# 唯一公开方法
fsm.request(npc_id, prompt)  # → action_ready 信号
```

信号：
```
action_ready(npc_id: String, action: Dictionary)
```

action 格式（患者）：
```json
{
  "think": "心里想什么",
  "utterances": ["1-2句话"]
}
```

action 格式（护士）：
```json
{
  "think": "分诊判断",
  "responses": [{"target": "patient_001", "utterances": ["..."], "conversation_done": false}]
}
```

JSON解析失败时自动提取think+utterances（支持 `think:` / `思考：` 前缀）。

## NPC → 对话系统集成

NPC 只需继承 `BaseNpc`：

```gdscript
extends BaseNpc
# 自动获得:
#   speak(entry)           — 发言
#   stop_speaking()        — 停止
#   get_dialogue_entry()   — DialogueManager 调用
#   get_memory()           — 获取MemoryStore
#   get_state_name()       — 状态描述（中文）
#   set_state(WAITING, "候诊区")  — 状态机 + 自动walk_to
#   walk_to("TRIAGE")     — 导航到命名位置
#   add_to_group("npcs")  — 自动分组
```

### NPC状态机

```
ARRIVED → WAITING → GOING_TO_ROOM → BEING_EXAMINED → DISCHARGED
```
