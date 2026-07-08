# Fix Summary Since Commit 492c759

本文档记录从 `492c759 Step 4A-1 add session prompt context` 开始到当前 `main` 的主要修改、修复原因和验收点。

## 提交范围

- `492c759` Step 4A-1 add session prompt context
- `d31f207` Step 4A-2 add scheduler patient plan
- `47f0b8d` Step 4A-3 switch dialogue test to scheduler
- `6409521` Add Step 4A Godot script UIDs
- `4b00091` Reduce dialogue bubble spam
- `e359cd5` Relax dialogue utterance limits
- `b6152ba` Start interactions with clinician
- `56e3ac6` Use public patient dialogue for clinician prompts
- `4253d5d` Start clinician sessions with open intake
- `ef47eb0` Expire dialogue bubbles on turn changes
- `2a008e4` Walk patients to exit before discharge

## 核心功能变化

### 1. 引入 Session + Scheduler

新增 `scripts/edmas/scheduler/`：

- `session.gd`
  - 管理一次有边界的交互。
  - 每个 session 拥有独立响应队列、显示状态和安全超时。
  - session 结束时释放资源并清理参与者气泡。
- `session_types/interaction_session.gd`
  - 管理医护和患者之间的 A/B 交互。
  - 支持分诊护士 session 和医生 session。
  - 根据 agent 输出的 `conversation_done` 和 `next_step` 结束并返回结果。
- `scheduler.gd`
  - 作为 autoload 注册。
  - 监听患者到达、资源释放、患者出院事件。
  - 负责资源仲裁、pending session 唤醒、下一阶段派发。

目的：替换原来 `NpcManager.start_auto_loop` 的单患者、单护士硬编码乒乓流程，支持多患者、多护士、多医生并行和等待。

### 2. 引入资源仲裁和患者计划

新增/扩展：

- `scripts/edmas/world/patient_plan.gd`
  - 跟踪患者当前阶段。
  - 根据 `next_step` 推进到医生、出院或后续检查阶段。
- `scripts/edmas/world/resource_registry.gd`
  - 动态注册 spawn 出来的护士和医生为 staff resource。
  - 支持 busy/queue 状态，供 Scheduler 仲裁。

效果：

- 前两个患者可同时进入护士 session。
- 后续患者会进入等待队列。
- 医生资源忙时患者等待，空闲后自动派发。

### 3. 配置驱动场景生成

新增：

- `scripts/edmas/scenario_config.gd`

默认生成：

- 2 名分诊护士
- 2 名医生
- 5 名患者

`scens/edmas/DialogueTest.gd` 改为启动后调用 `NpcManager.spawn_scenario(ScenarioConfig.DEFAULT)`，不再依赖场景内预摆的 `NPC_Nurse / NPC_Patient` 节点。

### 4. 医护和患者的 prompt 上下文修正

新增：

- `scripts/edmas/scheduler/prompt_context.gd`

重要修复：

- 患者可以读取自己的隐藏病例。
- 护士和医生不能读取患者隐藏病例。
- 护士/医生只能根据患者已经说出口的信息、护士分诊记录和公开对话 memory 判断。
- 医护第一句必须是开放式问诊，例如询问哪里不舒服、症状多久了，不能凭空诊断或直接安排下一步。

当前对话顺序：

1. 护士或医生先发起开放式问诊。
2. 患者根据自己的隐藏病例回答。
3. 医护根据公开对话继续追问、判断并输出 `next_step`。

### 5. 对话气泡显示修复

修改：

- `scripts/dialogue/dialogue_bubble.gd`
- `scripts/dialogue/dialogue_manager.gd`
- `scripts/edmas/scheduler/session.gd`

修复点：

- 长对话默认只显示摘要，后续以 `...` 省略。
- 点击气泡可展开完整内容。
- 不再逐条长时间堆叠 utterance。
- 气泡超过最长显示时间会消失。
- A/B 对话轮替时，下一句出现会让上一方旧气泡消失。
- session 结束时清理参与者气泡。
- 气泡淡出后会清空 NPC 的 `_current_entry`，避免同一句被重新显示。

### 6. 旧 memory 污染修复

修改：

- `scripts/dialogue/memory_store.gd`
- `scripts/base_npc.gd`
- `scripts/edmas/npc_manager.gd`

原因：动态 NPC 名称如 `NPC_Patient_001` 会复用，Godot `user://npc_memories/` 中的旧对话可能污染下一次 demo。

修复：

- `MemoryStore.clear()` 清空持久化 memory。
- `BaseNpc.reset_memory()` 暴露清理接口。
- `NpcManager.register_npc()` 对动态注册 NPC 执行 memory reset。

### 7. 出院流程修复

修改：

- `scripts/edmas/npc_manager.gd`
- `scripts/edmas/scheduler/scheduler.gd`

修复前：患者流程结束后原地 `queue_free()` 消失。

修复后：

1. 患者清空气泡。
2. 患者走回 `ED_ENTRANCE`。
3. 到达入口后设置为 `DISCHARGED` 并移除。
4. 若导航异常，最多等待 20 秒后兜底移除。
5. Scheduler 监听 `patient_discharged`，所有患者真正消失后打印结束态。

## 主要文件变更

- `project.godot`
  - 新增 `Scheduler` autoload。
- `scens/edmas/DialogueTest.gd`
  - 改为配置驱动 spawn。
- `scens/edmas/DialogueTest.tscn`
  - 移除预置 NPC。
- `scripts/edmas/npc_manager.gd`
  - 移除旧自动乒乓流程。
  - 新增动态 spawn、角色注册、出院移动。
- `scripts/edmas/conversation_context.gd`
  - 泛化 memory 路由。
  - 不再依赖单一 active patient。
- `scripts/edmas/scheduler/*`
  - 新增 Session/Scheduler 主体。
- `scripts/dialogue/*`
  - 修复气泡摘要、展开、超时、轮替清理。
- `scripts/base_npc.gd`
  - 增加 memory reset。
  - 兼容 doctor frame 命名加载。

## 验收点

### 多患者并行

- F5 打开 `scens/edmas/DialogueTest.tscn`。
- 应看到 2 名护士、2 名医生、5 名患者。
- 至少两个患者可同时进入分诊。
- 资源忙时，其余患者进入等待区。

### 对话顺序

- 医护第一句应为开放式问诊。
- 患者随后描述症状。
- 护士/医生不应在患者描述前直接知道疾病或安排诊疗。
- 医生应能看到患者口述和护士分诊记录，而不是隐藏病例。

### 气泡显示

- 等待提示不会常显。
- 患者去下一步后，旧症状气泡应消失。
- A 说话时，B 的上一句开始消失；B 说话时，A 的上一句开始消失。
- 长话只显示摘要，点击可展开详情。

### 出院结束

- 患者完成流程后应走回 `ED_ENTRANCE` 再消失。
- 所有患者消失后，控制台应出现 `[Scheduler] All patients discharged`。

## 当前限制

- Step 4A 阶段仍暂时忽略设备 orders，例如 `ct_scan / lab_test / ecg`，收到后会 warning 并按出院路径处理。
- 结束动画尚未接入。当前结束态只打印日志，后续可在 `Scheduler._check_all_discharged()` 处挂动画或场景切换。
- 当前没有可用的命令行 Godot 环境进行自动化运行验证，主要通过静态检查和 Godot 编辑器手动 F5 验收。
