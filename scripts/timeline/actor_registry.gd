class_name ActorRegistry
extends RefCounted

var _by_id: Dictionary = {}


func scan(root: Node) -> void:
	_by_id.clear()
	for node in root.get_tree().get_nodes_in_group("npcs"):
		if not (node is BaseNpc):
			continue
		var npc := node as BaseNpc
		match npc.get_npc_name():
			"分诊护士":
				_by_id["nurse_001"] = npc
			"手术医生":
				_by_id["doctor_001"] = npc
			"患者":
				if not _by_id.has("patient_actor_001"):
					_by_id["patient_actor_001"] = npc


func get_actor(actor_id: String) -> BaseNpc:
	return _by_id.get(actor_id) as BaseNpc


func has_actor(actor_id: String) -> bool:
	return _by_id.has(actor_id)
