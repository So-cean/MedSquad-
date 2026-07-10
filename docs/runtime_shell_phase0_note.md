# Runtime Shell Phase 0 Note

## 当前默认运行入口

- `project.godot` 仍然指向 `res://scens/room1.tscn`

## 当前主背景

- `room1.tscn` 已切换为完整 ED Core 地图背景
- 地图资源路径：`res://assets/maps/edmas/map1_v2.png`
- 旧 partial room 背景保留，但默认隐藏

## Phase 0 验收补充

- `EDCoreMapSprite.position = Vector2(0, 0)`
- `EDCoreMapSprite.centered = false`
- 地图坐标系以左上角为原点
- 当前 `Camera2D / viewport` 下能完整看到 ED Core 地图主体
- NPC spawn 坐标与 `map1_v2.png` 像素坐标一致

## 保留的运行壳

- `NpcManager`
- `NpcHoverCard`
- `SessionRuntime`
- `DialogueManager`

## Phase 1 边界补充

- `NpcManager` 默认只 spawn `F1`
- `F2 / F3` 只保留配置与测试，不在默认 runtime 自动实例化
- `ResourceRegistry` 默认只注册 active floor 的可调度 NPC
- `F2 / F3` 资源等楼层激活时再注册

## Phase 2A / 2B 边界补充

- 动态患者保持 `DialogueManager` / `BaseNpc.speak()` 气泡链路
- Phase 2A 使用 `direct_move_to_marker` 作为临时移动策略
- Phase 2B 按钮位于左上角 `SessionPanel`，仅在 active session 且玩家接近时显示

## 范围声明

- 本轮实施范围：Phase 0 / Phase 1 / Phase 2A / Phase 2B
- Phase 3 `MovementController / Patrol / Navigation` 后续单独实施
- Phase 4 `LLM Decision / Backend API` 后续单独实施
