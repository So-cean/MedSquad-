extends BaseNpc
class_name MapNpc

var role_profile: Dictionary = {}
var runtime_goal: String = ""
var runtime_location: String = ""
var runtime_floor: String = ""
var runtime_role: String = ""

func apply_role_profile(profile: Dictionary) -> void:
	role_profile = profile.duplicate(true)
	runtime_role = str(profile.get("role", "npc"))
	runtime_floor = str(profile.get("floor", ""))
	runtime_location = str(profile.get("home_location", "ED_ENTRANCE"))
	runtime_goal = str(profile.get("current_goal", "observe"))
	set_meta("role_profile", role_profile)
	set_meta("npc_id", str(profile.get("npc_id", "")))
	set_meta("display_name", str(profile.get("display_name", get_npc_name())))
	set_meta("role", runtime_role)
	set_meta("floor", runtime_floor)
	set_meta("current_location", runtime_location)
	set_meta("current_state", str(profile.get("idle_mode", "idle")))
	set_meta("current_goal", runtime_goal)
	set_meta("llm_enabled", bool(profile.get("llm_enabled", false)))
	set_meta("resource_role", profile.get("resource_role", null))
	set_meta("scheduler_eligible", bool(profile.get("scheduler_eligible", false)))

func get_frames_dir() -> String:
	var frames_value: Variant = role_profile.get("frames_dir", "")
	if typeof(frames_value) == TYPE_STRING and not str(frames_value).is_empty():
		return str(frames_value)
	return "res://assets/patient_blue_frames/"

func get_npc_name() -> String:
	var display_value: Variant = role_profile.get("display_name", "MapNpc")
	return str(display_value)

func get_walk_flip_dirs() -> Array[String]:
	var value: Variant = role_profile.get("walk_flip_dirs", [])
	if typeof(value) == TYPE_ARRAY:
		return value as Array[String]
	return []

func get_npc_group() -> String:
	var value: Variant = role_profile.get("npc_group", "npcs")
	return str(value)

func get_hover_payload() -> Dictionary:
	var payload: Dictionary = role_profile.duplicate(true)
	payload["current_state"] = str(get_meta("current_state", "idle"))
	payload["current_location"] = str(get_meta("current_location", runtime_location))
	payload["current_goal"] = str(get_meta("current_goal", runtime_goal))
	return payload

