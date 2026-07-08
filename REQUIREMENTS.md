# MedSquad — 完整需求文档

## 一、项目概述

Godot 4.7 2D俯视角医院急诊科模拟。NPC由LLM(DeepSeek-V4-Flash)驱动对话、分诊、移动。玩家自主操控角色探索。NPC完全自主——对话、移动、状态切换不需要玩家干预。

## 二、素材需求

### 2.1 地图
- 3张地图背景图 (1672×941)：`assets/maps/normalized/map1_norm.png`, `map2_norm.png`, `map3_norm.png`
- 墙体碰撞多边形（已有，在Floor场景的Collision/StaticBody2D/WallShape里）
- 可走区域mask（已有，`assets/maps/masks/map*_walkable_mask.png`）

### 2.2 角色
- 护士：`assets/nurse_frames/`（8方向idle+walk，32×32帧）
- 急救护士：`assets/nurse_blue_frames/`
- 住院护士：`assets/nurse_green_frames/`
- 医生：`assets/scrubs_green_frames/`（8方向idle+walk）
- 检验护士：`assets/scrubs_blue_frames/`
- 患者蓝：`assets/patient_blue_frames/`
- 患者绿：`assets/patient_green_frames/`
- 每个角色目录需要：idle_down.png, idle_down_right.png, ..., walk_down_a.png, ...（8方向×2帧）

### 2.3 字体
- 中文字体：`assets/fonts/NotoSansSC-VF.ttf`（已有）

### 2.4 UI
- 对话气泡：代码生成（Panel+RichTextLabel，无外部素材）
- Hover卡片：代码生成
- 患者状态图标：emoji（🤔思考, 🗣说话）

## 三、系统架构

### 3.1 Autoload层
| 名称 | 文件 | 职责 |
|---|---|---|
| DialogueManager | `scripts/dialogue/dialogue_manager.gd` | 气泡池管理、NPC轮询、hover检测 |
| NpcManager | `scripts/edmas/npc_manager.gd` | NPC注册/spawn/discharge、FSM持有、ConversationContext持有 |
| MapSystem | `scripts/edmas/map_system.gd` | NavigationRegion2D、路径查询、区域触发器 |
| HospitalMapData | `scripts/edmas/hospital_map_data.gd` | 命名位置→Vector2，3个楼层 |
| ResourceRegistry | `scripts/edmas/world/resource_registry.gd` | 医疗资源（护士/医生/房间/设备）注册+排队 |
| Scheduler | `scripts/edmas/scheduler/scheduler.gd` | 患者流调度（分诊→医生→出院） |

### 3.2 对话系统
**NPC_FSM** (`scripts/edmas/npc_fsm.gd`)
- 无状态LLM代理
- `request(npc_id, prompt)` → HTTP → `action_ready` 信号
- JSON解析 + 智能fallback（纯文本提取think+utterances）
- LLM节流：两次request间最少0.5秒

**ConversationContext** (`scripts/edmas/conversation_context.gd`)
- `on_response(npc_id, action, partner_id)` → 路由到双方MemoryStore
- **关键：add_dialogue用npc_id（不是display_name）做speaker和listener**
- `get_context_for_partner(npc_id)` 能正确匹配

**DialogueBubble** (`scripts/dialogue/dialogue_bubble.gd`)
- THINK阶段：🤔 icon + 蓝色文字 + 浅蓝背景 + 打字机效果
- THINK结束 → 清空文字+隐藏背景 → 切换到UTTERANCE
- UTTERANCE阶段：🗣 icon + 黑色文字 + 打字机效果
- **高度：1-3行自适应。内容≤3行时高度=内容高度。内容>3行时高度=3行(54px)，超出部分裁剪，每帧自动滚到底部显示最后3行**
- **无滚动条**：`SCROLL_MODE_DISABLED`，scrollbar `visible=false`
- think和utterance**不同时显示**：think播完清空后才显示utterance
- think可选：空think直接跳到utterance
- 播完自动fade_out + DialogueManager回收bubble
- 中文断行：`label.language = "zh"` + `AUTOWRAP_WORD`

**DialogueManager** (`scripts/dialogue/dialogue_manager.gd`)
- 6个bubble池
- _process每帧：检查NPC有无entry → 分配/释放bubble
- bubble位置：跟随NPC头顶上方20px，**不堆叠不偏移**（每个bubble跟自己的NPC）
- hover检测：鼠标40px半径内找NPC → 显示NpcHoverCard

### 3.3 记忆系统
**MemoryStore** (`scripts/dialogue/memory_store.gd`, `class_name MemoryStore`)
- per-NPC，磁盘持久化 `user://npc_memories/{node_name}/nodes.json`
- `add_dialogue(speaker_id, listener_id, think, text, importance, keywords)`
- `get_context_for_partner(partner_id, count)` — 按对话伙伴过滤
- **speaker和listener必须用npc_id**，不是display_name
- 跨NPC路由：患者发言→存入护士记忆；护士回应→存入患者记忆

### 3.4 地图系统
**MapSystem** (`scripts/edmas/map_system.gd`)
- 从墙体CollisionPolygon自动构建NavigationRegion2D
- 用 `NavigationServer2D.bake_from_source_geometry_data()` + `add_traversable_outline()`
- `ensure_nav_agent(body)` — 给CharacterBody2D自动创建NavigationAgent2D
- Area2D触发器：从Marker2D自动生成（60px半径）
- `change_floor(id)` — 切换楼层场景

**HospitalMapData** (`scripts/edmas/hospital_map_data.gd`)
- 命名位置：TRIAGE→(830,470), ED_RESUS→(340,200), WAITING_AREA→(340,590), DOCTOR→(1330,500), ED_ENTRANCE→(830,800), ELEVATOR→(840,120)
- 3个楼层：ED_CORE / DIAGNOSTICS / DOWNSTREAM

### 3.5 NPC系统
**BaseNpc** (`scripts/base_npc.gd`)
- 8方向idle+walk动画（code-generated SpriteFrames）
- 状态机：ARRIVED→WAITING→GOING_TO_ROOM→BEING_EXAMINED→DISCHARGED
- `walk_to(location_name)` / `walk_to_pos(Vector2)` — NavigationAgent2D寻路
- `approach_and_face(target_npc, offset)` — 走近+到达后面朝对方
- `face_toward(pos)` — 设idle方向朝某点
- `_separate_from_npcs()` — 软碰撞推开（35px半径，不依赖物理体）
- `can_wander` — 默认false，NPC不自由移动
- 移动用`global_position += vel * delta`（不做物理碰撞，导航路径绕墙）
- **delta用`get_physics_process_delta_time()`不是`get_process_delta_time()`**
- 到达后`stop_speaking()`清除旧对话

**MapNpc** (`scripts/edmas/map_npc.gd`)
- 继承BaseNpc
- @export: npc_display_name, npc_frames_dir, npc_walk_flip
- **不重复声明can_wander**（用父类的）
- `_physics_process`：导航优先，否则separate_from_npcs

### 3.6 调度系统
**Scheduler** (`scripts/edmas/scheduler/scheduler.gd`)
- 监听`patient_arrived` → `_dispatch_triage`
- `ResourceRegistry.find_idle_by_role("nurse")` → 找空闲护士
- `InteractionSession.new(nurse, patient, [nurse_res], "triage_nurse")`
- session结束 → `_dispatch_from_result` → doctor或discharge

**Session** (`scripts/edmas/scheduler/session.gd`)
- 管理一次交互的生命周期
- `_wait_for_arrival`用`Time.get_ticks_msec()`算超时（不用`get_process_delta_time()`，协程里返回0）
- `_wait_display`时间=think打字机时间+utterance打字机时间+阅读时间
- `_clear_participant_speech(except_npc)` — A说话时B旧气泡消失
- session结束→双方stop_speaking

**InteractionSession** (`scripts/edmas/scheduler/session_types/interaction_session.gd`)
- `_start()`：患者approach_and_face护士→等到达→面对面→护士先发起问诊
- `_fire_llm`→response→`_handle_action`(写记忆+显示)→`_wait_display`→`_after_display`(下一个或end)
- `conversation_done=true` → end() → scheduler派发下一阶段

**PromptContext** (`scripts/edmas/scheduler/prompt_context.gd`)
- 患者prompt：大白话说症状，不背医学术语
- 护士prompt：不能读患者隐藏病例，只能根据口述判断，开放式问诊开始
- 医生prompt：不能读隐藏病例，根据口述+分诊记录判断
- think可选：`"think可选：不填或填推理/感受，不要重复已知事实"`

### 3.7 NpcHoverCard
**NpcHoverCard** (`scripts/edmas/npc_hover_card.gd`)
- 深色背景(0.06,0.06,0.12,0.95) + 蓝色边框 + 阴影
- 显示：名字、角色(护士/医生/患者)、状态、位置、当前行为
- `label.language = "zh"` + `AUTOWRAP_WORD` 中文断行
- `autowrap_mode = AUTOWRAP_OFF`在value label上（短文本不需要换行）
- 宽度260px，高度自适应内容
- 跟随鼠标位置，clamp到视口内

## 四、对话显示规格

### 4.1 Think
- icon: 🤔
- 文字颜色: 蓝色 (0.25, 0.40, 0.80)
- 背景: 浅蓝 (0.92, 0.95, 0.98, 0.92)
- 打字机: 0.06s/字
- 打完暂停0.5s → 清空文字+隐藏背景 → 切换utterance
- 可选：空think跳过

### 4.2 Utterance
- icon: 🗣
- 文字颜色: 黑色 (0.12, 0.12, 0.12)
- 打字机: 0.06s/字
- 多条utterance逐条显示（打完一条→等阅读时间→下一条）
- 阅读时间: max(字数/7, 2.0)秒
- 全部播完 → 等0.8s → 自动fade_out

### 4.3 气泡高度
- **1-3行自适应**：内容1行→高度=1行(18px)，2行→36px，3行→54px
- **超过3行**：高度固定54px，超出裁剪，每帧自动滚到底部
- **无滚动条**

### 4.4 气泡位置
- NPC头顶上方20px
- 跟随NPC移动（NPC走bubble走，NPC停bubble停）
- **不堆叠**：每个bubble跟自己的NPC，不做Y轴偏移

## 五、NPC行为规格

### 5.1 护士/医生
- 站在原地不动（idle动画）
- 被approach时face_toward患者
- 对话时不动
- 不自由wander

### 5.2 患者
- spawn在ED_ENTRANCE
- 被scheduler指令时walk_to目标
- 排队时走到护士台附近等待（不说"我先去等着"）
- 分诊完成→walk_to目标房间（候诊区/抢救室/诊室）
- 出院→walk_to ED_ENTRANCE→消失

### 5.3 NPC间距
- 35px软碰撞推开（`_separate_from_npcs`）
- 不做物理碰撞（穿墙移动，导航路径绕墙）
- 不自由wander

## 六、LLM调用规格

### 6.1 模型
- DeepSeek-V4-Flash（所有NPC统一）

### 6.2 请求格式
```json
{"model":"DeepSeek-V4-Flash","messages":[{"role":"user","content":"prompt"}],"temperature":0.3,"max_tokens":512}
```

### 6.3 返回格式（患者）
```json
{"think":"","utterances":["大白话10-20字"]}
```

### 6.4 返回格式（护士/医生）
```json
{"think":"","responses":[{"target":"patient_001","utterances":["对患者说1句话"],"conversation_done":false}],"next_step":null}
```

### 6.5 节流
- 两次request间最少0.5秒

## 七、游戏流程

```
5个患者spawn在ED_ENTRANCE
  ↓
Scheduler为每个患者dispatch triage
  ↓
ResourceRegistry找空闲护士（2个护士，前2个患者同时分诊）
  ↓
患者approach_and_face护士 → 面对面 → 护士先问诊
  ↓
护士LLM → 患者LLM → 护士LLM → ... → conversation_done=true
  ↓
患者walk_to目标房间 → 护士释放 → 下一个排队患者激活
  ↓
Scheduler dispatch doctor session
  ↓
患者approach_and_face医生 → 医生问诊 → ... → discharge
  ↓
患者walk_to ED_ENTRANCE → 消失
  ↓
所有患者出院 → [Scheduler] All patients discharged
```

## 八、操作指南

| 操作 | 按键 | 说明 |
|---|---|---|
| 移动 | WASD | 玩家角色移动 |
| 互动 | E | 与NPC对话/进入电梯 |
| 下楼 | Q | 电梯下楼 |
| 暂停 | Esc | 暂停菜单 |

## 九、当前已知问题

详见 `issues.md`

## 十、编码规则

- 不用`:=`做类型推断，显式声明类型
- Variant返回值函数（JSON.parse_string, Dictionary.get等）必须显式类型
- 不重复声明父类已有的成员
- 协程里不用`get_process_delta_time()`（返回0），用`Time.get_ticks_msec()`
- _physics_process里不用`get_process_delta_time()`，用`get_physics_process_delta_time()`
