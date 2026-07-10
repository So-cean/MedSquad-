# ED-MAS / MedSquad Teammate Video Baseline Scene Report

> 结论先行：当前仓库里，最像“队友视频里那套 ED 地图 + 角色小人 + 中文对白气泡”的基线场景是 `res://scens/room1.tscn`，它走的是 `BaseNpc + DialogueManager + MockDialogueSystem + mock_flows.json` 的纯本地对白链路，不依赖后端 API。

## 1. 结论摘要

- **最可能的视频场景**：`res://scens/room1.tscn`
- **核心对白系统**：`scripts/dialogue/dialogue_manager.gd` + `scripts/dialogue/mock_dialogue_system.gd` + `scripts/dialogue/dialogue_bubble.gd`
- **角色运行基础**：`scripts/base_npc.gd`，配合 `scens/nurse.tscn`、`scens/patient_blue.tscn` 等 NPC 场景
- **是否依赖后端**：否。当前可见的中文对白、气泡显示、NPC 发现与对话推进都来自本地脚本和 `data/mock_flows.json`
- **Main_EDMAS 为何不一样**：`scens/edmas/Main_EDMAS.tscn` 是另一条“API 驱动 + 地图/患者”链路，它没有直接复用视频 baseline 的 `BaseNpc` 世界和 `MockDialogueSystem`

---

## 2. 我搜索到的关键证据

### 2.1 未找到的内容

以下关键词在当前仓库中**没有找到**对应的 scene / script 直接命名：

- `DialogueTest`
- `npc_display_name`
- `reset_memory`
- `get_memory`
- `scripts/edmas/npc_manager.gd`
- `scripts/edmas/map_npc.gd`
- `scripts/edmas/scheduler/session.gd`

这说明当前仓库的“视频 baseline”不是一条 `NpcManager / MapNpc / Scheduler` 运行链，而更像是老的本地对话场景。

### 2.2 找到的对白链路

#### 场景

- `D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-\scens\room1.tscn`

该场景直接实例化了：

- `scens/player.tscn`
- `scens/nurse.tscn`
- `scens/scrubs_green.tscn`
- `scens/nurse_blue.tscn`
- `scens/scrubs_blue.tscn`
- `scens/nurse_green.tscn`
- `scens/patient_blue.tscn`
- `scens/patient_green.tscn`

#### 白话系统脚本

- `scripts/dialogue/dialogue_manager.gd`
- `scripts/dialogue/conversation_manager.gd`
- `scripts/dialogue/dialogue_bubble.gd`
- `scripts/dialogue/dialogue_entry.gd`
- `scripts/dialogue/mock_dialogue_system.gd`
- `scripts/dialogue/memory_store.gd`
- `scripts/dialogue/npc_data_loader.gd`

#### NPC 脚本

- `scripts/base_npc.gd`
- `scripts/nurse.gd`
- `scripts/nurse_blue.gd`
- `scripts/nurse_green.gd`
- `scripts/scrubs_blue.gd`
- `scripts/scrubs_green.gd`
- `scripts/patient_blue.gd`
- `scripts/patient_green.gd`

#### 数据

- `data/mock_flows.json`
- `data/npcs/患者.json`
- `data/npcs/分诊护士.json`
- `data/npcs/急救护士.json`
- `data/npcs/住院护士.json`
- `data/npcs/检验科护士.json`
- `data/npcs/手术医生.json`

---

## 3. 最可能的视频 baseline 是什么

### 3.1 目录判断

`room1.tscn` 是当前仓库里最符合“视频里看到地图 + 多个小人 + 中文对话气泡”的场景，因为：

1. 它直接实例化了多种 NPC scene。
2. 这些 NPC scene 都 `extends BaseNpc`。
3. `DialogueManager` 是 autoload，进入场景后会自动接管气泡显示。
4. `MockDialogueSystem` 会从 `data/mock_flows.json` 读取本地对白流，不依赖后端。

### 3.2 对话内容来源

视频里的中文对白气泡，最可能来自：

- `scripts/dialogue/mock_dialogue_system.gd`
- `data/mock_flows.json`

`MockDialogueSystem` 会扫描 `group("npcs")` 里的 `BaseNpc` 节点，然后按 flow step 触发 `DialogueEntry`。因此视频中的对话不是后端 API 生成，而是**本地脚本驱动的固定对白流**。

---

## 4. 和 Main_EDMAS 的对比

### 4.1 Main_EDMAS 的场景类型不同

- `res://scens/edmas/Main_EDMAS.tscn` 是 `Control` 主界面
- 它挂的是：
  - `scripts/edmas/main_edmas.gd`
  - `scripts/edmas/api_client.gd`
  - `scripts/edmas/patient_manager.gd`
  - `scens/edmas/HospitalMap.tscn`

这条链路的目标是：

- 从后端拉 snapshot
- 显示地图
- 显示患者位置
- 做 demo / step / reset

它不是视频里那种“`BaseNpc` 对话泡泡 + 本地 flow”的 baseline。

### 4.2 依赖链不同

#### 视频 baseline 链路

`room1.tscn`
→ `BaseNpc` 子类场景
→ `DialogueManager`
→ `ConversationManager`
→ `MockDialogueSystem`
→ `DialogueBubble`
→ `data/mock_flows.json`

#### Main_EDMAS 链路

`Main_EDMAS.tscn`
→ `APIClient`
→ `PatientManager`
→ `HospitalMapManager`
→ `PatientSprite`
→ 后端 `/api/godot/*`

两条链路的目标完全不同，所以“视频能跑、Main_EDMAS 失败”并不矛盾。

---

## 5. 是否依赖后端

### 5.1 视频 baseline

**不依赖后端。**

证据：

- `scripts/dialogue/mock_dialogue_system.gd` 只读本地 `res://data/mock_flows.json`
- `scripts/base_npc.gd` 的对话行为是本地状态机
- `DialogueManager` 只负责泡泡分配和位置跟随

### 5.2 Main_EDMAS

**依赖后端。**

证据：

- `scripts/edmas/api_client.gd` 通过 HTTP 请求 `/api/godot/snapshot`、`/api/godot/step`、`/api/godot/user_turn` 等接口
- `main_edmas.gd` 的 UI 按钮会驱动这些 API

---

## 6. 是否依赖 MemoryStore / Scheduler / BaseNpc

### 6.1 BaseNpc

**视频 baseline 依赖 `BaseNpc`。**

证据：

- `scripts/nurse.gd`
- `scripts/nurse_blue.gd`
- `scripts/nurse_green.gd`
- `scripts/scrubs_blue.gd`
- `scripts/scrubs_green.gd`
- `scripts/patient_blue.gd`
- `scripts/patient_green.gd`

这些脚本都 `extends BaseNpc`。

### 6.2 MemoryStore

**有依赖，但属于“辅助记忆”，不是视频里气泡显示的核心前提。**

证据：

- `scripts/base_npc.gd` 会在 `_ready()` 里尝试加载 `res://scripts/dialogue/memory_store.gd`
- `scripts/base_npc.gd` 内部使用 `_memory` 保存对话/思考记录

也就是说：

- 没有 MemoryStore，视频里的基础对白气泡链路理论上仍应能出现
- 但如果 `BaseNpc` 构造或脚本加载因 MemoryStore/路径/类名异常而中断，NPC 运行会失败

### 6.3 Scheduler / session

**当前仓库的这个视频 baseline 不依赖 Scheduler / session。**

证据：

- 当前仓库未找到 `scripts/edmas/scheduler/session.gd`
- `room1.tscn` 也没有引用该路径
- `MockDialogueSystem` 直接基于本地 flow 推进，不需要调度器

### 6.4 你当前看到的失败链路

如果你现在的 `Main_EDMAS` 或某些新整合链路里报：

- `MemoryStore not found in BaseNpc`
- `BaseNpc parse failure`
- `map_npc extends BaseNpc failure`
- `NpcManager creates plain CharacterBody2D`
- `npc_display_name / reset_memory / get_memory missing`

这说明你走的是**新接入/改造链路**，而不是 `room1.tscn` 这条视频 baseline。

---

## 7. 为什么 Main_EDMAS 现在会失败，而视频 baseline 能工作

### 7.1 根因 1：场景目的不同

`room1.tscn` 的设计目标是：

- 本地 NPC
- 本地对白
- 本地 bubble
- 本地随机走动 / 对话展示

`Main_EDMAS.tscn` 的设计目标是：

- 后端驱动 snapshot
- 患者状态显示
- 地图切换
- demo 回放 / step / reset

因此二者不是同一条运行链。

### 7.2 根因 2：依赖层不同

视频 baseline 已经有完整的本地依赖：

- `BaseNpc`
- `DialogueManager`
- `ConversationManager`
- `MockDialogueSystem`
- `DialogueBubble`

而 `Main_EDMAS` 的链路需要：

- 后端 API
- `PatientManager`
- `HospitalMapManager`
- `PatientSprite`

两边只共享“医院题材”，不共享“运行架构”。

### 7.3 根因 3：资源命名与类期望必须对齐

`BaseNpc` 这条链路对资源文件名非常敏感，它会按固定命名加载 frame：

- `idle_down.png`
- `idle_up.png`
- `walk_down_a.png`
- `walk_down_b.png`
- 等等

如果资源命名或目录不对，就会出现 parse / resource load failure。

所以视频 baseline 能成功，说明当时那套资产和脚本是对齐的；而新整合链路中，如果文件名或类名没有同步，就会失败。

---

## 8. 最小安全合并计划

如果后续要把“视频 baseline 的可见性”安全合并到 `Main_EDMAS`，建议只做下面这个最小计划：

1. **保留 `room1.tscn` 不动**，把它作为本地 NPC 对话基线场景。
2. **不要先改后端**，先保证 `BaseNpc + DialogueManager + MockDialogueSystem` 单独可跑。
3. **把 `Main_EDMAS` 继续保持为后端驱动场景**，不要把它强行改成 `BaseNpc` 世界。
4. 如果要把视频里的气泡效果迁移到 `Main_EDMAS`，应当只迁移：
   - `DialogueBubble`
   - `DialogueManager`
   - `MockDialogueSystem`
   而不是整套 `NpcManager / Scheduler / MapNpc`
5. 先确定一条主链路，再决定是否与 API 驱动链路共存。

---

## 9. 你现在可以直接引用的文件清单

### 场景

- `D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-\scens\room1.tscn`
- `D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-\scens\edmas\Main_EDMAS.tscn`

### 对话与 NPC

- `D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-\scripts\base_npc.gd`
- `D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-\scripts\dialogue\dialogue_manager.gd`
- `D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-\scripts\dialogue\conversation_manager.gd`
- `D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-\scripts\dialogue\dialogue_bubble.gd`
- `D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-\scripts\dialogue\mock_dialogue_system.gd`
- `D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-\scripts\dialogue\memory_store.gd`

### 数据

- `D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-\data\mock_flows.json`
- `D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-\data\npcs\患者.json`
- `D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-\data\npcs\分诊护士.json`

### 目前不在本仓库中的条目

- `scripts/edmas/npc_manager.gd`
- `scripts/edmas/map_npc.gd`
- `scripts/edmas/scheduler/session.gd`

这些文件名在当前仓库里**未找到**，所以不能把它们当作视频 baseline 的证据。

---

## 10. 最终判断

**视频 baseline 最可能使用的是 `room1.tscn`，走的是纯本地对话链路，不依赖后端。**

**`Main_EDMAS` 失败的原因，是它已经切到另一条“后端驱动 + 患者状态同步”的新架构，和视频 baseline 不是同一套运行系统。**

