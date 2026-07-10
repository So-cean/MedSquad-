# MedSquad 三层多 NPC 运行时索引

> 说明：当前正式计划以 [medsquad_three_npc_runtime_plan_v2_1.md](./medsquad_three_npc_runtime_plan_v2_1.md) 为准。

## 当前结论

- 默认入口仍然是 `res://scens/room1.tscn`
- Phase 0 先替换为完整 ED Core 地图，并补 camera / viewport 验收
- Phase 1 默认只 spawn F1
- F2 / F3 只保留配置，不进入默认 active pool
- Phase 2A 动态患者仍需保留对话气泡能力
- Phase 2A 使用 `direct_move_to_marker`
- Phase 2B 介入按钮位于左上角 SessionPanel，且受距离条件控制
- 本轮只覆盖 Phase 0 / 1 / 2A / 2B

## 相关文档

- [Runtime Shell Phase 0 Note](./runtime_shell_phase0_note.md)
- [MedSquad 三层多 NPC 运行时分阶段落地计划 v2.1](./medsquad_three_npc_runtime_plan_v2_1.md)
