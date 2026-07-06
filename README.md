# MedSquad — 急诊科多智能体模拟

Godot 4.7 医院主题 2D 俯视角游戏。模拟急诊科多个 NPC 的对话与协作。

---

## 启动

### 方式一：Godot 编辑器

从 [godotengine.org/download](https://godotengine.org/download/) 下载 **Godot 4.7** 标准版，打开 `project.godot`，按 F5 运行。

### 方式二：网页版 (WebAssembly)

**在线游玩：** [https://so-cean.github.io/MedSquad-/](https://so-cean.github.io/MedSquad-/)

**本地测试 Web 构建：**

```bash
# 1. 导出 Web 构建
.\bin\godot.exe --headless --export-release Web build/web/index.html

# 2. 启动 HTTP 服务器（Web 导出不能直接双击 index.html 打开，
#    因为浏览器安全策略禁止 file:// 加载 WebAssembly）
cd build\web
python -m http.server 8080

# 3. 浏览器访问 http://localhost:8080
```

> 本地双击 `build/web/index.html` 会报 `Failed to fetch` 错误，这是正常的浏览器 CORS 限制，必须通过 HTTP 服务器访问。

### CI/CD 自动部署

每次 push 到 `main`，GitHub Actions 自动：
1. 拉取 `barichello/godot-ci:4.7` Docker 镜像
2. 运行 Web 导出（单线程，兼容 GitHub Pages）
3. 部署到 `gh-pages` 分支
4. GitHub Pages 自动更新（首次需在仓库 Settings → Pages 中选择 `gh-pages` 分支）

---

## 交互流程

### NPC 对话气泡

每个 NPC 说话时头顶会显示一个气泡框，分两阶段：

```
Phase 1: 🤔 [蓝色文字] 思考内容 (逐字打字效果)
              ↓  思考完成，暂停 0.5s
Phase 2: 🗣 [深色文字] 实际对话内容 (淡入)
              ↓  停留 duration 秒后
             气泡自动淡化消失 (0.4s)
```

- 没有思考内容时，直接进入 Phase 2
- 气泡最大高度 180px，超过可滚动，自动滚到底部
- 气泡有上下浮动动画

### 对话优先级与打断

| 优先级 | 场景 | 角色 |
|---|---|---|
| 4 | 急诊抢救 | 急救护士 ↔ 手术医生 |
| 3 | 手术准备 | 手术医生 |
| 2 | 检验结果 | 检验科护士 |
| 1 | 常规分诊、查房 | 分诊护士、住院护士 |
| 0 | 患者回应 | 患者 |

**打断规则：**

```
NPC A ↔ NPC B 正在对话
    ↓
NPC C 想找 A
    ↓
A 检查优先级
 ├─ C > B → A 切换到 C (B 进入空闲)
 └─ C ≤ B → C 进入 A 的等待队列
              A 结束后 → 检查队列 → 最高优先级出队
```

- 两组不相干的对话可以同时进行（各自独立气泡）

### 时间系统

- 每 1 真实秒 = 1 游戏分钟
- 从 08:00（第1天）开始
- 对话记录带游戏内时间戳
- 未来 NPC 行为可依赖时间

---

## 对话流 (Mock 模式)

当前内置 7 个对话流，启动后随机循环播放：

| 流 | 参与者 | 场景 |
|---|---|---|
| `triage` | 分诊护士 ↔ 患者 | 头痛分诊 → CT检查 |
| `emergency` | 急救护士 ↔ 手术医生 | 车祸急救 → 手术准备 |
| `lab_result` | 检验科护士 ↔ 分诊护士 | 检验报告 → 开药 |
| `ward_round` | 住院护士 ↔ 患者 | 术后查房 |
| `medication` | 分诊护士 ↔ 患者 | 用药指导 |
| `surgery_prep` | 手术医生 ↔ 急救护士 | 术前准备 |
| `shift_change` | 急救护士 ↔ 分诊护士 | 夜班交班 |

流定义文件：`data/mock_flows.json`

---

## NPC 角色

| NPC | 职业 | 场景文件名 | 知识库文件 |
|---|---|---|---|
| 分诊护士 | 急诊分诊 | `nurse.gd` | `data/npcs/分诊护士.json` |
| 手术医生 | 外科手术 | `scrubs_green.gd` | `data/npcs/手术医生.json` |
| 急救护士 | 急诊抢救 | `nurse_blue.gd` | `data/npcs/急救护士.json` |
| 检验科护士 | 检验科 | `scrubs_blue.gd` | `data/npcs/检验科护士.json` |
| 住院护士 | 住院部 | `nurse_green.gd` | `data/npcs/住院护士.json` |
| 患者 | 就诊 | `patient_blue/green.gd` | `data/npcs/患者.json` |

---

## 项目结构

```
├── bin/godot.exe             捆绑的 Godot 4.7 编辑器
├── project.godot              项目配置 (含 autoload)
├── data/
│   ├── mock_flows.json        对话流定义 (JSON)
│   └── npcs/*.json            各 NPC 角色知识库
├── scripts/
│   ├── base_npc.gd            NPC 基类 (动画 + 移动 + 对话接口 + 记忆)
│   ├── nurse.gd / scrubs_*.gd / patient_*.gd  各 NPC 脚本
│   ├── player.gd / camera.gd  玩家与相机
│   └── dialogue/
│       ├── dialogue_entry.gd      对话数据接口
│       ├── dialogue_bubble.gd     气泡 UI (CanvasLayer)
│       ├── dialogue_manager.gd    全局管理者 (autoload)
│       ├── conversation_manager.gd 对话配对 + 优先级打断
│       ├── mock_dialogue_system.gd Mock 对话流引擎
│       ├── memory_store.gd         NPC 记忆存储 (JSON)
│       ├── npc_data_loader.gd      NPC 知识库加载
│       └── time_system.gd         游戏内时间 (autoload)
├── scens/                      场景文件
│   ├── room1.tscn              主场景
│   ├── player.tscn
│   └── *.tscn                  各 NPC 场景
├── assets/
│   ├── rooms/                  背景图
│   ├── doctor_frames/          玩家动画帧
│   └── *_[npc]_frames/         各 NPC 动画帧
├── character/                  原始精灵表
└── Tilesets/                   医院主题瓦片
```

---

## 架构说明

### 三层架构

```
自动加载层 (autoload)
  ├─ DialogueManager     气泡管理 + NPC注册
  ├─ TimeSystem          游戏内时间推进
  └─ ConversationManager  (DialogueManager 的子节点)
                             对话配对 + 打断逻辑

场景层
  └─ BaseNpc (class_name)
       ├─ 8方向行走动画
       ├─ 对话接口 (speak / stop_speaking)
       └─ 记忆存储 (MemoryStore)

数据层
  ├─ data/mock_flows.json    对话流
  ├─ data/npcs/*.json        NPC 知识库
  └─ user://npc_memories/*/  运行时记忆 (JSON)
```

### 记忆系统 (Stanford 风格)

每个 NPC 有独立记忆文件 (`user://npc_memories/{name}/nodes.json`)：
- `dialogue` 类型：谁对谁说了什么 + think 内容
- `thought` 类型：内部推理
- 带游戏内时间戳
- 供未来 LLM 检索作为 context

---

## 角色归属

- 护士和医生精灵图：Jephed (Game Between The Lines)
- 基于 Stanford Generative Agents 论文架构设计
