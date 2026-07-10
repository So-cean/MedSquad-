# ED-MAS Clean Runtime Report

## 1. Clean 版本定义

当前 clean 版本只保留一条默认运行链：

`project.godot` -> `scens/room1.tscn` -> `BaseNpc` -> `DialogueManager` -> `ConversationManager` -> `MockDialogueSystem` -> `DialogueBubble`

这条链负责：

- 人物显示
- NPC 自主走动
- 中文对白气泡
- 本地 mock 对话流

`backend` 保留为独立 Python 编排能力，`gh-pages` 保留为 Web 发布产物。  
`map` 分支内容不进入默认启动链，仅作为归档参考。

---

## 2. 三个分支的本质功能

### `main`

本质上是 Godot 本地前端基线。

它负责：

- `room1.tscn`
- `player / nurse / patient / scrubs` 场景
- `BaseNpc` 的移动与对话接口
- `DialogueManager` 的气泡显示
- `MockDialogueSystem` 的本地对白流
- Web 导出入口

### `backend`

本质上是 Python 侧编排层。

它负责：

- 场景解析
- step / timeline 生成
- CLI 演示
- HTTP simulator / 服务能力

它输出的是结构化数据与动作序列，供前端消费。

### `gh-pages`

本质上是发布产物。

它负责：

- 浏览器可打开的 Web build
- `index.html`、`index.js`、`index.wasm`、`index.pck`

它不承担源码开发逻辑。

---

## 3. 保留 / 参考 / 隔离

### 保留

- `scens/room1.tscn`
- `scripts/base_npc.gd`
- `scripts/nurse.gd`
- `scripts/nurse_blue.gd`
- `scripts/nurse_green.gd`
- `scripts/patient_blue.gd`
- `scripts/patient_green.gd`
- `scripts/scrubs_blue.gd`
- `scripts/scrubs_green.gd`
- `scripts/dialogue/*`
- `data/mock_flows.json`
- `data/npcs/*`
- `assets/rooms/*`
- `assets/doctor_frames/*`
- `assets/nurse*_frames/*`
- `assets/patient*_frames/*`
- `assets/scrubs*_frames/*`

### 只作参考

- `backend/app/*`
- `backend/app/cli/*`
- `backend/app/services/backend_server.py`
- `backend/README.md`
- `backend.md`

### 隔离出默认 runtime

- `scens/edmas/*`
- `scripts/edmas/*`
- `assets/maps/*`
- `docs/*g3*` 中的 ED-MAS map 相关说明
- 旧 ABC / mock demo 里的 map 回放路径

这些内容可以作为备份、试验或后续迁移材料，但不进入默认启动入口。

---

## 4. 统一 runtime 的链路

### 默认链路

1. 打开 `project.godot`
2. 默认进入 `scens/room1.tscn`
3. `BaseNpc` 负责人物生成、移动、对话接口
4. `DialogueManager` 负责气泡显示
5. `MockDialogueSystem` 读取 `data/mock_flows.json`
6. `ConversationManager` 负责对话配对与打断

### 后端链路

1. 运行 `backend`
2. CLI / HTTP simulator 生成结构化场景数据
3. 输出 timeline / action plan / session 数据
4. 前端若需要接入，只接消费层，不改变默认 room1 baseline

---

## 5. 现在可直接用的启动命令

### 前端基线

```powershell
cd D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-
.\bin\godot.exe
```

在 Godot 中：

- 默认应进入 `scens/room1.tscn`
- 如果想手动看视频基线，可按 `F6` 运行当前场景

### 后端参考

```powershell
cd D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-\backend
python -m app.services.backend_server
```

### Web 版本

```powershell
cd D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-
.\bin\godot.exe --headless --export-release Web build\web\index.html
cd build\web
python -m http.server 8080
```

浏览器访问：

```text
http://localhost:8080
```

---

## 6. 视频效果来自哪里

视频里那种“人物出现 + 中文气泡 + 局部对话”的效果，来源于：

- Godot 前端
- `room1.tscn`
- `BaseNpc`
- `DialogueManager`
- `MockDialogueSystem`

如果看到的是网页形式，那也是同一套 Godot 前端导出的 Web 版本；  
它的本质仍然是前端 scene 在浏览器里运行。

---

## 7. 当前 clean 版本的目标

- 默认只保留一条可理解的前端运行线
- NPC 能移动
- NPC 能会话
- 前端能作为独立界面启动
- 后端作为独立服务提供结构化数据
- `gh-pages` 只负责发布

---

## 8. 备份说明

`map` 分支相关内容建议作为独立备份保留，后续如果要做实验性地图/患者/新 UI，再单独启用，不进入默认运行入口。

