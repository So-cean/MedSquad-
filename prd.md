# EDMAS Backend Pipeline PRD

## 1. 背景与目标

EDMAS 当前是一个 Godot 4.7 医院主题 2D 俯视角演示项目，已有固定 NPC、mock 对话流、气泡展示、对话优先级与记忆雏形。下一阶段目标是梳理并实现完整的后端输入输出流水线，使用户可以自定义医生、病人、疾病、护士、设备等医疗场景要素；Agent 可以通过 API 生成对话、行为和事件；Godot 负责把后端输出自动化展示为动画演示。

本 PRD 只定义需求、接口边界、优先级与验收方案，不涉及代码实现。

## 2. 现状功能接口

### 2.1 Godot 已有展示与调度接口

- 主场景：`res://scens/room1.tscn`
- 全局 Autoload：
  - `DialogueManager`：注册 NPC、分配对话气泡、管理 `ConversationManager` 和 `MockDialogueSystem`
  - `TimeSystem`：游戏内时间系统
- NPC 基类：`BaseNpc`
  - `get_npc_name() -> String`
  - `speak(entry: DialogueEntry) -> void`
  - `stop_speaking() -> void`
  - `record_dialogue(listener, think, dialogue, importance)`
  - `get_memory_context(count) -> String`
- 对话数据结构：`DialogueEntry`
  - `speaker`
  - `think`
  - `dialogue`
  - `target`
  - `mood`
- 对话配对与打断：`ConversationManager.request_speak(speaker, listener, priority) -> Dictionary`
- Mock 输入文件：`data/mock_flows.json`
  - `flows[].name`
  - `flows[].priority_base`
  - `flows[].steps[]`
  - step 字段：`speaker`、`listener`、`think`、`dialogue`、`duration`、`priority`
- NPC 知识库：`data/npcs/*.json`
  - `npc_name`
  - `role`
  - `personality`
  - `priority_default`
  - `knowledge`
  - `scratch`

### 2.2 当前主要缺口

- 输入仍是静态 mock JSON，无法从外部 API 动态提交场景。
- 医生、病人、疾病、护士、设备等实体没有统一 schema。
- Agent 没有标准 API 可调用，无法按状态生成下一步行动。
- 后端输出缺少面向 Godot 的稳定演示协议，例如移动、等待、说话、使用设备、状态变更。
- Godot 当前只展示对话气泡和随机游走，未能按后端脚本执行完整动画。
- 没有端到端验收标准，无法判断一次医疗模拟是否“成功演示完毕”。

## 3. 产品目标

### 3.1 核心目标

构建一个“自定义医疗场景输入 -> 后端仿真/Agent 决策 -> Godot 自动动画演示”的闭环。

用户可以提交一个医疗模拟案例，例如：

- 有哪些医生、护士、病人、设备和空间
- 病人的疾病、症状、体征、检查结果和风险等级
- 医护人员的职责、知识、个性和优先级
- 希望模拟的任务目标，例如分诊、检查、抢救、手术准备、查房

系统输出一段 Godot 可播放的自动化演示：

- 角色移动到指定地点或对象附近
- 角色之间按优先级对话
- 角色调用设备、检查、下医嘱、等待结果
- 对话气泡展示 Agent 的思考和实际发言
- 演示结束后返回结构化总结和事件日志

### 3.2 非目标

- P0 阶段不实现真实医学诊断系统，只做可配置的医疗流程模拟。
- P0 阶段不要求多人联网和实时编辑。
- P0 阶段不要求 Godot 内置 LLM 调用，LLM/Agent 逻辑优先放在后端。
- P0 阶段不做复杂路径规划，允许使用预设锚点和简单移动。

## 4. 用户与使用场景

### 4.1 目标用户

- 医疗流程教学内容制作人
- 医学生、护士培训人员
- 医院流程演示或应急演练设计者
- 游戏/仿真开发者

### 4.2 典型场景

1. 急诊分诊：病人主诉头痛，分诊护士判断需要 CT，医生查看结果后安排进一步处理。
2. 创伤抢救：急救护士接收车祸病人，通知手术医生，设备和手术室进入准备状态。
3. 检验闭环：护士送检，检验设备生成结果，检验科护士通知医生调整治疗。
4. 住院查房：护士和医生根据病人状态完成查房、用药说明和复查安排。

## 5. 端到端流水线

### 5.1 P0 流水线

1. 用户提交 `SimulationSpec`。
2. 后端校验输入 schema，生成初始世界状态。
3. 后端创建 simulation session，返回 `simulation_id`。
4. Agent 根据病例、角色、设备、目标生成 `ActionPlan`。
5. 后端把 `ActionPlan` 转换为 Godot 可执行的 `DemoTimeline`。
6. Godot 拉取或接收 `DemoTimeline`。
7. Godot 按时间线执行移动、说话、等待、使用设备、状态变更。
8. Godot 回传播放进度、错误和完成状态。
9. 后端返回事件日志、对话日志、最终状态和演示总结。

### 5.2 后续 P1/P2 流水线增强

- 支持演示过程中用户插入新事件，例如“突然血压下降”。
- 支持 Agent 多轮协商和工具调用。
- 支持保存、复用、回放、导出多个案例。
- 支持评分与教学反馈。

## 6. 输入需求

### 6.1 SimulationSpec

P0 必须支持一个完整场景输入对象：

```json
{
  "title": "急诊头痛分诊演示",
  "locale": "zh-CN",
  "scene": {
    "map_id": "room1",
    "start_time": "08:00",
    "locations": [
      {"id": "triage_desk", "name": "分诊台", "position": {"x": 550, "y": 300}},
      {"id": "ct_room", "name": "CT室", "position": {"x": 290, "y": 343}}
    ]
  },
  "actors": [],
  "patients": [],
  "diseases": [],
  "devices": [],
  "objectives": [],
  "constraints": {}
}
```

### 6.2 角色输入

所有人类角色统一使用 `ActorSpec`：

```json
{
  "id": "doctor_001",
  "display_name": "王医生",
  "type": "doctor",
  "profession": "surgeon",
  "sprite": "scrubs_green",
  "location_id": "or_room",
  "priority_default": 3,
  "personality": "果断、专注、决策快",
  "knowledge": [
    {"condition": "急性阑尾炎", "action": "腹腔镜阑尾切除", "dept": "手术室"}
  ],
  "tools": ["order_exam", "request_transfer", "use_device"],
  "memory": []
}
```

P0 角色类型：

- `doctor`
- `nurse`
- `patient`
- `technician`

P0 可选 sprite：

- `doctor_white`
- `nurse_white`
- `nurse_blue`
- `nurse_green`
- `scrubs_green`
- `scrubs_blue`
- `patient_blue`
- `patient_green`

### 6.3 病人输入

病人使用 `PatientSpec`，并可绑定到一个 `ActorSpec`：

```json
{
  "id": "patient_001",
  "actor_id": "actor_patient_001",
  "name": "李四",
  "age": 45,
  "sex": "male",
  "chief_complaint": "头痛2小时",
  "symptoms": ["头痛", "恶心"],
  "vitals": {
    "temperature": 37.2,
    "heart_rate": 82,
    "blood_pressure": "128/82",
    "spo2": 98
  },
  "allergies": [],
  "medical_history": ["高血压"],
  "disease_ids": ["headache_case_001"],
  "risk_level": 2
}
```

### 6.4 疾病输入

疾病使用 `DiseaseSpec`：

```json
{
  "id": "headache_case_001",
  "name": "待查头痛",
  "severity": "medium",
  "possible_diagnoses": ["偏头痛", "颅内出血待排"],
  "recommended_checks": ["CT"],
  "expected_findings": [
    {"test": "CT", "result": "未见明显出血"}
  ],
  "care_pathway": ["分诊", "CT检查", "医生复核", "用药指导"]
}
```

### 6.5 设备输入

设备使用 `DeviceSpec`：

```json
{
  "id": "ct_001",
  "name": "CT扫描仪",
  "type": "ct_scanner",
  "location_id": "ct_room",
  "status": "idle",
  "capabilities": ["scan"],
  "operation_duration": 5.0,
  "outputs": [
    {"name": "CT报告", "format": "text"}
  ]
}
```

P0 设备类型：

- `ct_scanner`
- `lab_analyzer`
- `ecg_monitor`
- `operation_table`
- `medicine_cart`

### 6.6 目标输入

目标使用 `ObjectiveSpec`：

```json
{
  "id": "obj_001",
  "type": "triage",
  "description": "完成头痛病人的分诊和CT检查建议",
  "success_conditions": [
    "patient_received_triage",
    "ct_exam_ordered",
    "patient_informed"
  ]
}
```

## 7. Agent API 需求

### 7.1 API 设计原则

- 后端是 Agent 的执行宿主，Godot 是演示客户端。
- Agent 不能直接操纵 Godot 节点，只能输出标准动作。
- Agent 每次调用必须包含可追踪的 `simulation_id`、当前世界状态和可用工具。
- Agent 输出必须可校验，失败时后端能回退到规则模板。

### 7.2 必需 API

#### 创建模拟

`POST /api/simulations`

请求：`SimulationSpec`

响应：

```json
{
  "simulation_id": "sim_20260707_001",
  "status": "created",
  "world_state": {},
  "warnings": []
}
```

#### 生成计划

`POST /api/simulations/{simulation_id}/plan`

请求：

```json
{
  "mode": "auto",
  "agent_config": {
    "provider": "openai",
    "model": "configured_backend_default",
    "temperature": 0.3
  }
}
```

响应：`ActionPlan`

#### 获取 Godot 时间线

`GET /api/simulations/{simulation_id}/timeline`

响应：`DemoTimeline`

#### Agent 对话/下一步

`POST /api/simulations/{simulation_id}/agent/step`

请求：

```json
{
  "actor_id": "nurse_001",
  "target_actor_id": "patient_001",
  "intent": "triage_patient",
  "context": {
    "recent_events": [],
    "memory": []
  }
}
```

响应：

```json
{
  "actions": [],
  "think": "根据病人主诉和生命体征，优先排除颅内风险。",
  "dialogue": "您好，根据您的头痛情况，建议先做一次CT检查。",
  "state_patch": {}
}
```

#### Godot 进度回传

`POST /api/simulations/{simulation_id}/events`

请求：

```json
{
  "event_type": "timeline_action_completed",
  "action_id": "act_001",
  "timestamp": 12.5,
  "payload": {}
}
```

响应：

```json
{"ok": true}
```

### 7.3 P1 API

- `POST /api/simulations/{simulation_id}/interrupt`：插入突发事件。
- `GET /api/simulations/{simulation_id}/summary`：获取演示总结。
- `GET /api/simulations/{simulation_id}/logs`：获取事件、对话、Agent 工具调用日志。
- `POST /api/simulations/{simulation_id}/replay`：从日志重建演示。

## 8. 输出需求

### 8.1 ActionPlan

`ActionPlan` 是 Agent 语义层输出，描述“应该发生什么”：

```json
{
  "simulation_id": "sim_20260707_001",
  "plan_id": "plan_001",
  "steps": [
    {
      "id": "step_001",
      "actor_id": "nurse_001",
      "type": "speak",
      "target_actor_id": "patient_001",
      "think": "病人主诉头痛，需要评估风险并建议检查。",
      "dialogue": "您好，请描述一下头痛的位置和持续时间。",
      "priority": 1
    }
  ]
}
```

### 8.2 DemoTimeline

`DemoTimeline` 是 Godot 执行层输出，描述“如何演示”：

```json
{
  "simulation_id": "sim_20260707_001",
  "timeline_id": "tl_001",
  "version": 1,
  "actions": [
    {
      "id": "act_001",
      "time": 0.0,
      "type": "move_to",
      "actor_id": "nurse_001",
      "location_id": "triage_desk",
      "duration": 2.0
    },
    {
      "id": "act_002",
      "time": 2.0,
      "type": "speak",
      "actor_id": "nurse_001",
      "target_actor_id": "patient_001",
      "think": "病人主诉头痛，需要评估风险并建议检查。",
      "dialogue": "您好，请描述一下头痛的位置和持续时间。",
      "duration": 4.0,
      "priority": 1
    }
  ]
}
```

### 8.3 P0 动作类型

- `spawn_actor`：生成或绑定场景角色。
- `move_to`：移动到地点或坐标。
- `face_actor`：朝向另一个角色。
- `speak`：展示思考和对话气泡。
- `wait`：等待指定时间。
- `use_device`：设备进入使用状态并显示结果。
- `set_state`：修改角色、病人、设备或场景状态。
- `end_simulation`：演示结束。

### 8.4 Godot 适配要求

- Godot 只消费 `DemoTimeline`，不直接理解医学实体推理。
- Godot 角色通过 `actor_id` 绑定到场景中的 NPC 节点。
- 若输入 actor 数量超过当前场景可用 sprite，P0 阶段允许复用同类 sprite。
- 若 `location_id` 不存在，后端必须在校验阶段报错或映射到默认位置。
- `speak` 动作应复用现有 `DialogueEntry` 字段：`speaker`、`think`、`dialogue`、`target`、`mood`。

## 9. 状态与日志

### 9.1 WorldState

后端必须维护结构化世界状态：

- 当前游戏时间
- 角色位置、状态、当前任务
- 病人病情、风险等级、检查结果
- 设备状态
- 已完成目标
- 对话记忆
- 事件日志

### 9.2 日志

每次演示必须至少记录：

- 输入 spec 快照
- Agent 输入与输出
- 生成的 ActionPlan
- 生成的 DemoTimeline
- Godot 回传事件
- 最终状态
- 错误与回退记录

## 10. 优先级

### P0：可用闭环

- 定义并校验 `SimulationSpec`。
- 支持医生、护士、病人、疾病、设备、地点、目标输入。
- 实现创建模拟、生成计划、获取时间线、Agent step、Godot 事件回传 API。
- 生成稳定的 `DemoTimeline`。
- Godot 能按时间线完成自动演示：移动、说话、等待、使用设备、结束。
- 支持至少 1 个完整案例：急诊头痛分诊 + CT 建议。
- 有错误提示和基础日志。

### P1：动态 Agent 与多案例

- 支持突发事件插入和中途重规划。
- 支持多个病人、多名医生/护士并发任务。
- 支持优先级打断，与现有 `ConversationManager` 规则一致。
- 支持检验结果、设备结果和医嘱状态变化。
- 支持演示总结、对话日志和可回放日志。
- 支持至少 3 个案例：分诊、创伤抢救、检验闭环。

### P2：教学与产品化

- 支持案例模板库。
- 支持教学评分、关键步骤检查和反馈。
- 支持可视化编辑输入 spec。
- 支持导出视频、报告或 Web 演示链接。
- 支持更复杂的地图、房间、设备和路径规划。

## 11. 验收方案

### 11.1 P0 功能验收

1. 使用一个 JSON 输入创建模拟，包含：
   - 1 名医生
   - 1 名护士
   - 1 名病人
   - 1 个疾病/病例
   - 1 台 CT 设备
   - 2 个地点
   - 1 个分诊目标
2. `POST /api/simulations` 返回 `simulation_id`，并输出无阻断错误。
3. `POST /api/simulations/{id}/plan` 返回至少 5 个语义步骤。
4. `GET /api/simulations/{id}/timeline` 返回至少包含：
   - 1 个 `move_to`
   - 2 个 `speak`
   - 1 个 `use_device`
   - 1 个 `end_simulation`
5. Godot 能完整播放时间线，角色移动、气泡文字、设备使用状态均可见。
6. 演示完成后，后端日志包含所有 action 的完成事件。

### 11.2 P0 数据验收

- 缺少必填字段时，API 返回明确的字段级错误。
- `actor_id`、`patient_id`、`device_id`、`location_id` 引用不存在时，API 返回明确错误。
- Agent 输出非法动作时，后端拒绝该动作并给出回退或错误记录。
- 同一输入在关闭随机性时能生成一致时间线。

### 11.3 P0 Godot 验收

- Godot 不需要改动输入 JSON 即可从 API 或本地时间线加载演示。
- 对话气泡能显示 `think` 与 `dialogue` 两阶段内容。
- 动作执行失败时，Godot 能回传错误事件。
- 演示结束时，Godot 能触发 `end_simulation` 完成事件。

### 11.4 P1 验收

- 可在演示中插入“病人生命体征恶化”事件，并触发重规划。
- 高优先级抢救对话能打断低优先级常规对话。
- 三个案例均可从输入 spec 自动生成并播放。
- 演示结束后可查看结构化总结，包括关键医学流程是否完成。

## 12. 风险与待确认问题

- 医学内容准确性：需要明确系统是教学演示还是临床建议，界面和 API 应标记为模拟用途。
- Agent 稳定性：LLM 输出需要 schema 校验和规则回退。
- Godot 与后端通信方式：P0 可先支持本地 JSON 文件或 HTTP 拉取，最终方式需要根据部署环境确认。
- 角色动态生成：现有场景是固定 NPC，P0 可先做节点绑定，P1 再做真正动态生成。
- 中文字体与编码：当前项目已有中文字体 fallback，但所有 JSON 和 API 必须统一 UTF-8。

## 13. 推荐里程碑

### M1：接口定稿

- 定稿 `SimulationSpec`、`ActionPlan`、`DemoTimeline` schema。
- 定稿 P0 API。
- 准备一个头痛分诊测试输入。

### M2：后端闭环

- 完成输入校验、session、Agent plan、timeline 生成、日志。
- 使用本地 mock Agent 通过验收。

### M3：Godot 播放器

- Godot 加载 `DemoTimeline`。
- 执行 P0 动作集合。
- 回传播放事件。

### M4：端到端演示

- 头痛分诊案例从输入到 Godot 自动播放。
- 输出完整日志和总结。
- 修复稳定性问题，形成 P0 可演示版本。
