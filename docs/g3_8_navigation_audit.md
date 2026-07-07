# G3.8 Navigation Audit

## 1. 当前 PatientSprite 是什么

- 当前实现位置：
  - [scens/edmas/PatientSprite.tscn](D:/projects/BME1325Spring2026/ED-MAS/godot_client/MedSquad-/scens/edmas/PatientSprite.tscn)
  - [scripts/edmas/patient_sprite.gd](D:/projects/BME1325Spring2026/ED-MAS/godot_client/MedSquad-/scripts/edmas/patient_sprite.gd)
- 结论：
  - `PatientSprite.tscn` 当前只有 `Node2D` + `scripts/edmas/patient_sprite.gd`
  - `patient_sprite.gd` 运行时创建的是 `ColorRect` placeholder
  - 不是 `Sprite2D`
  - 不是 `AnimatedSprite2D`

## 2. 患者素材审计

### 2.1 推荐替换 placeholder 的资源

最适合的患者素材路径：

- [assets/patient_blue_frames](D:/projects/BME1325Spring2026/ED-MAS/godot_client/MedSquad-/assets/patient_blue_frames)

理由：

- 有 18 个 PNG 文件
- 每张都是 32x32
- 文件名是标准方向/动作序列：
  - `idle_down.png`
  - `idle_up.png`
  - `walk_up_a.png`
  - `walk_up_b.png`
  - `walk_down_a.png`
  - `walk_down_b.png`
  - 其余 8 方向帧
- 这说明它更适合做 `AnimatedSprite2D`

备选资源：

- [character/patient blue.png](D:/projects/BME1325Spring2026/ED-MAS/godot_client/MedSquad-/character/patient%20blue.png)
- [character/patient green.png](D:/projects/BME1325Spring2026/ED-MAS/godot_client/MedSquad-/character/patient%20green.png)

### 2.2 `patient_blue_frames` 是什么

- 它是单帧 PNG 序列，不是整张 spritesheet
- 审计结果：
  - `18 png files`
  - 每张 `32 x 32`
  - `RGBA`
- 所以最小实现建议是 `AnimatedSprite2D`

### 2.3 `patient green / blue` 是否是整张 spritesheet

- 不是传统意义上的大 spritesheet
- 目前看到的是：
  - `character/patient blue.png`，`32 x 32`
  - `character/patient green.png`，`32 x 32`
- 更像单图图标/占位角色图
- 真正适合动画的是 `assets/patient_blue_frames` / `assets/patient_green_frames`

## 3. movement 审计

- 当前移动逻辑位置：
  - [scripts/edmas/patient_manager.gd](D:/projects/BME1325Spring2026/ED-MAS/godot_client/MedSquad-/scripts/edmas/patient_manager.gd)
  - [scripts/edmas/patient_sprite.gd](D:/projects/BME1325Spring2026/ED-MAS/godot_client/MedSquad-/scripts/edmas/patient_sprite.gd)
- 结论：
  - 当前是直线移动
  - `patient_manager.gd` 根据 marker 位置调用 `move_to(target_position)`
  - `patient_sprite.gd` 使用 `Tween` 直接 tween `global_position`
  - 目前没有路径点列表
  - 目前没有绕墙
  - 目前没有 `AStarGrid2D`

## 4. 地图与 marker 审计

### 4.1 HospitalMap 是否有 Marker2D 清单

是，位置在：

- [scens/edmas/HospitalMap.tscn](D:/projects/BME1325Spring2026/ED-MAS/godot_client/MedSquad-/scens/edmas/HospitalMap.tscn)

已存在的 marker 包括：

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

### 4.2 是否已有 masks 目录

是，存在：

- [assets/maps/masks](D:/projects/BME1325Spring2026/ED-MAS/godot_client/MedSquad-/assets/maps/masks)

### 4.3 是否已有 mask 文件

是，三张都已存在：

- `map1_walkable_mask.png`
- `map2_walkable_mask.png`
- `map3_walkable_mask.png`

### 4.4 地图尺寸

三张 normalized 地图尺寸都为：

- `1672 x 941`

对应路径：

- [assets/maps/normalized/map1_norm.png](D:/projects/BME1325Spring2026/ED-MAS/godot_client/MedSquad-/assets/maps/normalized/map1_norm.png)
- [assets/maps/normalized/map2_norm.png](D:/projects/BME1325Spring2026/ED-MAS/godot_client/MedSquad-/assets/maps/normalized/map2_norm.png)
- [assets/maps/normalized/map3_norm.png](D:/projects/BME1325Spring2026/ED-MAS/godot_client/MedSquad-/assets/maps/normalized/map3_norm.png)

## 5. mask 现状

### 5.1 mask 尺寸

三张 mask 与 normalized 地图一致：

- `1672 x 941`

### 5.2 mask 内容

当前三张 mask 都是全白：

- 只有 `255`
- 没有黑色障碍信息

结论：

- 目前是 placeholder mask
- 不能代表真实墙体识别
- 暂时不能用于真实绕行

## 6. 当前最小实现建议

### 推荐方案

优先使用：

- `AnimatedSprite2D`

推荐资源：

- [assets/patient_blue_frames](D:/projects/BME1325Spring2026/ED-MAS/godot_client/MedSquad-/assets/patient_blue_frames)

### 备选方案

如果动画接入暂时不稳定，可先用：

- [character/patient blue.png](D:/projects/BME1325Spring2026/ED-MAS/godot_client/MedSquad-/character/patient%20blue.png)

但这仍应挂在 `Sprite2D` 上，而不是继续用 `ColorRect`

## 7. 下一阶段是否可执行

结论：**可以执行**

原因：

- 患者素材已存在
- 地图尺寸已知
- marker 已存在
- mask 目录已存在
- 当前 movement 是直线移动，便于替换为 path movement

但需要注意：

- mask 当前是全白占位
- 真实绕墙需要下一阶段补充路径规划实现
