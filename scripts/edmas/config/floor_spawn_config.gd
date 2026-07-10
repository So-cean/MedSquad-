extends RefCounted
class_name FloorSpawnConfig

const FLOOR_SPAWN_CONFIG: Dictionary = {
	"F1": {
		"floor_id": "F1",
		"display_name": "急诊前线层",
		"auto_spawn": true,
		"spawn_plan": [
			{
				"npc_id": "player_doctor_001",
				"scene_node_name": "Player",
				"scene_path": "res://scens/player.tscn",
				"spawn_position": Vector2(400.0, 350.0),
				"spawn_mode": "existing_or_spawn",
			},
			{
				"npc_id": "triage_nurse_001",
				"scene_node_name": "Nurse",
				"scene_path": "res://scens/nurse.tscn",
				"spawn_position": Vector2(550.0, 300.0),
				"spawn_mode": "existing_or_spawn",
			},
			{
				"npc_id": "triage_nurse_002",
				"scene_node_name": "NurseBlue",
				"scene_path": "res://scens/nurse_blue.tscn",
				"spawn_position": Vector2(650.0, 280.0),
				"spawn_mode": "existing_or_spawn",
			},
			{
				"npc_id": "emergency_nurse_001",
				"scene_node_name": "NurseGreen",
				"scene_path": "res://scens/nurse_green.tscn",
				"spawn_position": Vector2(350.0, 450.0),
				"spawn_mode": "existing_or_spawn",
			},
			{
				"npc_id": "doctor_green_001",
				"scene_node_name": "ScrubsGreen",
				"scene_path": "res://scens/scrubs_green.tscn",
				"spawn_position": Vector2(650.0, 400.0),
				"spawn_mode": "existing_or_spawn",
			},
			{
				"npc_id": "doctor_red_001",
				"scene_node_name": "ScrubsBlue",
				"scene_path": "res://scens/scrubs_blue.tscn",
				"spawn_position": Vector2(750.0, 350.0),
				"spawn_mode": "existing_or_spawn",
			},
			{
				"npc_id": "patient_spawn_point",
				"scene_node_name": "PatientBlue",
				"scene_path": "res://scens/patient_blue.tscn",
				"spawn_position": Vector2(450.0, 450.0),
				"spawn_mode": "existing_or_spawn",
			},
		],
	},
	"F2": {
		"floor_id": "F2",
		"display_name": "检查诊断层",
		"auto_spawn": false,
		"spawn_plan": [
			{
				"npc_id": "lab_nurse_001",
				"scene_node_name": "LabNurse",
				"scene_path": "res://scens/nurse_blue.tscn",
				"spawn_position": Vector2(220.0, 240.0),
				"spawn_mode": "debug_only",
			},
			{
				"npc_id": "lab_technician_001",
				"scene_node_name": "LabTechnician",
				"scene_path": "res://scens/scrubs_blue.tscn",
				"spawn_position": Vector2(300.0, 260.0),
				"spawn_mode": "debug_only",
			},
			{
				"npc_id": "surgeon_001",
				"scene_node_name": "Surgeon",
				"scene_path": "res://scens/scrubs_green.tscn",
				"spawn_position": Vector2(700.0, 240.0),
				"spawn_mode": "debug_only",
			},
		],
	},
	"F3": {
		"floor_id": "F3",
		"display_name": "下游转归层",
		"auto_spawn": false,
		"spawn_plan": [
			{
				"npc_id": "ward_nurse_001",
				"scene_node_name": "WardNurse",
				"scene_path": "res://scens/nurse_green.tscn",
				"spawn_position": Vector2(540.0, 260.0),
				"spawn_mode": "debug_only",
			},
			{
				"npc_id": "qa_officer_001",
				"scene_node_name": "QAOfficer",
				"scene_path": "res://scens/nurse.tscn",
				"spawn_position": Vector2(220.0, 260.0),
				"spawn_mode": "debug_only",
			},
		],
	},
}

static func get_floor_config(floor_id: String) -> Dictionary:
	var floor_value: Variant = FLOOR_SPAWN_CONFIG.get(floor_id, {})
	if typeof(floor_value) == TYPE_DICTIONARY:
		return floor_value as Dictionary
	return {}

static func get_spawn_plan(floor_id: String) -> Array:
	var floor_config: Dictionary = get_floor_config(floor_id)
	var plan_value: Variant = floor_config.get("spawn_plan", [])
	if typeof(plan_value) == TYPE_ARRAY:
		return plan_value as Array
	return []

static func get_auto_spawn_floor_ids() -> Array:
	var floor_ids: Array = []
	for floor_id_value: Variant in FLOOR_SPAWN_CONFIG.keys():
		var floor_id: String = str(floor_id_value)
		var floor_config: Dictionary = get_floor_config(floor_id)
		if bool(floor_config.get("auto_spawn", false)):
			floor_ids.append(floor_id)
	return floor_ids

