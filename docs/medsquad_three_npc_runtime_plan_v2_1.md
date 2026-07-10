# MedSquad 三层多 NPC 运行时分阶段落地计划 v2.1

## Summary
以 `week13/MedSquad-` 的 `room1.tscn` 作为默认运行入口，继续保留 `BaseNpc + DialogueManager + MemoryStore + MockDialogueSystem` 作为本地基线。先把默认画面收敛到完整 ED Core 地图，再按“世界层 -> 会话层”建立三层角色配置、NPC 初始化、hover 状态、动态患者与本地 mock 会话。默认主线不接真实后端 API，不引入真实 LLM，不使用 `map` 分支内容。

## Phase 0: Runtime Shell + ED Core Map Replacement
- 保留 `project.godot` 默认入口为 `res://scens/room1.tscn`。
- 将完整 ED Core 地图静态复制到 `assets/maps/edmas/`，让 `room1.tscn` 直接引用 `map1_v2.png` 作为 F1 背景。
- `room1.tscn` 中旧 partial room 背景先隐藏，不删除。
- 保留 `NpcManager`、`NpcHoverCard`、`SessionRuntime`、`Player`、`Camera`、`DialogueManager` 这条运行壳。
- 验收必须同时包含：
  - `EDCoreMapSprite.position = Vector2(0, 0)`
  - `EDCoreMapSprite.centered = false`
  - 地图坐标系以左上角为原点
  - 当前 `Camera2D / viewport` 下能完整看到 ED Core 地图主体
  - NPC spawn 坐标与 `map1_v2.png` 像素坐标一致
- 自动测试：`tests/godot/test_room1_ed_core_map.py`。

## Phase 1: World / Role Runtime
- 新增静态配置：`role_profiles.gd`、`floor_spawn_config.gd`。
- `NpcManager` 默认只 spawn `F1`，并显式设置 `default_active_floor = "F1"`。
- `F2 / F3` 仅完成配置与测试，不在默认 `room1.tscn` 运行时自动实例化。
- 明确玩家医生与 NPC 医生分离：`player_doctor_001` 不进入资源调度；`doctor_green_001` / `doctor_red_001` 作为可调度医生保留。
- `NpcHoverCard` 只展示基础态：`display_name`、`role`、`floor`、`current_state`、`current_location`、`current_goal`、`llm_enabled`、`resource_role`、`scheduler_eligible`。
- `ResourceRegistry` 默认只注册 active floor 的可调度 NPC，`F2 / F3` 资源保留到楼层激活时再进入 active pool。

## Phase 2A: Dynamic Patient + Mock Triage Session
- 新增 `patient_case_pool.gd`、`patient_factory.gd`、`interaction_session.gd`、`session_manager.gd`。
- 动态生成 patient，绑定 mock case，状态从 `ARRIVED` 开始，位置从 `ED_ENTRANCE` 进入。
- 动态患者单独加入 `dynamic_patients`，不进入旧 `npcs` 组，避免和 legacy mock flow 串台。
- 动态患者仍需保留对话气泡能力：保留 `DialogueManager` / `BaseNpc.speak()` 链路。
- 本阶段只做局部 triage 会话，用 mock dialogue 驱动，不接真实 LLM。
- Phase 2A 固定使用 `direct_move_to_marker` 作为临时移动策略，完整 pathfinding 留到后续 MovementController / Navigation 阶段。

## Phase 2B: Player Intervention UI
- `SessionRuntime` 根据玩家与 active session 的距离显示介入面板。
- 面板按钮固定为 `Patient / Nurse / Doctor / Advance`。
- 左上角 `SessionPanel` 内显示；只在 active session 存在且玩家距离 session center 小于阈值时显示；阈值先设为 `120px`；无 active session 时隐藏。
- 点击按钮只影响当前 session，不影响全局调度，也不接真实 LLM。

## Boundary
- 本轮实施范围仅覆盖：`Phase 0 / Phase 1 / Phase 2A / Phase 2B`
- `NPC idle / patrol`
- `MovementController / full navigation`
- `LLM decision / backend API`
- `状态 dashboard`
- 以上内容均不在本轮实现范围，后续单独开 Phase 3 / 4。

## Assumptions
- 默认运行入口始终是 `room1.tscn`，不切换到 `map` 分支主场景。
- `map` 分支内容仅作为归档参考，不进入默认 runtime。
- 旧 `BaseNpc` / `DialogueManager` / `MockDialogueSystem` 保留，但只作为 room1 baseline 的本地前端链路。
- Phase 0 只替换 ED Core 视觉背景，不引入真实后端 API、真实 LLM 或完整自动寻路。
- F2 / F3 完成配置，但默认不进入 `ResourceRegistry` active pool。
- Phase 2A 先用 `direct_move_to_marker` 保证会话可验证，后续再单独升级移动系统。
