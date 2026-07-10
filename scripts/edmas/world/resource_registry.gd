extends RefCounted
class_name ResourceRegistry

static func get_role_profile(npc_id: String) -> Dictionary:
	return RoleProfiles.get_profile(npc_id)

static func get_profiles_for_floor(floor_id: String) -> Array:
	return RoleProfiles.get_profiles_for_floor(floor_id)

static func get_floor_config(floor_id: String) -> Dictionary:
	return FloorSpawnConfig.get_floor_config(floor_id)

static func get_spawn_plan(floor_id: String) -> Array:
	return FloorSpawnConfig.get_spawn_plan(floor_id)

static func get_auto_spawn_floor_ids() -> Array:
	return FloorSpawnConfig.get_auto_spawn_floor_ids()

static func get_scene_path_for_role(npc_id: String) -> String:
	var profile: Dictionary = get_role_profile(npc_id)
	var scene_value: Variant = profile.get("scene_path", "")
	if typeof(scene_value) == TYPE_STRING:
		return str(scene_value)
	return ""

