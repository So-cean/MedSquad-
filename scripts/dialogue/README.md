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

## DialogueEntry

数据容器。一次 NPC 发言的所有内容。

```gdscript
# 构造
DialogueEntry.new(
    speaker: String,              # 显示名
    think: String,                # 推理/思考 (🤔 阶段)
    dialogue: String,             # 旧格式单句 (后备)
    target: String = "",          # 说话对象
    utterances: Array[String] = []  # 新格式：多条短句 (推荐)
)
```

### 规则

- **优先 utterances[]**：每条 ≤15 字，逐条自动播放 2.5s
- **dialogue 后备**：utterances 为空时自动转 `[dialogue]`
- **think 可为空**：直接进入对话阶段

```gdscript
# 推荐用法
var entry := DialogueEntry.new(
    "分诊护士",
    "患者头痛需询问具体信息",
    "", "",
    ["哪里痛？", "多久了？", "发烧吗？"]
)
```

### 方法

```gdscript
is_empty() -> bool              # 无内容
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
      🗣 utterances[0] (2.5s)
      🗣 utterances[1] (2.5s)
      ... 直至全部播完 → DONE
```

### Robust

- 序列计数器：`show_entry()` 再次调用时丢弃旧 async 回调
- Null 守卫：每个节点操作前检查
- Typewriter 在 fade_out 时自动停止
- API 超时/失败 → 后备 "嗯，我在思考…"

## DialogueManager

Autoload。管理 6 个气泡池。每帧遍历 NPC，有 entry → 显示，无 → 回收。

## NPC → 对话系统集成

NPC 只需继承 `BaseNpc`：

```gdscript
extends BaseNpc
# 自动获得:
#   speak(entry)           — 发言
#   stop_speaking()        — 停止
#   get_dialogue_entry()   — DialogueManager 调用
#   add_to_group("npcs")   — 自动分组
```

## NPC_FSM (LLM 驱动)

`scripts/edmas/npc_fsm.gd` — NPC 状态机，直接调 Gitee AI。

```gdscript
var fsm = preload("res://scripts/edmas/npc_fsm.gd").new()
add_child(fsm)
fsm.action_ready.connect(_on_action)

# 注册
fsm.register_npc("nurse_001", "分诊护士", "nurse", knowledge)
fsm.register_npc("patient_001", "患者", "patient", [])

# 触发决策（并发）
fsm.tick_all()

# 完成
fsm.report_complete("nurse_001")
```

信号：
```
action_ready(npc_id: String, action: Dictionary)
```

action 格式：
```json
{
  "type": "speak|move_to|wait",
  "utterances": ["短句1", "短句2"],
  "think": "...",
  "duration": 2.5
}
```
