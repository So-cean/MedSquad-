extends Node

signal active_patient_changed(patient_id)

const NavigationService = preload("res://scripts/edmas/navigation/navigation_service.gd")

@export var hospital_map_path: NodePath
@onready var hospital_map: Node2D = get_node_or_null(hospital_map_path) as Node2D

const MARKER_FALLBACK := "Marker_ED_Entrance"

var patient_sprites: Dictionary = {}
var patient_states: Dictionary = {}
var active_patient_id: String = ""
var _navigation_service: NavigationService = NavigationService.new()

func apply_snapshot(snapshot: Dictionary) -> void:
	var payload: Dictionary = _normalize_payload(snapshot)
	var patients_list: Array = _extract_patients(payload)
	var present_ids: Array[String] = []

	for patient_value in patients_list:
		if typeof(patient_value) != TYPE_DICTIONARY:
			continue
		var patient_data: Dictionary = patient_value as Dictionary
		var patient_id: String = str(patient_data.get("patient_id", "UNKNOWN"))
		if patient_id.is_empty():
			continue
		if not present_ids.has(patient_id):
			present_ids.append(patient_id)
		create_patient_if_needed(patient_id)
		update_patient_location(patient_data)

	_prune_missing_patients(present_ids)
	_sync_active_patient(present_ids)

func create_patient_if_needed(patient_id: String) -> void:
	if patient_sprites.has(patient_id):
		return
	var sprite_scene: PackedScene = preload("res://scens/edmas/PatientSprite.tscn")
	var sprite: Node = sprite_scene.instantiate()
	var sprite_node: Node2D = sprite as Node2D
	if sprite_node == null:
		push_warning("patient_manager: patient scene is not Node2D")
		return
	sprite_node.name = "Patient_%s" % patient_id
	if sprite_node.has_method("setup"):
		sprite_node.setup(patient_id)
	add_child(sprite_node)
	patient_sprites[patient_id] = sprite_node
	if not patient_states.has(patient_id):
		patient_states[patient_id] = {}
	patient_states[patient_id]["location"] = "ED_ENTRANCE"
	patient_states[patient_id]["state"] = "UNKNOWN"
	print("[EDMAS][PATIENT] created %s" % patient_id)

func update_patient_location(patient_data: Dictionary) -> void:
	var patient_id: String = str(patient_data.get("patient_id", "UNKNOWN"))
	create_patient_if_needed(patient_id)
	var sprite: Node2D = patient_sprites.get(patient_id) as Node2D
	if sprite == null:
		return
	var location_name: String = str(patient_data.get("location", "ED_ENTRANCE"))
	var state_name: String = str(patient_data.get("state", "UNKNOWN"))
	var current_state: Dictionary = {}
	if patient_states.has(patient_id) and typeof(patient_states[patient_id]) == TYPE_DICTIONARY:
		current_state = patient_states[patient_id] as Dictionary
	var old_location: String = str(current_state.get("location", ""))
	var next_state: Dictionary = {
		"location": location_name,
		"state": state_name,
	}
	patient_states[patient_id] = next_state
	if sprite.has_method("apply_patient_state"):
		sprite.apply_patient_state(patient_data)
	if old_location == location_name:
		print("[EDMAS][PATIENT] no location change %s" % patient_id)
		return
	print("[EDMAS][PATIENT] update %s: %s -> %s" % [patient_id, old_location, location_name])
	var target_position: Vector2 = _get_marker_position(location_name)
	var path_points: Array[Vector2] = _get_path_to_location(sprite.position, target_position, location_name)
	if not path_points.is_empty() and sprite.has_method("move_along_path"):
		sprite.move_along_path(path_points)
	elif sprite.has_method("move_to"):
		push_warning("patient_manager: navigation fallback move_to for %s -> %s" % [patient_id, location_name])
		sprite.move_to(target_position)

func get_active_patient_id() -> String:
	return active_patient_id

func _normalize_payload(snapshot: Dictionary) -> Dictionary:
	var payload_value: Variant = snapshot.get("data", snapshot)
	if typeof(payload_value) == TYPE_DICTIONARY:
		return payload_value as Dictionary
	return snapshot

func _extract_patients(payload: Dictionary) -> Array:
	var patients_value: Variant = payload.get("patients", payload)
	if typeof(patients_value) == TYPE_ARRAY:
		return patients_value as Array
	if typeof(patients_value) == TYPE_DICTIONARY and not (patients_value as Dictionary).is_empty():
		return [patients_value as Dictionary]
	if payload.has("patient_id"):
		return [payload]
	return []

func _prune_missing_patients(present_ids: Array[String]) -> void:
	var existing_ids: Array = patient_sprites.keys()
	for existing_id_value in existing_ids:
		var existing_id: String = str(existing_id_value)
		if present_ids.has(existing_id):
			continue
		var sprite: Node = patient_sprites.get(existing_id) as Node
		if sprite != null and sprite.is_inside_tree():
			sprite.queue_free()
		patient_sprites.erase(existing_id)
		patient_states.erase(existing_id)
		print("[EDMAS][PATIENT] removed stale %s" % existing_id)

func _sync_active_patient(present_ids: Array[String]) -> void:
	var next_active: String = active_patient_id
	if present_ids.is_empty():
		next_active = ""
	elif next_active.is_empty() or not present_ids.has(next_active):
		next_active = present_ids[0]
	if next_active != active_patient_id:
		active_patient_id = next_active
		active_patient_changed.emit(active_patient_id)

func _get_marker_position(location_name: String) -> Vector2:
	var marker_name: String = "Marker_%s" % location_name
	if hospital_map == null:
		return Vector2.ZERO
	var marker_node: Node = hospital_map.get_node_or_null(marker_name)
	if marker_node == null:
		marker_node = hospital_map.get_node_or_null(MARKER_FALLBACK)
	if marker_node == null:
		push_warning("patient_manager: missing marker %s and fallback %s" % [marker_name, MARKER_FALLBACK])
		return Vector2.ZERO
	var marker_2d: Marker2D = marker_node as Marker2D
	if marker_2d == null:
		push_warning("patient_manager: marker is not Marker2D: %s" % marker_name)
		return Vector2.ZERO
	return marker_2d.position

func _get_path_to_location(start_position: Vector2, target_position: Vector2, location_name: String) -> Array[Vector2]:
	if hospital_map == null:
		push_warning("patient_manager: navigation unavailable without hospital_map")
		return []
	var map_id: String = "MAP_ED_CORE"
	if hospital_map.has_method("get_map_id_for_location"):
		map_id = str(hospital_map.call("get_map_id_for_location", location_name))
	if not _navigation_service.build_for_map(map_id):
		return []
	return _navigation_service.get_path(start_position, target_position)
