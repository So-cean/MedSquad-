# Godot Repo Inspection

## 1. ED-MAS 后端状态

- 后端项目路径：`D:\projects\BME1325Spring2026\ED-MAS`
- 存在的关键文件：
  - `app_core\app\godot_api.py`
  - `edmas_v1\godot_api_contract.py`
  - `edmas_v1\demo_playback.py`
  - `tests\edmas_v1\`
- 后端已提供 Godot 相关 HTTP 路由，并且是当前 snapshot 的来源之一。
- 后端没有在本目录中看到 `manage.py`。

## 2. ED-MAS 可用 API 列表

来自 `D:\projects\BME1325Spring2026\ED-MAS\app_core\app\godot_api.py` 的路由：

- `GET /api/godot/snapshot`
- `GET /api/godot/events/recent`
- `GET /api/godot/model_calls/recent`
- `GET /api/godot/demo/list`
- `POST /api/godot/demo/load`
- `POST /api/godot/demo/reset`
- `POST /api/godot/step`
- `POST /api/godot/user_turn`

## 3. snapshot schema 摘要

后端 snapshot 由 `edmas_v1\demo_playback.py` 和 `edmas_v1\godot_api_contract.py` 共同组织。

- `patient_id`：
  - 出现在 `demo_playback.build_demo_snapshot()` 返回的 `patients.patient_id`
  - 也被 `app_core.app.godot_api.get_snapshot()` 读取后写入 envelope
- `patient.location`：
  - 出现在 `demo_playback.build_demo_snapshot()` 返回的 `patients.location`
  - 在 fallback snapshot 中也存在
- `patient.state`：
  - 出现在 `demo_playback.build_demo_snapshot()` 返回的 `patients.state`
- `backend_status`：
  - 出现在 `demo_playback.build_demo_snapshot()` 返回的顶层 `backend_status`
  - 也在 `app_core.app.godot_api.post_step()` 返回中出现
- `demo_id / step / cursor`：
  - `demo_id`：存在，见 `demo_playback.build_demo_snapshot()` 顶层 `sim_id`
  - `step`：存在，见 `demo_playback.build_demo_snapshot()` 顶层 `step`
  - `cursor`：存在，见 `demo_playback.get_current_demo_state()` 和 `DemoSession.cursor`

## 4. MedSquad Godot 项目结构

项目路径：`D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-`

### 4.1 主场景与项目配置

- `project.godot` 存在
- `main_scene` 已设置为 `uid://dj5e7k2td4sek`
- 这是一个 Godot 4.7 项目

### 4.2 目录检查

- `scens\`：存在
- `scenes\`：未发现
- `scripts\`：存在
- `assets\`：存在
- `character\`：存在
- `NPC\`：存在
- `Tilesets\`：存在
- `data\`：存在

### 4.3 现有场景

- `scens\room1.tscn`：存在
- `scens\nurse.tscn`：存在
- `scens\nurse_blue.tscn`：存在
- `scens\nurse_green.tscn`：存在
- `scens\patient_blue.tscn`：存在
- `scens\patient_green.tscn`：存在
- `scens\player.tscn`：存在
- `scens\scrubs_blue.tscn`：存在
- `scens\scrubs_green.tscn`：存在

### 4.4 现有脚本

- `scripts\player.gd`：存在
- `scripts\camera.gd`：存在
- `scripts\nurse.gd`：存在
- `scripts\nurse_blue.gd`：存在
- `scripts\nurse_green.gd`：存在
- `scripts\patient_blue.gd`：存在
- `scripts\patient_green.gd`：存在
- `scripts\scrubs_blue.gd`：存在
- `scripts\scrubs_green.gd`：存在
- `scripts\dialogue\`：存在

### 4.5 现有资源

- `assets\doctor_frames\`：存在
- `assets\nurse_frames\`：存在
- `assets\nurse_blue_frames\`：存在
- `assets\nurse_green_frames\`：存在
- `assets\patient_blue_frames\`：存在
- `assets\patient_green_frames\`：存在
- `assets\scrubs_blue_frames\`：存在
- `assets\scrubs_green_frames\`：存在
- `Tilesets\`：存在，包含 hospital 主题瓦片资源

## 5. 可复用资源

- 主场景：`scens\room1.tscn`
- 角色场景：`scens\player.tscn`、`scens\nurse*.tscn`、`scens\patient*.tscn`
- 动画脚本：`scripts\player.gd`、`scripts\nurse*.gd`、`scripts\patient*.gd`
- 地图/瓦片资源：`Tilesets\`、`assets\rooms\`、`assets\doctor_frames\`
- 对话系统：`scripts\dialogue\`
- Mock flow：`data\mock_flows.json`

## 6. 缺失模块

- `scenes\Main.tscn`：未发现，当前使用的是 `scens\room1.tscn`
- `HospitalMap.tscn`：未发现
- `APIClient` / `HTTPRequest` 专用 Godot 脚本：未发现
- UI button 专用场景：未发现独立的 Godot UI 入口
- 面向 ED-MAS 后端的 Godot API 接入层：未发现

## 7. 推荐下一步修改文件列表

建议优先新增或调整以下文件，不改动现有业务脚本：

- `scens\room1.tscn` 或新增独立前端主场景
- `scripts\api_client.gd`
- `scripts\control_panel.gd`
- `scripts\hospital_map.gd`
- `scripts\patient_manager.gd`
- `scripts\dialogue_panel.gd`
- `project.godot` 中增加后端对接相关 autoload 或默认入口

## 8. 是否建议以 MedSquad- 作为 Godot 客户端主工程

- 建议：**是**
- 原因：
  - 已经是完整 Godot 4 工程
  - 有现成角色、地图、对话、资源体系
  - 适合直接加后端 API 接入层，而不是重建一个新前端工程

## 9. 是否需要修改 ED-MAS 后端

- 结论：**当前不需要修改后端业务逻辑**
- 原因：
  - 后端已提供 `/api/godot/*` 路由
  - snapshot/schema 已可被前端消费
  - 当前更像是前端接入和显示层对齐的问题

## 10. 风险项

- `bin\godot.exe` 在当前环境下不能直接作为正常命令行引擎使用，实际导出/运行依赖本机可用的 Godot 4.7 安装。
- 现有项目主场景是 `scens\room1.tscn`，而非 `scenes\Main.tscn`，后续接入需要统一主入口约定。
- 后端 demo playback 属于后端契约层，前端接入时要区分“回放 demo”与“真实仿真运行”。
- 现有目录中大量资源是现成可复用资产，但命名和路径风格较混杂，前端接入时要避免误改原始资源。

