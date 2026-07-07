# MedSquad — 急诊科多智能体模拟

Godot 4.7 2D 俯视角医院模拟。NPC 由 LLM (DeepSeek-V4-Flash) 实时驱动对话与决策。

**核心架构：Godot → Gitee AI (HTTP)。无 Python 后端，无进程管理。**

---

## 启动

```bash
# 直接打开 project.godot，按 F5 运行
godot project.godot
```

Godot 内建的 `NPC_FSM` 通过 `HTTPRequest` 直连 Gitee AI，不需要额外启动任何服务。

### 网页版

```bash
godot --headless --audio-driver Dummy --export-release Web build/web/index.html
cd build\web && python -m http.server 8080
# → http://localhost:8080
```

在线版：https://so-cean.github.io/MedSquad-/

---

## 架构

```
Godot F5
  └─ NPC_FSM (scripts/edmas/npc_fsm.gd)
       ├─ register_npc() → 注册 NPC
       ├─ tick_all() → 并发 HTTPRequest × N
       │    └─ 每个直连 Gitee AI (DeepSeek-V4-Flash)
       │         └─ 返回 utterances[]
       ├─ action_ready 信号 → 接收 NPC 决策
       │    └─ npc.speak(entry) → DialogueBubble 显示
       └─ report_complete() → NPC 回到 IDLE
```

| 组件 | 位置 | 职责 |
|---|---|---|
| `npc_fsm.gd` | `scripts/edmas/` | NPC 状态机，并发调 LLM |
| `DialogueManager` | `scripts/dialogue/` (autoload) | 气泡池管理、NPC 注册 |
| `DialogueBubble` | `scripts/dialogue/` | 气泡 UI (THINK→UTTERANCE 状态机) |
| `DialogueEntry` | `scripts/dialogue/` | 数据格式 (think + utterances[]) |

### LLM 模型

| 场景 | 模型 | 速度 |
|---|---|---|
| NPC 决策 + 对话 | DeepSeek-V4-Flash | ~2.7s |
| 医学分诊 | HealthGPT-L14 | ~2.3s |

所有请求**并发**，3 个 NPC 同时决策 ≈ 2.7s。

### API Key 轮询

两个 Gitee AI key 自动轮询，一个失败自动切另一个。

---

## 对话系统

```
show_entry(entry)
  ├─ THINK: 🤔 蓝色文字 typewriter (如有 think 内容)
  │          → 完成后暂停 0.5s → 淡出
  └─ UTTERANCE: 🗣 utterances[] 逐条播放 (每条 2.5s)
                 → 全部播完 → DONE
```

API 超时或失败时自动显示 "嗯，我在思考…" 后备内容。

详见 `scripts/dialogue/README.md`。

---

## 测试场景

`scens/edmas/DialogueTest.tscn` — 1 护士 + 2 患者，10 轮 LLM 对话测试。

打开 `project.godot` 按 F5 运行。

---

## 楼层场景

| 楼层 | 场景 | NPC |
|---|---|---|
| 1F 急诊 | `Floor_ED_Core.tscn` | 分诊护士、急救护士、患者×2 |
| 2F 检查 | `Floor_Diagnostics.tscn` | 手术医生、检验科护士 |
| 3F 转归 | `Floor_Downstream.tscn` | 住院护士 |

按 **E** 上楼、**Q** 下楼。

---

## 项目结构

```
scripts/
├── edmas/
│   ├── npc_fsm.gd              NPC 状态机 + LLM 调用
│   ├── main_edmas.gd            主场景
│   ├── map_npc.gd               楼层 NPC
│   └── managers/
├── dialogue/                    对话系统 (详见 README)
└── ui/virtual_joystick.gd       触控摇杆
scens/edmas/
├── Main_EDMAS.tscn              主场景
├── Floor_*.tscn                 楼层场景
└── DialogueTest.tscn            测试场景
assets/maps/
├── normalized/                  地图图
└── collision/                   墙体碰撞
backend/                         (备用 Python 后端)
data/                            NPC 知识库
```
