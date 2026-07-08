extends Node2D

## 分诊测试场景
##
## NpcManager 自主驱动所有 NPC 对话和移动。
## 本脚本只负责：发现NPC → 启动auto loop → 监听事件。

func _ready() -> void:
	await get_tree().create_timer(1.5).timeout

	# NpcManager 已经在 _ready 自动发现并注册了场景NPC
	# 这里只需要启动自主对话循环

	# 连接事件
	NpcManager.patient_arrived.connect(_on_patient_arrived)
	NpcManager.triage_started.connect(_on_triage_started)
	NpcManager.triage_done.connect(_on_triage_done)
	NpcManager.all_triage_done.connect(_on_all_done)

	print("[Test] 启动自主对话循环")
	NpcManager.start_auto_loop()


func _on_patient_arrived(npc_id: String, npc: BaseNpc) -> void:
	print("[Test] 患者到达: %s (%s)" % [npc_id, npc.get_npc_name()])


func _on_triage_started(npc_id: String) -> void:
	print("[Test] 开始分诊: %s" % npc_id)


func _on_triage_done(npc_id: String, target_room: String) -> void:
	print("[Test] 分诊完成: %s → 去%s" % [npc_id, target_room if not target_room.is_empty() else "候诊"])


func _on_all_done() -> void:
	print("\n[Test] 全部分诊完成")
	NpcManager.print_status()
	print("[Test] 测试结束")
	# Clear bubbles
	for npc in NpcManager.get_all_npcs():
		npc.stop_speaking()
