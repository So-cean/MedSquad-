extends BaseNpc

## Patient blue — uses walk_a→walk_b for up/down walk cycle

func get_frames_dir() -> String:
	return "res://assets/patient_blue_frames/"

func get_npc_name() -> String:
	return "患者"

func get_walk_flip_dirs() -> Array[String]:
	return ["up", "down"]

func get_npc_group() -> String:
	return "dynamic_patients"
