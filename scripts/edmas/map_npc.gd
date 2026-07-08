extends BaseNpc

## Map NPC — configured via @export vars, no subclass needed.
## Wandering controlled by parent's can_wander (default false).

@export var npc_display_name: String = "NPC"
@export var npc_frames_dir: String = ""
@export var npc_walk_flip: Array[String] = []

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
	# Wander only if parent's can_wander=true
	if can_wander:
		super._physics_process(delta)
	else:
		# Stationary — soft separation only
		_separate_from_npcs()
