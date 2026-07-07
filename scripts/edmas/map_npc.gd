extends BaseNpc

## Stationary NPC placed on the EDMAS map.
## No movement/collision — serves as dialogue anchor for MockDialogueSystem.

@export var npc_display_name: String = "NPC"
@export var npc_frames_dir: String = ""
@export var npc_walk_flip: Array[String] = []

func get_frames_dir() -> String:
	return npc_frames_dir

func get_npc_name() -> String:
	return npc_display_name

func get_walk_flip_dirs() -> Array[String]:
	return npc_walk_flip

func _physics_process(_delta: float) -> void:
	# Stationary — no movement
	pass
