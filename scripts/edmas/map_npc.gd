extends BaseNpc

## Stationary NPC placed on the EDMAS map.
## Wandering is disabled by default. Can still walk_to() if has NavigationAgent2D.

@export var npc_display_name: String = "NPC"
@export var npc_frames_dir: String = ""
@export var npc_walk_flip: Array[String] = []
@export var can_wander: bool = true  # idle NPCs wander slightly

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
		return
	# Optional wandering
	if can_wander:
		super._physics_process(delta)
	# else: stationary — no movement, no collision
