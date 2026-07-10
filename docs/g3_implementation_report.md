# G3 Implementation Report

## 新增文件

- `assets/maps/map1_v1.png`
- `assets/maps/map2_v3.png`
- `assets/maps/map3_v1.png`
- `scripts/edmas/config.gd`
- `scripts/edmas/api_client.gd`
- `scripts/edmas/hospital_map_manager.gd`
- `scripts/edmas/patient_sprite.gd`
- `scripts/edmas/patient_manager.gd`
- `scripts/edmas/main_edmas.gd`
- `scens/edmas/HospitalMap.tscn`
- `scens/edmas/PatientSprite.tscn`
- `scens/edmas/Main_EDMAS.tscn`
- `tests/godot/test_edmas_godot_structure.py`

## 使用的 API

- `GET /api/godot/demo/list`
- `POST /api/godot/demo/load`
- `POST /api/godot/demo/reset`
- `GET /api/godot/snapshot`
- `POST /api/godot/step`
- `GET /api/godot/events/recent`
- `GET /api/godot/model_calls/recent`
- `POST /api/godot/user_turn`

## 三张地图路径

- `res://assets/maps/map1_v1.png`
- `res://assets/maps/map2_v3.png`
- `res://assets/maps/map3_v1.png`

## Marker 清单

- `Marker_ED_Entrance`
- `Marker_Triage`
- `Marker_Waiting`
- `Marker_Doctor`
- `Marker_ED_Resus`
- `Marker_Lab`
- `Marker_Imaging`
- `Marker_Diagnostic_Waiting`
- `Marker_Result_Review`
- `Marker_Disposition`
- `Marker_ICU`
- `Marker_Ward`
- `Marker_ED_Boarding`
- `Marker_Discharge`
- `Marker_Elevator_ED`
- `Marker_Elevator_Diagnostics`
- `Marker_Elevator_Downstream`

## snapshot 兼容方式

- 后端返回 envelope：`{ok, fallback_used, data}`
- `main_edmas.gd` 会先读取 `data`，再解包 `patients`
- `patients` 支持单对象和数组两种形式
- 前端只根据 `location` 驱动地图和移动，不推断下一状态

## 手动运行步骤

1. 打开 `D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-\project.godot`
2. 打开场景 `res://scens/edmas/Main_EDMAS.tscn`
3. 确认 ED-MAS 后端已启动并提供 `/api/godot/*`
4. 点击 `Load Demo A / B / C`
5. 点击 `Step`
6. 观察地图切换与患者位置变化

## 已知问题

- 当前 `PatientSprite` 先用 placeholder 图形，不依赖患者素材。
- 当前版本未做平滑跨图淡入淡出，仅做三地图 show/hide。
- 需要在 Godot Editor 中手动确认 `project.godot` 打开后能解析所有资源路径。

