extends Node2D


func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	NpcManager.patient_arrived.connect(_on_patient_arrived)
	NpcManager.patient_discharged.connect(_on_patient_discharged)
	print("[Test] spawning scheduler scenario")
	await NpcManager.spawn_scenario(ScenarioConfig.DEFAULT)


func _on_patient_arrived(npc_id: String, npc: BaseNpc) -> void:
	print("[Test] patient arrived: %s (%s)" % [npc_id, npc.get_npc_name()])


func _on_patient_discharged(npc_id: String) -> void:
	print("[Test] patient discharged: %s" % npc_id)
