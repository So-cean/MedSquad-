extends Node

@export var hospital_map_path: NodePath
@onready var hospital_map: Node2D = get_node(hospital_map_path) as Node2D
const MARKER_FALLBACK := "Marker_ED_Entrance"
var patients: Dictionary = {}

func apply_snapshot(snapshot: Dictionary) -> void:
	var payload_value: Variant = snapshot.get("data", snapshot)
	var payload: Dictionary = snapshot
	if typeof(payload_value) == TYPE_DICTIONARY:
		payload = payload_value as Dictionary
	if payload.has("patient"):
		var nested_value: Variant = payload.get("patient", {})
		if typeof(nested_value) == TYPE_DICTIONARY:
			payload = nested_value as Dictionary
	var patients_value: Variant = payload.get("patients", payload)
	var list: Array = []
	if typeof(patients_value) == TYPE_ARRAY:
		list = patients_value as Array
	elif typeof(patients_value) == TYPE_DICTIONARY and not (patients_value as Dictionary).is_empty():
		list = [patients_value as Dictionary]
	elif payload.has("patient_id"):
		list = [payload]
	for patient_data in list:
		if typeof(patient_data) == TYPE_DICTIONARY:
			create_patient_if_needed(str((patient_data as Dictionary).get("patient_id", "UNKNOWN")))
			update_patient_location(patient_data as Dictionary)

func create_patient_if_needed(patient_id: String) -> void:
	if patients.has(patient_id):
		return
	var sprite_scene: PackedScene = preload("res://scens/edmas/PatientSprite.tscn")
	var sprite: Node = sprite_scene.instantiate()
	var sprite_node: Node2D = sprite as Node2D
	if sprite_node == null:
		push_warning("patient_manager: patient scene is not Node2D")
		return
	sprite_node.setup(patient_id)
	add_child(sprite_node)
	patients[patient_id] = sprite_node
	print("[EDMAS] Patient created: %s" % patient_id)

func update_patient_location(patient_data: Dictionary) -> void:
	var patient_id: String = str(patient_data.get("patient_id", "UNKNOWN"))
	create_patient_if_needed(patient_id)
	var sprite: Node2D = patients[patient_id]
	if hospital_map == null:
		return
	var location_name: String = str(patient_data.get("location", "ED_ENTRANCE"))
	var target_position: Vector2 = _get_marker_position(location_name)
	if sprite.has_method("apply_patient_state"):
		sprite.apply_patient_state(patient_data)
	if sprite.has_method("move_to"):
		sprite.move_to(target_position)
	print("[EDMAS] Patient moved to: %s" % location_name)

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
	return marker_2d.global_position
