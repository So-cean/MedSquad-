# EDMAS Backend — 架构、工作流与使用指南

> **最后更新：** 2026-07-07  
> **语言：** 中文  
> **目标读者：** 项目合作者、后端开发者、Godot 前端开发者

---

## 目录

1. [项目概览](#1-项目概览)
2. [核心工作流](#2-核心工作流)
3. [代码结构](#3-代码结构)
4. [环境配置](#4-环境配置)
5. [运行方式](#5-运行方式)
6. [数据流详解](#6-数据流详解)
7. [核心组件说明](#7-核心组件说明)
8. [Schema 契约](#8-schema-契约)
9. [Provider 模式](#9-provider-模式)
10. [地图与角色系统](#10-地图与角色系统)
11. [测试](#11-测试)
12. [常见问题排查](#12-常见问题排查)
13. [扩展指南](#13-扩展指南)

---

## 1. 项目概览

EDMAS（Emergency Department Multi-Agent Simulation）是一个医院急诊流程多智能体仿真系统。**Backend** 负责：

- 将用户的自然语言场景描述转换成结构化的 `SimulationSpec` JSON
- 根据场景为医生、护士、患者、设备生成可播放的对话与行动流程（`ActionPlan`）
- 将行动计划转换为 Godot 引擎可直接加载的 `DemoTimeline` JSON
- 支持本地离线模式（不依赖 API）和远程 API 模式（OpenAI 兼容接口）

**Backend 是纯终端 CLI 工具，没有 Web 服务器。** 它通过命令行交互，输出 JSON 文件供 Godot 前端读取。

---

## 2. 核心工作流

```
用户输入自然语言场景
        │
        ▼
┌─────────────────────────────────┐
│  阶段 1: 意图解析               │
│  ScenarioIntentAgent            │
│  "车祸急诊，需要设备和医生调度"    │
│         ↓                       │
│  SimulationSpec JSON            │
│  (角色、患者、疾病、设备、地点、目标) │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  阶段 2: 校验与会话创建          │
│  ValidationService              │
│  SimulationService.create()     │
│         ↓                       │
│  WorldState (初始世界状态)        │
│  写入: runtime/simulations/{id}/ │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  阶段 3: 行动计划生成            │
│  AgentService.generate_plan()   │
│  → MockAgent 或 OpenAIAgent     │
│         ↓                       │
│  ActionPlan (步骤列表)           │
│  speak, move_to, use_device, ... │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  阶段 4: Timeline 生成           │
│  TimelineService.build_timeline()│
│         ↓                       │
│  DemoTimeline (带时间戳的动作序列) │
│  写入: runtime/.../timeline.json │
│  可选: 复制到 Godot data/ 目录    │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  阶段 5: Godot 播放              │
│  timeline_loader.gd 读取 JSON   │
│  timeline_player.gd 逐条执行     │
│  NPC 移动、对话气泡、设备动画     │
└─────────────────────────────────┘
```

### 工作流简述

| 阶段 | 输入 | 输出 | 核心组件 |
|------|------|------|----------|
| 意图解析 | 自然语言文本 | `SimulationSpec` JSON | `ScenarioIntentAgent` + `OpenAIScenarioIntentAgent`（或 `TemplateScenarioIntentAgent`） |
| 校验 & 会话 | `SimulationSpec` | `WorldState` + 会话文件 | `ValidationService` + `SimulationService` + `FileStore` |
| 计划生成 | `SimulationSpec` + `WorldState` | `ActionPlan` | `MockAgent`（确定性）或 `OpenAIAgent`（API 驱动） |
| Timeline | `ActionPlan` + `SimulationSpec` | `DemoTimeline` | `TimelineService` |
| 播放 | `DemoTimeline` JSON | Godot 动画/对话 | Godot 端 `timeline_player.gd` |

---

## 3. 代码结构

```
backend/
├── .env.example              # 环境变量模板（可提交）
├── .env                      # 本地环境变量（已 gitignore，不提交）
├── pyproject.toml            # Python 项目配置
├── README.md                 # 简要 README
│
├── app/
│   ├── config.py             # 配置加载（从 .env 读取）
│   │
│   ├── agents/               # 智能体层
│   │   ├── base.py           # BaseAgent 抽象接口
│   │   ├── mock_agent.py     # 确定性 Mock 智能体（不依赖 API）
│   │   ├── openai_agent.py   # OpenAI API 智能体（对话/计划生成）
│   │   └── scenario_intent_agent.py  # 场景意图解析智能体
│   │       ├── ScenarioIntentAgent   # 入口：选择 provider
│   │       ├── OpenAIScenarioIntentAgent  # API 驱动
│   │       └── TemplateScenarioIntentAgent  # 模板驱动（离线）
│   │
│   ├── schemas/              # Pydantic 数据模型（输入输出契约）
│   │   ├── common.py         # Position, ApiError, ValidationWarning
│   │   ├── simulation.py     # SimulationSpec, ActorSpec, PatientSpec, ...
│   │   ├── intent.py         # ScenarioIntentRequest/Response
│   │   ├── plan.py           # ActionPlan, PlanStep, AgentStepRequest/Result
│   │   ├── timeline.py       # DemoTimeline, TimelineAction
│   │   └── compat.py         # Pydantic v1/v2 兼容层
│   │
│   ├── services/             # 业务逻辑层
│   │   ├── openai_client.py  # 共享 OpenAI SDK 客户端工厂
│   │   ├── simulation_service.py  # 模拟生命周期管理
│   │   ├── validation_service.py  # SimulationSpec 校验
│   │   ├── world_state_service.py # WorldState 初始化
│   │   ├── agent_service.py  # 智能体选择与调度
│   │   ├── agent_context_service.py  # 为每个角色构建 system prompt
│   │   ├── timeline_service.py  # ActionPlan → DemoTimeline
│   │   └── map_context_service.py  # 地图、房间、角色职责定义
│   │
│   ├── storage/
│   │   └── file_store.py     # JSON 文件读写（模拟会话持久化）
│   │
│   ├── cli/
│   │   └── terminal_demo.py  # 终端入口（唯一 CLI 入口）
│   │
│   └── data/examples/        # 预置案例
│       ├── headache_triage.simulation.json
│       ├── headache_triage.timeline.json
│       └── stomach_pain.simulation.json
│
├── tests/                    # 单元测试
│   ├── test_validation.py
│   ├── test_plan_generation.py
│   ├── test_timeline_generation.py
│   ├── test_simulation_pipeline.py
│   ├── test_scenario_intent_agent.py
│   ├── test_openai_agent.py
│   ├── test_agent_context.py
│   └── test_terminal_demo_cli.py
│
└── runtime/                  # 运行时输出（已 gitignore）
    └── simulations/
        └── {simulation_id}/
            ├── input.json        # 原始 SimulationSpec
            ├── world_state.json  # 初始 WorldState
            ├── plan.json         # ActionPlan
            ├── timeline.json     # DemoTimeline
            └── warnings.json     # 校验警告
```

---

## 4. 环境配置

### 4.1 初次设置

```bash
cd backend
cp .env.example .env
# 编辑 .env，填入你的 API 配置
```

### 4.2 配置项详解

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `EDMAS_APP_NAME` | `EDMAS Backend` | 应用名称 |
| `EDMAS_AGENT_PROVIDER` | `mock` | 计划生成智能体：`mock`（确定性本地）或 `openai`（API 驱动） |
| `EDMAS_DETERMINISTIC` | `true` | 是否确定性模式 |
| `EDMAS_INTENT_PROVIDER` | `openai` | 意图解析：`openai`（API）、`api`（同 openai）、`template`（本地模板） |
| `EDMAS_INTENT_FALLBACK_PROVIDER` | `template` | 意图解析失败时的回退方案：`template` 或 `none` |
| `OPENAI_API_KEY` | — | API 密钥（也支持 `api_key` 别名） |
| `OPENAI_BASE_URL` | `https://api.openai.com/v1` | API 端点（也支持 `base_url` 别名） |
| `OPENAI_MODEL` | `gpt-4.1-mini` | 模型名称（也支持 `model_name` 别名） |
| `OPENAI_TIMEOUT_SECONDS` | `120` | API 超时秒数 |
| `EDMAS_RUNTIME_DIR` | `backend/runtime` | 运行时输出目录 |
| `EDMAS_GODOT_TIMELINE_OUTPUT` | `data/timelines/headache_triage.timeline.json` | Godot 端 timeline 输出路径 |

### 4.3 推荐配置

**纯离线开发（不需要 API）：**
```env
EDMAS_AGENT_PROVIDER=mock
EDMAS_INTENT_PROVIDER=template
EDMAS_INTENT_FALLBACK_PROVIDER=template
```

**使用 Gitee AI 等兼容 API（推荐）：**
```env
EDMAS_AGENT_PROVIDER=mock          # 计划生成用 mock，更快更稳定
EDMAS_INTENT_PROVIDER=openai       # 意图解析用 API
EDMAS_INTENT_FALLBACK_PROVIDER=template
OPENAI_API_KEY=你的密钥
OPENAI_BASE_URL=https://ai.gitee.com/v1
OPENAI_MODEL=DeepSeek-V4-Flash
OPENAI_TIMEOUT_SECONDS=120
```

**完全 API 驱动（实验性）：**
```env
EDMAS_AGENT_PROVIDER=openai
EDMAS_INTENT_PROVIDER=openai
EDMAS_INTENT_FALLBACK_PROVIDER=template
OPENAI_API_KEY=你的密钥
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-4.1-mini
```

> ⚠️ **安全提醒：** `.env` 文件已在 `.gitignore` 中排除，**不要**将 API 密钥提交到仓库。`.env.example` 中的密钥值为占位符，可以安全提交。

---

## 5. 运行方式

### 5.1 交互式运行

```bash
cd backend
python -m app.cli.terminal_demo
```

程序会提示：
```
请输入场景：
```

输入自然语言描述，例如：
```
车祸急诊流程，需要设备和医生资源调度
```

### 5.2 命令行参数

```bash
# 直接传入场景
python -m app.cli.terminal_demo --intent "车祸急诊流程，需要设备和医生资源调度"

# 使用预置案例
python -m app.cli.terminal_demo --case stomach
python -m app.cli.terminal_demo --case headache

# 加载自定义 JSON
python -m app.cli.terminal_demo --spec app/data/examples/stomach_pain.simulation.json

# 保存生成的 SimulationSpec JSON
python -m app.cli.terminal_demo --intent "模拟一个胃痛病人看病" --save-generated-spec runtime/my_case.json

# 显示完整的 Agent system prompt（调试用）
python -m app.cli.terminal_demo --intent "车祸急诊" --show-prompts
```

### 5.3 可用参数

| 参数 | 说明 |
|------|------|
| `--case {stomach,headache}` | 使用预置案例 |
| `--spec PATH` | 加载自定义 SimulationSpec JSON |
| `--intent [TEXT]` | 自然语言场景（不传则交互式输入） |
| `--save-generated-spec PATH` | 保存 API 生成的 JSON 到指定路径 |
| `--show-prompts` | 打印每个角色的完整 system prompt |

---

## 6. 数据流详解

### 6.1 从自然语言到 SimulationSpec

```
用户输入: "车祸急诊流程，需要设备和医生资源调度"
        │
        ▼
ScenarioIntentAgent.build_spec(text)
        │
        ├── provider="openai" 或 "api"
        │   └── OpenAIScenarioIntentAgent
        │       ├── 构建 system prompt（含地图上下文 + JSON Schema）
        │       ├── 调用 OpenAI SDK 的 chat.completions.create
        │       ├── 解析返回的 JSON → ScenarioIntentResponse
        │       └── ValidationService.validate(simulation_spec)
        │           ├── 检查 ID 唯一性
        │           ├── 检查引用完整性（actor.location_id, patient.actor_id, ...）
        │           └── 生成 warnings
        │
        ├── provider="template"
        │   └── TemplateScenarioIntentAgent
        │       ├── 关键词匹配："车祸/创伤/急救" → 创伤模板
        │       ├── 关键词匹配："胃/腹痛" → 胃痛模板
        │       └── 默认 → 头痛分诊模板
        │
        └── fallback="template"（API 失败时）
            └── 回退到模板，并在 assumptions 中记录失败原因
```

### 6.2 从 SimulationSpec 到 DemoTimeline

```
SimulationSpec
        │
        ▼
SimulationService.create(spec)
        ├── ValidationService.validate(spec)  → warnings
        ├── WorldStateService.create_initial_state(id, spec)  → WorldState
        └── FileStore 写入 runtime/simulations/{id}/
                ├── input.json
                ├── world_state.json
                └── warnings.json
        │
        ▼
SimulationService.generate_plan(simulation_id)
        ├── 读取 input.json + world_state.json
        └── AgentService.generate_plan(spec, world_state)
                ├── MockAgent（默认）
                │   ├── 检测是否为创伤案例 → 生成创伤抢救流程
                │   └── 否则 → 通用分诊流程
                └── OpenAIAgent
                    ├── 构建 plan system prompt（含地图 + 角色职责 + ActionPlan schema）
                    └── 调用 API 生成 PlanStep 列表
        │
        ▼
SimulationService.get_or_create_timeline(simulation_id)
        └── TimelineService.build_timeline(plan, spec, world_state)
                ├── 遍历 PlanStep
                ├── 为每个步骤分配时间戳（累积 duration）
                ├── 解析 location_id → Position 坐标
                ├── use_device 步骤使用设备的 operation_duration
                └── 末尾追加 end_simulation
```

### 6.3 输出文件

每次运行在 `runtime/simulations/{simulation_id}/` 下生成：

| 文件 | 内容 | 格式 |
|------|------|------|
| `input.json` | 原始 SimulationSpec | Pydantic model → JSON |
| `world_state.json` | 初始世界状态 | WorldState |
| `warnings.json` | 校验警告列表 | ValidationWarning[] |
| `plan.json` | 行动计划 | ActionPlan |
| `timeline.json` | 可播放时间线 | DemoTimeline |

---

## 7. 核心组件说明

### 7.1 OpenAI 客户端（`app/services/openai_client.py`）

所有 API 调用统一通过此模块，使用 `openai` SDK：

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://ai.gitee.com/v1",
    api_key=settings.openai_api_key,
    default_headers={"X-Failover-Enabled": "true"},
    timeout=settings.openai_timeout_seconds,
)

# 非流式调用
client.chat.completions.create(
    model="DeepSeek-V4-Flash",
    messages=[...],
    temperature=0.2,
    top_p=0.7,
    max_tokens=4096,
    frequency_penalty=1.0,
    response_format={"type": "json_object"},
    extra_body={"top_k": 50},
)
```

模块提供 `chat_completion()` 函数，封装了上述调用逻辑。如需修改 API 参数（如增加 `stream`、调整 `top_k`），只需修改此文件。

### 7.2 意图解析智能体（`app/agents/scenario_intent_agent.py`）

- **`ScenarioIntentAgent`**：入口类，根据 `provider` 选择解析方式。
- **`OpenAIScenarioIntentAgent`**：调用 API，将自然语言转成 `ScenarioIntentResponse`。API 的 system prompt 包含完整的地图上下文和 JSON Schema，确保 LLM 输出合法。
- **`TemplateScenarioIntentAgent`**：关键词匹配的本地模板，支持创伤、胃痛、头痛三种场景。

### 7.3 计划生成智能体（`app/agents/openai_agent.py` 和 `mock_agent.py`）

- **`MockAgent`**：确定性本地实现。检测是否为创伤案例，生成对应的多角色对话和设备使用流程。适合开发调试和离线演示。
- **`OpenAIAgent`**：API 驱动。将 `SimulationSpec` + `WorldState` + 每个角色的 system prompt 发给 LLM，生成 `ActionPlan`。

### 7.4 校验服务（`app/services/validation_service.py`）

校验 `SimulationSpec` 的完整性：
- 所有 ID 唯一（actors, patients, diseases, devices, locations, objectives）
- 引用完整性（actor.location_id 存在, patient.actor_id 存在, patient.disease_ids 存在, device.location_id 存在）
- 生成 warnings（actor 数量 > 8, 缺少 doctor 角色）

### 7.5 地图上下文服务（`app/services/map_context_service.py`）

定义了三张地图和所有房间：
- **MAP_ED_CORE**（急诊核心区）：ED_ENTRANCE, TRIAGE, WAITING_AREA, DOCTOR, ED_RESUS
- **MAP_DIAGNOSTICS**（检查检验区）：LAB, IMAGING, DIAGNOSTIC_WAITING, RESULT_REVIEW
- **MAP_DOWNSTREAM**（去向与处置区）：DISPOSITION, ICU, WARD, ED_BOARDING, DISCHARGE

同时定义了每种角色的职责边界（`ROLE_RESPONSIBILITIES`），用于构建 Agent 的 system prompt。

---

## 8. Schema 契约

### 8.1 核心数据模型

```
SimulationSpec
├── title: str                    # 场景标题
├── locale: str = "zh-CN"         # 语言
├── scene: SceneSpec
│   ├── map_id: str               # 地图 ID
│   ├── start_time: str           # 开始时间
│   └── locations: LocationSpec[] # 地点列表
│       ├── id: str               # 如 "ED_ENTRANCE"
│       ├── name: str             # 如 "急诊入口"
│       └── position: Position    # {x, y}
├── actors: ActorSpec[]           # 角色（医生、护士、患者、技师）
│   ├── id, display_name, type, profession
│   ├── sprite: 白名单（doctor_white, nurse_white, nurse_blue, ...）
│   ├── location_id: str          # 初始位置
│   ├── knowledge: [{condition, action, dept}]
│   └── tools: [str]
├── patients: PatientSpec[]       # 患者信息
│   ├── id, actor_id, name, age, sex
│   ├── chief_complaint, symptoms, vitals
│   └── disease_ids: [str]        # 关联疾病
├── diseases: DiseaseSpec[]       # 疾病定义
│   ├── id, name, severity
│   ├── possible_diagnoses, recommended_checks
│   └── expected_findings, care_pathway
├── devices: DeviceSpec[]         # 设备
│   ├── id, name, type: 白名单（ct_scanner, lab_analyzer, ...）
│   ├── location_id, capabilities
│   └── operation_duration: float
├── objectives: ObjectiveSpec[]   # 目标
│   ├── id, type, description
│   └── success_conditions: [str]
└── constraints: dict             # 约束条件
```

### 8.2 ActionPlan

```
ActionPlan
├── simulation_id: str
├── plan_id: str
└── steps: PlanStep[]
    ├── id: str
    ├── type: "spawn_actor" | "move_to" | "face_actor" | "speak" |
    │         "wait" | "use_device" | "set_state" | "end_simulation"
    ├── actor_id, target_actor_id, location_id, device_id
    ├── think: str          # 角色内心独白
    ├── dialogue: str       # 对话内容
    ├── duration: float     # 持续时间（秒）
    └── payload: dict       # 额外数据
```

### 8.3 DemoTimeline

```
DemoTimeline
├── simulation_id: str
├── timeline_id: str
├── version: int = 1
└── actions: TimelineAction[]
    ├── id, time, type, duration
    ├── actor_id, target_actor_id, location_id, device_id
    ├── position: Position | null   # 移动目标坐标
    ├── think, dialogue, priority
    └── payload: dict
```

### 8.4 白名单约束

**Actor.type:** `doctor`, `nurse`, `patient`, `technician`

**Sprite:** `doctor_white`, `nurse_white`, `nurse_blue`, `nurse_green`, `scrubs_green`, `scrubs_blue`, `patient_blue`, `patient_green`

**Device.type:** `ct_scanner`, `lab_analyzer`, `ecg_monitor`, `operation_table`, `medicine_cart`

---

## 9. Provider 模式

系统通过 Provider 模式支持灵活切换实现：

### 9.1 Intent Provider（意图解析）

| Provider | 说明 | 适用场景 |
|----------|------|----------|
| `openai` / `api` | 调用 OpenAI 兼容 API | 生产环境，需要灵活的场景解析 |
| `template` | 本地关键词匹配模板 | 离线开发，固定场景测试 |

### 9.2 Agent Provider（计划生成）

| Provider | 说明 | 适用场景 |
|----------|------|----------|
| `mock` | 确定性 MockAgent | 开发调试，离线演示，快速迭代 |
| `openai` | 调用 OpenAI 兼容 API | 需要 LLM 生成多样化对话 |

### 9.3 Fallback 机制

当 `intent_provider=openai` 但 API 调用失败时：
- 如果 `fallback_provider=template`：自动回退到模板，在 `assumptions` 中记录错误
- 如果 `fallback_provider=none`：直接抛出异常

---

## 10. 地图与角色系统

### 10.1 地图房间

| 地图 | 房间 ID | 房间名称 | 坐标范围 |
|------|---------|----------|----------|
| MAP_ED_CORE | ED_ENTRANCE | 急诊入口 | (140,170)-(230,250) |
| MAP_ED_CORE | TRIAGE | 分诊台 | (270,170)-(350,250) |
| MAP_ED_CORE | WAITING_AREA | 候诊区 | (390,170)-(480,250) |
| MAP_ED_CORE | DOCTOR | 医生诊室 | (520,170)-(610,250) |
| MAP_ED_CORE | ED_RESUS | 抢救区 | (650,170)-(740,250) |
| MAP_DIAGNOSTICS | LAB | 检验科 | (180,200)-(270,280) |
| MAP_DIAGNOSTICS | IMAGING | 影像检查室 | (340,200)-(430,280) |
| MAP_DIAGNOSTICS | DIAGNOSTIC_WAITING | 检查等待区 | (500,200)-(600,280) |
| MAP_DIAGNOSTICS | RESULT_REVIEW | 结果复核区 | (660,200)-(760,280) |
| MAP_DOWNSTREAM | DISPOSITION | 处置/去向讨论区 | (180,220)-(270,300) |
| MAP_DOWNSTREAM | ICU | ICU | (340,220)-(430,300) |
| MAP_DOWNSTREAM | WARD | 病房 | (500,220)-(600,300) |
| MAP_DOWNSTREAM | ED_BOARDING | 急诊留观 | (660,220)-(760,300) |
| MAP_DOWNSTREAM | DISCHARGE | 离院/出院 | (820,220)-(920,300) |

### 10.2 角色职责

| 角色 profession | 职责 |
|-----------------|------|
| triage_nurse | 接收患者主诉，判断紧急程度，决定路径 |
| gastroenterologist | 胃病相关病史采集、鉴别诊断、检查建议 |
| emergency_doctor | 急诊整体评估和风险升级，复核检查结果 |
| emergency_nurse | 抢救区接诊、生命体征监测、协调转运 |
| surgeon | 创伤外科会诊、手术适应证判断 |
| anesthesiologist | 气道、麻醉风险评估 |
| lab_nurse | 检验采样、设备使用、报告回传 |
| imaging_nurse | 影像检查引导、状态回传 |
| patient | 表达症状、病史、担忧，反馈自身感受 |

这些职责在 `map_context_service.py` 的 `ROLE_RESPONSIBILITIES` 中定义，通过 `AgentContextService` 注入到每个角色的 system prompt 中。

---

## 11. 测试

```bash
cd backend
python -m pytest -v
```

### 测试覆盖

| 测试文件 | 覆盖内容 |
|----------|----------|
| `test_validation.py` | Schema 校验（合法/非法输入、引用完整性） |
| `test_plan_generation.py` | MockAgent 计划生成 |
| `test_timeline_generation.py` | Timeline 转换 |
| `test_simulation_pipeline.py` | 端到端管道 |
| `test_scenario_intent_agent.py` | 意图解析（模板 + API mock） |
| `test_openai_agent.py` | OpenAI agent（mock API 响应） |
| `test_agent_context.py` | 地图上下文和 Agent prompt 构建 |
| `test_terminal_demo_cli.py` | CLI 参数解析 |

所有测试均使用 mock/fake，不依赖真实 API。

---

## 12. 常见问题排查

### 12.1 "ValidationException: simulation validation failed"

**原因：** API 返回的 JSON 中引用关系不正确（如 actor 的 location_id 不存在于 scene.locations）。

**解决：**
1. 确保 `.env` 中 `EDMAS_INTENT_FALLBACK_PROVIDER=template`
2. 使用 `--save-generated-spec` 保存原始 JSON 检查
3. 或改用 `EDMAS_INTENT_PROVIDER=template` 跳过 API

### 12.2 API 超时

**原因：** `OPENAI_TIMEOUT_SECONDS` 太小或 API 服务响应慢。

**解决：**
1. 增大 `OPENAI_TIMEOUT_SECONDS` 到 120 或更大
2. 将 `EDMAS_AGENT_PROVIDER` 设为 `mock`（计划生成不需要 API）

### 12.3 "ModuleNotFoundError: No module named 'openai'"

```bash
pip install openai
```

### 12.4 终端中文乱码

- Windows CMD: 运行前执行 `chcp 65001`
- PowerShell: 使用 `$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding`
- 推荐使用 Windows Terminal

### 12.5 runtime 目录权限问题

确保 `backend/runtime/` 目录可写。如果不存在，程序会自动创建。

---

## 13. 扩展指南

### 13.1 添加新场景模板

在 `app/agents/scenario_intent_agent.py` 的 `TemplateScenarioIntentAgent` 中：

1. 添加关键词检测方法（如 `_is_cardiac()`）
2. 添加场景构建方法（如 `_cardiac_spec()`）
3. 在 `build_spec()` 中添加分支

### 13.2 添加新角色类型

1. 在 `app/schemas/simulation.py` 的 `ActorType` 中添加新类型
2. 在 `app/services/map_context_service.py` 的 `ROLE_RESPONSIBILITIES` 中添加职责
3. 在 `app/agents/scenario_intent_agent.py` 的 system prompt 中更新白名单

### 13.3 添加新地图

1. 在 `app/services/map_context_service.py` 的 `MAPS` 中添加新地图定义
2. 在 `TemplateScenarioIntentAgent._base_locations()` 中添加新房间
3. 更新 system prompt 中的地图描述

### 13.4 添加新设备类型

1. 在 `app/schemas/simulation.py` 的 `DeviceType` 中添加新类型
2. 在 system prompt 中更新设备白名单

### 13.5 接入新 API 提供商

1. 修改 `.env` 中的 `OPENAI_BASE_URL` 和 `OPENAI_MODEL`
2. 如果 API 需要额外的 header 或参数，在 `app/services/openai_client.py` 的 `create_client()` 和 `chat_completion()` 中修改

### 13.6 添加 Web API（FastAPI）

当前 backend 是纯 CLI。如需 Web API，参考 `plan.md` 中的阶段 2 设计：
- 添加 `app/api/` 包
- 实现 `POST /api/simulations`、`POST /api/simulations/{id}/plan` 等路由
- 复用现有 `SimulationService`、`AgentService`、`TimelineService`

---

## 附录：快速开始清单

```bash
# 1. 安装依赖
cd backend
pip install openai pydantic

# 2. 配置环境
cp .env.example .env
# 编辑 .env，至少设置：
#   EDMAS_INTENT_PROVIDER=template    （离线模式）
#   或配置 OPENAI_API_KEY + OPENAI_BASE_URL  （API 模式）

# 3. 运行
python -m app.cli.terminal_demo --intent "车祸急诊流程，需要设备和医生资源调度"

# 4. 测试
python -m pytest -v

# 5. 查看输出
ls runtime/simulations/$(ls -t runtime/simulations/ | head -1)/
# 包含: input.json, world_state.json, plan.json, timeline.json, warnings.json
```