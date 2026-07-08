extends BaseNpc

## Stationary NPC placed on the EDMAS map.
## Wandering is disabled by default. Can still walk_to() if has NavigationAgent2D.

@export var npc_display_name: String = "NPC"
@export var npc_frames_dir: String = ""
@export var npc_walk_flip: Array[String] = []
@export var can_wander: bool = false  # NPC不自由移动，只在被指令时才动

func get_frames_dir() -> String:
	return npc_frames_dir

func get_npc_name() -> String:
	return npc_display_name

func get_walk_flip_dirs() -> Array[String]:
	return npc_walk_flip

func _physics_process(delta: float) -> void:
	# Navigation takes priority
	if _is_walking and _nav_agent:
		_nav_step()
		_update_anim()
		_separate_from_npcs()
		return
	# Wander only if explicitly enabled
	if can_wander:
		super._physics_process(delta)
	else:
		# Stationary — just do soft separation + keep idle anim
		_separate_from_npcs()
