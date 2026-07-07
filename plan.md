# EDMAS Backend Pipeline Implementation Plan

## 1. 执行原则

本计划用于指导后续代码实现，目标是按 `prd.md` 做出 P0 可用闭环：

`SimulationSpec 输入 -> 后端校验与会话 -> Mock/Agent 生成 ActionPlan -> 转换 DemoTimeline -> Godot 自动播放 -> 回传事件与日志`

执行时遵守以下原则：

- 先做本地可跑的 deterministic mock backend，再接真实 LLM/Agent。
- Godot 只理解 `DemoTimeline`，不承载医学推理。
- 后端 schema 是唯一输入输出契约，Godot 与 Agent 都围绕 schema 对齐。
- P0 优先跑通一个“急诊头痛分诊 + CT 建议”案例。
- 不重构现有 NPC 动画资源，不重命名 `scens/`。
- 所有 JSON、API、日志统一 UTF-8。

## 2. 推荐新增代码结构

```text
backend/
  README.md
  pyproject.toml
  app/
    __init__.py
    main.py
    config.py
    api/
      __init__.py
      routes_simulations.py
      routes_health.py
    schemas/
      __init__.py
      common.py
      simulation.py
      plan.py
      timeline.py
      events.py
    services/
      __init__.py
      simulation_service.py
      validation_service.py
      world_state_service.py
      agent_service.py
      timeline_service.py
      log_service.py
    agents/
      __init__.py
      base.py
      mock_agent.py
      openai_agent.py
    storage/
      __init__.py
      file_store.py
    data/
      examples/
        headache_triage.simulation.json
        headache_triage.timeline.json
    tests/
      test_validation.py
      test_plan_generation.py
      test_timeline_generation.py
      test_api_simulations.py

scripts/
  timeline/
    timeline_loader.gd
    timeline_player.gd
    timeline_action.gd
    actor_registry.gd
    device_registry.gd

data/
  simulations/
    headache_triage.json
  timelines/
    headache_triage.timeline.json
```

说明：

- `backend/` 是后端服务，建议使用 Python + FastAPI + Pydantic。
- `backend/app/schemas/` 定义 `SimulationSpec`、`ActionPlan`、`DemoTimeline`、事件回传等契约。
- `backend/app/services/` 写业务编排，避免 API 路由直接堆逻辑。
- `backend/app/agents/mock_agent.py` 先输出稳定流程，P0 验收依赖它。
- `backend/app/agents/openai_agent.py` 预留真实 Agent 接入点，P0 可以先空实现或配置关闭。
- `scripts/timeline/` 是 Godot 侧 timeline 播放器，和现有 `scripts/dialogue/` 解耦。
- `data/simulations/` 与 `data/timelines/` 放 Godot 本地模式可读取的样例文件。

## 3. 阶段 0：准备与基线确认

### 目标

确认当前项目可作为 Godot 播放端继续扩展，不破坏现有 mock 对话系统。

### 涉及文件

- 只读确认：
  - `project.godot`
  - `scens/room1.tscn`
  - `scripts/base_npc.gd`
  - `scripts/dialogue/dialogue_entry.gd`
  - `scripts/dialogue/dialogue_manager.gd`
  - `scripts/dialogue/conversation_manager.gd`
  - `scripts/dialogue/mock_dialogue_system.gd`
  - `data/mock_flows.json`

### 需要做什么

1. 记录现有 autoload：`DialogueManager`、`TimeSystem`。
2. 确认所有 NPC 都在 `npcs` group 中可被发现。
3. 确认 `DialogueEntry` 字段可以承载 timeline 的 `speak` 动作。
4. 确认 `MockDialogueSystem` 未来可被开关控制，避免和 timeline 播放器同时抢气泡。

### 验收

- 能列出当前 Godot 展示接口与新增 timeline 播放器的衔接点。
- 不改动现有运行逻辑。
- 明确 P0 要增加一个“关闭 mock 自动对话”的配置项或运行模式。

## 4. 阶段 1：定义后端 Schema

### 目标

把 `prd.md` 中的输入输出契约落成可校验代码。

### 新增文件

- `backend/app/schemas/common.py`
- `backend/app/schemas/simulation.py`
- `backend/app/schemas/plan.py`
- `backend/app/schemas/timeline.py`
- `backend/app/schemas/events.py`
- `backend/tests/test_validation.py`

### 需要做什么

1. 在 `common.py` 定义通用模型：
   - `Position`
   - `ValidationWarning`
   - `ApiError`
   - `EntityRef`
2. 在 `simulation.py` 定义：
   - `SimulationSpec`
   - `SceneSpec`
   - `LocationSpec`
   - `ActorSpec`
   - `PatientSpec`
   - `DiseaseSpec`
   - `DeviceSpec`
   - `ObjectiveSpec`
   - `WorldState`
3. 在 `plan.py` 定义：
   - `ActionPlan`
   - `PlanStep`
4. 在 `timeline.py` 定义：
   - `DemoTimeline`
   - `TimelineAction`
   - P0 动作类型枚举：`spawn_actor`、`move_to`、`face_actor`、`speak`、`wait`、`use_device`、`set_state`、`end_simulation`
5. 在 `events.py` 定义：
   - `GodotEvent`
   - `ActionCompletedEvent`
   - `ActionFailedEvent`
6. 编写 schema 单元测试，覆盖：
   - 必填字段缺失
   - 非法 actor/device/location 引用
   - 非法动作类型
   - 关闭随机性时输出稳定

### 验收

- `headache_triage.simulation.json` 能被 schema 校验通过。
- 缺少 `scene.locations`、`actors.id`、`patients.actor_id` 等字段时测试失败并返回字段级错误。
- `DemoTimeline` 至少能表达 PRD P0 的所有动作类型。

## 5. 阶段 2：后端服务骨架

### 目标

提供 P0 API 的可运行框架。

### 新增文件

- `backend/pyproject.toml`
- `backend/README.md`
- `backend/app/main.py`
- `backend/app/config.py`
- `backend/app/api/routes_health.py`
- `backend/app/api/routes_simulations.py`
- `backend/app/services/simulation_service.py`
- `backend/app/storage/file_store.py`
- `backend/tests/test_api_simulations.py`

### API

- `GET /api/health`
- `POST /api/simulations`
- `POST /api/simulations/{simulation_id}/plan`
- `GET /api/simulations/{simulation_id}/timeline`
- `POST /api/simulations/{simulation_id}/agent/step`
- `POST /api/simulations/{simulation_id}/events`

### 需要做什么

1. 建立 FastAPI app。
2. `POST /api/simulations` 接收 `SimulationSpec`，生成 `simulation_id`。
3. 使用 `file_store.py` 将 session 写入本地：
   - `backend/runtime/simulations/{simulation_id}/input.json`
   - `backend/runtime/simulations/{simulation_id}/world_state.json`
   - `backend/runtime/simulations/{simulation_id}/events.jsonl`
4. API 返回 `simulation_id`、`status`、`world_state`、`warnings`。
5. 增加统一错误响应。

### 验收

- `GET /api/health` 返回 `{"ok": true}`。
- 创建模拟后，runtime 目录出现对应 session 文件。
- 输入非法时返回 422 或业务错误，不创建不完整 session。
- API 测试能覆盖成功创建和失败创建。

## 6. 阶段 3：WorldState 与输入校验

### 目标

把用户输入转成后端可持续更新的世界状态，并在生成计划前拦截错误。

### 新增/修改文件

- `backend/app/services/validation_service.py`
- `backend/app/services/world_state_service.py`
- `backend/app/services/simulation_service.py`
- `backend/tests/test_validation.py`

### 需要做什么

1. 校验所有 ID 唯一：
   - actors
   - patients
   - diseases
   - devices
   - locations
   - objectives
2. 校验引用存在：
   - `ActorSpec.location_id`
   - `PatientSpec.actor_id`
   - `PatientSpec.disease_ids`
   - `DeviceSpec.location_id`
3. 校验 sprite 属于 P0 白名单。
4. 根据输入生成 `WorldState`：
   - `time`
   - `actors`
   - `patients`
   - `devices`
   - `locations`
   - `objectives`
   - `events`
5. 生成 warnings：
   - actor 数量超过 Godot 当前可绑定 NPC 数量
   - 设备类型在 Godot 侧没有视觉节点
   - 缺少可处理某疾病的医生或护士

### 验收

- 引用不存在时返回清晰错误，例如 `patients[0].actor_id not found`。
- 合法输入能生成完整 `WorldState`。
- warnings 不阻断创建，但会出现在 API 响应中。

## 7. 阶段 4：Mock Agent 与 ActionPlan

### 目标

先不用真实 LLM，基于输入病例稳定生成 P0 可验收的 `ActionPlan`。

### 新增文件

- `backend/app/agents/base.py`
- `backend/app/agents/mock_agent.py`
- `backend/app/services/agent_service.py`
- `backend/tests/test_plan_generation.py`

### 需要做什么

1. 定义 `BaseAgent` 接口：
   - `generate_plan(simulation, world_state) -> ActionPlan`
   - `step(actor_id, target_actor_id, intent, context) -> AgentStepResult`
2. 实现 `MockAgent`：
   - 根据 objective 类型 `triage` 生成头痛分诊流程。
   - 根据 disease 的 `recommended_checks` 插入设备使用步骤。
   - 输出每一步的 `think` 与 `dialogue`。
3. `POST /api/simulations/{id}/plan` 调用 `agent_service`。
4. 将 `ActionPlan` 保存到：
   - `backend/runtime/simulations/{id}/plan.json`
5. 支持 deterministic 模式：
   - 固定 step id 顺序
   - 固定 dialogue 模板

### P0 头痛分诊最小计划

1. 护士询问病人主诉。
2. 病人回答头痛情况。
3. 护士建议 CT 检查。
4. 病人移动/准备前往 CT。
5. CT 设备生成检查结果。
6. 医生复核并告知初步处理建议。
7. 结束演示。

### 验收

- `POST /plan` 返回至少 5 个 `steps`。
- 至少包含 2 个 `speak` 语义步骤。
- 至少包含 1 个设备相关语义步骤。
- 同一输入生成相同 `ActionPlan`。

## 8. 阶段 5：Timeline 生成器

### 目标

把语义层 `ActionPlan` 转成 Godot 可直接播放的 `DemoTimeline`。

### 新增文件

- `backend/app/services/timeline_service.py`
- `backend/tests/test_timeline_generation.py`
- `backend/app/schemas/timeline.py`

### 需要做什么

1. 将 plan step 转换为 timeline action。
2. 为每个 action 分配：
   - `id`
   - `time`
   - `duration`
   - `type`
   - `actor_id`
   - `target_actor_id`
   - `location_id`
   - `payload`
3. 对 `speak` 动作设置：
   - `think`
   - `dialogue`
   - `priority`
   - `duration`
4. 对 `use_device` 动作设置：
   - `device_id`
   - `operation_duration`
   - `result`
5. 对 `move_to` 动作使用 `location_id` 的坐标。
6. 在末尾插入 `end_simulation`。
7. 保存到：
   - `backend/runtime/simulations/{id}/timeline.json`
   - 可选复制到 `data/timelines/headache_triage.timeline.json` 用于 Godot 本地模式。

### 验收

- `GET /timeline` 返回有效 `DemoTimeline`。
- 时间线至少包含：
  - 1 个 `move_to`
  - 2 个 `speak`
  - 1 个 `use_device`
  - 1 个 `end_simulation`
- 所有 `actor_id`、`device_id`、`location_id` 都能在输入 spec 或 world state 中解析。
- action 的 `time` 单调递增。

## 9. 阶段 6：Godot Timeline 播放器

### 目标

Godot 能脱离 mock flow，读取 `DemoTimeline` 并自动演示。

### 新增文件

- `scripts/timeline/timeline_action.gd`
- `scripts/timeline/timeline_loader.gd`
- `scripts/timeline/timeline_player.gd`
- `scripts/timeline/actor_registry.gd`
- `scripts/timeline/device_registry.gd`

### 修改文件

- `project.godot`
- `scens/room1.tscn`
- `scripts/dialogue/dialogue_manager.gd`
- 可能涉及各 NPC 脚本或 `BaseNpc`

### 需要做什么

1. `timeline_loader.gd`
   - 从 `res://data/timelines/headache_triage.timeline.json` 加载本地 timeline。
   - P1 再支持 HTTP 拉取。
2. `actor_registry.gd`
   - 建立 `actor_id -> BaseNpc` 映射。
   - P0 可以在场景中手动配置 export 映射。
3. `device_registry.gd`
   - 建立 `device_id -> Node2D/Marker2D` 映射。
   - P0 没有设备节点时可用 location marker 表示。
4. `timeline_player.gd`
   - 顺序执行 action。
   - 支持 `move_to`、`face_actor`、`speak`、`wait`、`use_device`、`set_state`、`end_simulation`。
5. `speak`
   - 创建 `DialogueEntry`。
   - 调用现有 `BaseNpc.speak(entry)`。
   - 根据 `duration` 调用 `stop_speaking()`。
6. `move_to`
   - P0 使用直线移动到目标坐标。
   - 到达或超时后完成 action。
7. `use_device`
   - P0 用设备状态文字、气泡或简单状态日志表达。
   - 若没有设备视觉节点，至少通过相关 actor 的气泡说明设备使用完成。
8. `end_simulation`
   - 停止播放。
   - 打印或记录完成事件。
9. 增加 mock flow 开关：
   - 当 timeline 模式开启时，不自动启动 `MockDialogueSystem`。

### 验收

- 打开 Godot 主场景后，timeline 模式能自动播放本地 JSON。
- NPC 会移动到指定位置。
- 气泡显示 `think` 与 `dialogue`。
- 播放过程中不会和 `MockDialogueSystem` 随机对话冲突。
- 结束时能看到完成日志。

## 10. 阶段 7：Godot 与后端事件对接

### 目标

Godot 执行动作后能向后端回传进度，为完整闭环和日志做准备。

### 新增/修改文件

- `scripts/timeline/timeline_player.gd`
- `scripts/timeline/timeline_loader.gd`
- `backend/app/api/routes_simulations.py`
- `backend/app/services/log_service.py`
- `backend/app/storage/file_store.py`

### 需要做什么

1. 后端实现 `POST /api/simulations/{id}/events`。
2. Godot 每完成一个 action 生成事件：
   - `timeline_action_started`
   - `timeline_action_completed`
   - `timeline_action_failed`
   - `simulation_completed`
3. P0 如果 HTTP 在导出环境受限，至少先支持本地打印事件，并保留 HTTP client 代码路径。
4. 后端将事件追加写入 `events.jsonl`。
5. 后端根据事件更新 `WorldState` 中的 action 状态。

### 验收

- 完整播放后，后端日志包含所有 action 的 completed 事件。
- 失败 action 能产生 failed 事件和错误 payload。
- `simulation_completed` 事件出现后，session 状态变为 `completed`。

## 11. 阶段 8：端到端样例与回归测试

### 目标

形成 P0 演示用固定案例，后续每次修改都可快速验证。

### 新增文件

- `backend/app/data/examples/headache_triage.simulation.json`
- `backend/app/data/examples/headache_triage.timeline.json`
- `data/simulations/headache_triage.json`
- `data/timelines/headache_triage.timeline.json`
- `backend/tests/test_e2e_headache_triage.py`

### 需要做什么

1. 编写头痛分诊输入 JSON：
   - 1 名医生
   - 1 名护士
   - 1 名病人
   - 1 个疾病/病例
   - 1 台 CT 设备
   - 2 个地点
   - 1 个分诊目标
2. 用后端生成 plan 和 timeline。
3. 将 timeline 放入 Godot 本地数据目录。
4. Godot 播放并人工观察。
5. 后端测试覆盖完整 API 调用顺序。

### 验收

- 一条命令或一组明确命令可生成 timeline。
- Godot 播放时能完整演示头痛分诊闭环。
- 后端测试通过。
- `data/timelines/headache_triage.timeline.json` 与 schema 一致。

## 12. 阶段 9：真实 Agent 接入预留

### 目标

在 P0 mock 闭环稳定后，给真实 Agent 留出清晰入口，不影响现有验收。

### 新增/修改文件

- `backend/app/agents/openai_agent.py`
- `backend/app/services/agent_service.py`
- `backend/app/config.py`
- `backend/tests/test_plan_generation.py`

### 需要做什么

1. `agent_service` 根据配置选择：
   - `mock`
   - `openai`
2. `openai_agent.py` 输入：
   - `SimulationSpec`
   - `WorldState`
   - 可用动作 schema
   - 医学安全声明
3. `openai_agent.py` 输出必须经过 `ActionPlan` schema 校验。
4. 校验失败时回退到 `MockAgent`，并记录 fallback log。

### 验收

- 未配置 API key 时仍能使用 mock 模式完成 P0。
- 配置真实 Agent 后，输出非法 JSON 不会击穿系统。
- fallback 事件会写入日志。

## 13. 阶段 10：P1 扩展规划

### 目标

在 P0 之后支持动态事件、多案例和优先级打断。

### 未来新增/修改文件

- `backend/app/api/routes_interrupts.py`
- `backend/app/services/replan_service.py`
- `backend/app/services/summary_service.py`
- `backend/app/data/examples/trauma_rescue.simulation.json`
- `backend/app/data/examples/lab_result.simulation.json`
- `scripts/timeline/timeline_interrupt_handler.gd`

### 需要做什么

1. 支持 `POST /api/simulations/{id}/interrupt`。
2. 支持中途重规划，并生成 timeline patch。
3. Godot 支持插入高优先级 action。
4. 与现有 `ConversationManager` 对齐优先级规则。
5. 支持演示总结：
   - 完成了哪些 success conditions
   - 哪些关键步骤缺失
   - 角色对话日志
   - 设备与病人状态变化

### 验收

- 插入“生命体征恶化”事件后，原 timeline 被打断或追加抢救流程。
- 高优先级对话能覆盖低优先级对话。
- 至少支持 3 个案例自动生成和播放。

## 14. 具体执行顺序

推荐按以下顺序执行，每一步都要完成验收再进入下一步：

1. 后端 schema 与样例输入。
2. 后端 API 骨架。
3. validation + world state。
4. mock agent 生成 ActionPlan。
5. timeline service 生成 DemoTimeline。
6. Godot 本地 timeline 播放器。
7. Godot 事件回传后端。
8. 头痛分诊端到端验收。
9. 真实 Agent 预留接口。
10. P1 动态重规划。

## 15. P0 总验收清单

### 后端

- `GET /api/health` 正常。
- `POST /api/simulations` 能创建 session。
- `POST /api/simulations/{id}/plan` 能生成 `ActionPlan`。
- `GET /api/simulations/{id}/timeline` 能生成 `DemoTimeline`。
- `POST /api/simulations/{id}/agent/step` 能返回 `think`、`dialogue` 和 actions。
- `POST /api/simulations/{id}/events` 能记录 Godot 事件。
- 非法输入有字段级错误。
- 同一输入在 mock 模式下输出稳定。

### Godot

- timeline 模式不会启动随机 mock 对话。
- 能加载本地 timeline。
- 能绑定 actor 到现有 NPC 节点。
- 能执行 `move_to`。
- 能执行 `speak` 并显示两阶段气泡。
- 能执行 `use_device`。
- 能执行 `end_simulation`。
- 能记录或回传 action 完成事件。

### 端到端

- 头痛分诊案例完整播放。
- 时间线包含至少 1 个移动、2 个对话、1 个设备使用、1 个结束动作。
- 后端日志包含输入、plan、timeline、Godot events、最终状态。
- 演示可重复运行，结果一致。

## 16. 风险控制

- 如果 FastAPI 依赖暂时无法安装，先用本地 Python 脚本生成 plan/timeline，保持 schema 与服务层代码可迁移。
- 如果 Godot HTTP 受限，P0 先走本地 JSON，事件回传先打印，再接 HTTP。
- 如果动态生成 NPC 太复杂，P0 固定使用现有场景 NPC，通过 `actor_id` 映射绑定。
- 如果设备缺少可视节点，P0 用地点 marker 和对话说明表达设备动作。
- 如果真实 Agent 输出不稳定，默认关闭真实 Agent，mock 模式作为验收基线。
