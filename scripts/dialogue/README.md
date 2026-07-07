# Dialogue System — API Reference

## 架构概览

```
                    ┌──────────────┐
                    │  Any Scene   │  (DialogueTest.tscn / Main_EDMAS.tscn / etc.)
                    │  NPC calls   │
                    │  speak(entry)│
                    └──────┬───────┘
                           │
              ┌────────────▼────────────┐
              │    DialogueManager       │  ← autoload, always alive
              │    (气泡池管理)          │
              │    ┌──────────────────┐  │
              │    │ DialogueBubble x6 │  │  CanvasLayer layer 100
              │    │ (池，循环复用)    │  │
              │    └──────────────────┘  │
              │ 每帧: 检查所有 NPC      │
              │ 有 dialogue → 分配气泡  │
              │ 无 → fade_out           │
              └─────────────────────────┘
```

### 核心原则

1. **NPC 只管说话**：`npc.speak(entry)` 把内容发给 DialogueManager，不关心气泡怎么显示
2. **DialogueManager 管显示**：自动分配气泡、定位、更新、回收
3. **DialogueEntry 是唯一数据格式**：描述一次「发言」的所有内容
4. **调用方不碰气泡内部**：不直接调 DialogueBubble 的方法，只通过 `npc.speak()`

---

## DialogueEntry

**文件**: `dialogue_entry.gd`

一次 NPC 发言的数据容器。

```gdscript
# ── 构造 ──
DialogueEntry.new(
    speaker: String,        # 说话者名称，如 "分诊护士"
    think: String,          # 思考/推理内容（显示在 🤔 阶段）
    dialogue: String,       # 旧格式：单句对话（新项目用 utterances 替代）
    target: String = "",    # 说话对象 ID
    utterances: Array[String] = []  # 新格式：多句短对话
)
```

### 使用规则

- **优先用 `utterances[]`**：每条不超过 15 字，逐条自动播放
- **`dialogue` 是后备**：如果 `utterances` 为空且 `dialogue` 不为空，自动转为 `[dialogue]`
- **`think` 可为空**：无思考内容时直接进入对话阶段

```gdscript
# ✅ 推荐用法（多条短句）
var entry := DialogueEntry.new(
    "分诊护士",
    "患者头痛需询问具体信息",
    "", "",
    ["哪里痛？", "多久了？", "发烧吗？"]
)

# ✅ 兼容用法（单句）
var entry := DialogueEntry.new(
    "分诊护士",
    "评估完成",
    "建议去CT室检查"
)

# ❌ 不要直接操作气泡内部
```

### 方法

```gdscript
entry.is_empty() -> bool          # 无内容时返回 true
entry.utterance_count() -> int    # 返回 utterances 条数
entry.get_utterance(idx) -> str   # 获取第 idx 条，越界返回 dialogue
```

---

## NPC → DialogueManager 接口

NPC 不需要知道 DialogueManager 的存在，只需要继承 `BaseNpc`：

```gdscript
# 在任意 NPC 脚本中
extends BaseNpc

# 发言
speak(entry: DialogueEntry) -> void

# 停止发言（气泡消失）
stop_speaking() -> void

# DialogueManager 每帧调用来检查是否有新内容
get_dialogue_entry() -> DialogueEntry
```

### 示例

```gdscript
# 分诊护士在对话测试中
var nurse = _find_npc("分诊护士")
if nurse:
    var entry := DialogueEntry.new("分诊护士", "", "", "", [
        "您好，我是分诊护士",
        "您说头痛2天了？",
        "具体是哪个部位痛？",
    ])
    nurse.speak(entry)
```

---

## DialogueBubble

**文件**: `dialogue_bubble.gd`

**不直接调用。** 只通过 DialogueManager 间接使用。

### 生命周期

```
show_entry()
  │
  ├─ THINK 阶段（如有 think 内容）
  │   ├─ 🤔 蓝色文字逐字输出 (0.04s/字)
  │   ├─ 完成后暂停 0.5s
  │   └─ 淡出消失 (0.25s)
  │
  ├─ UTTERANCE 阶段
  │   ├─ 🗣 utterances[0] 显示 (2.5s)
  │   ├─ 🗣 utterances[1] 显示 (2.5s)
  │   └─ ...直至全部播完
  │
  └─ DONE → 等待 Manager 回收
       → fade_out() (0.4s 淡出)
```

### 状态机

```
IDLE → show_entry() → THINK → (think完成) → UTTERANCE → (全部播完) → DONE
                                              ↑
                                        无 think 时直接跳到这里
```

---

## DialogueManager

**文件**: `dialogue_manager.gd` | **注册**: `project.godot` autoload

全局单例，管理气泡池（6 个气泡循环复用）。

### 自动行为（无需调用）

- 每帧遍历所有注册 NPC，检查 `get_dialogue_entry()`
- 有内容 → 分配空闲气泡
- 无内容 → 释放气泡（fade_out）
- 气泡位置跟随 NPC 世界坐标 → 屏幕坐标

### NPC 注册/注销（自动）

```gdscript
# BaseNpc._ready() 自动调用
DialogueManager.register(self)

# BaseNpc._exit_tree() 自动调用
DialogueManager.unregister(self)
```

---

## 气泡显示规则

| 条件 | 行为 |
|---|---|
| `think` 非空 | 🤔 typewriter → 0.5s → 切 🗣 utterances |
| `think` 为空 | 直接 🗣 utterances |
| `utterances` 为空且 `dialogue` 非空 | 自动转 `[dialogue]` |
| `utterances` 为空且 `dialogue` 为空 | 不显示任何内容 |

---

## 集成指南

### 在场景中添加 NPC

```tscn
[node name="MyNPC" type="CharacterBody2D"]
script = ExtResource("map_npc")
npc_display_name = "分诊护士"
npc_frames_dir = "res://assets/nurse_frames/"

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="MyNPC"]
```

自动获得：
- NPC 被 DialogueManager 发现和注册 ✅
- 可通过 `npcs` 分组查找 ✅
- 调用 `speak(entry)` 显示气泡 ✅

### 触发对话

```gdscript
# 直接触发
_my_npc.speak(DialogueEntry.new("医生", "思考中...", "", "", ["一句", "两句"]))

# 延时后清除
_my_npc.stop_speaking()
```

### 当前对话系统不需要关心的

- 气泡位置计算 → DialogueManager 自动处理
- 气泡回收 → 自动
- 相机是否存在 → 有则跟随，无则跳过（气泡不显示）
- Think → Utterance 切换 → 自动

---

## 测试场景

`scens/edmas/DialogueTest.tscn` + `DialogueTest.gd`

```gdscript
# 启动后 1.5s 自动演示 NPC 对话
# 分诊护士说 4 条 utterances → 患者回复 1 条 → 护士再回 3 条
# 观察气泡逐条自动播放
```
