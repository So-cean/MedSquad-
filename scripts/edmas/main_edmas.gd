extends Control

@onready var api_client: Node = $APIClient
@onready var hospital_map_manager: Node = $ViewportArea/HospitalMapManager
@onready var patient_manager: Node = $ViewportArea/PatientManager
@onready var current_location_label: Label = $UI/VBox/CurrentLocationLabel
@onready var current_state_label: Label = $UI/VBox/CurrentStateLabel
@onready var backend_status_label: Label = $UI/VBox/BackendStatusLabel
@onready var error_label: Label = $UI/VBox/ErrorLabel
@onready var load_demo_a_button: Button = $UI/VBox/LoadDemoAButton
@onready var load_demo_b_button: Button = $UI/VBox/LoadDemoBButton
@onready var load_demo_c_button: Button = $UI/VBox/LoadDemoCButton
@onready var step_button: Button = $UI/VBox/StepButton
@onready var reset_button: Button = $UI/VBox/ResetButton

var _last_snapshot: Dictionary = {}

func _ready() -> void:
	print("[EDMAS] Main_EDMAS scene loaded")
	load_demo_a_button.pressed.connect(func(): _on_load_demo("demo_A"))
	load_demo_b_button.pressed.connect(func(): _on_load_demo("demo_B"))
	load_demo_c_button.pressed.connect(func(): _on_load_demo("demo_C"))
	step_button.pressed.connect(_on_step_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	api_client.snapshot_received.connect(_on_snapshot_received)
	api_client.demo_loaded.connect(_on_demo_loaded)
	api_client.demo_reset.connect(_on_demo_reset)
	api_client.step_completed.connect(_on_step_completed)
	api_client.api_error.connect(_on_api_error)
	if patient_manager != null and patient_manager.has_signal("active_patient_changed"):
		patient_manager.active_patient_changed.connect(_on_active_patient_changed)
	backend_status_label.text = "ED-MAS Main Scene Loaded"
	api_client.get_snapshot()

func _on_load_demo(demo_id: String) -> void:
	api_client.load_demo(demo_id)

func _on_step_pressed() -> void:
	api_client.post_step(1)

func _on_reset_pressed() -> void:
	api_client.reset_demo()

func _on_snapshot_received(data: Dictionary) -> void:
	_last_snapshot = data.duplicate(true)
	if patient_manager != null:
		patient_manager.apply_snapshot(data)
	var patient: Dictionary = _resolve_display_patient(data)
	_update_labels(data, patient)
	if hospital_map_manager != null and hospital_map_manager.has_method("show_map_for_location"):
		hospital_map_manager.show_map_for_location(str(patient.get("location", "ED_ENTRANCE")))
	else:
		error_label.text = "hospital map manager missing show_map_for_location"

func _on_demo_loaded(data: Dictionary) -> void:
	var snapshot_value: Variant = data.get("snapshot", {})
	if typeof(snapshot_value) == TYPE_DICTIONARY:
		_on_snapshot_received(snapshot_value as Dictionary)

func _on_demo_reset(data: Dictionary) -> void:
	var snapshot_value: Variant = data.get("snapshot", {})
	if typeof(snapshot_value) == TYPE_DICTIONARY:
		_on_snapshot_received(snapshot_value as Dictionary)

func _on_step_completed(data: Dictionary) -> void:
	var snapshot_value: Variant = data.get("snapshot", {})
	if typeof(snapshot_value) == TYPE_DICTIONARY:
		_on_snapshot_received(snapshot_value as Dictionary)

func _on_api_error(endpoint: String, message: String) -> void:
	error_label.text = "%s: %s" % [endpoint, message]

func _on_active_patient_changed(patient_id: String) -> void:
	if _last_snapshot.is_empty():
		return
	var patient: Dictionary = _find_patient_by_id(_last_snapshot, patient_id)
	if patient.is_empty():
		patient = _resolve_display_patient(_last_snapshot)
	_update_labels(_last_snapshot, patient)

func _update_labels(data: Dictionary, patient: Dictionary) -> void:
	var display_patient: Dictionary = patient
	if display_patient.is_empty():
		display_patient = _resolve_display_patient(data)
	current_location_label.text = "location: %s" % str(display_patient.get("location", "UNKNOWN"))
	current_state_label.text = "state: %s" % str(display_patient.get("state", "UNKNOWN"))
	backend_status_label.text = "backend_status: %s" % str(data.get("backend_status", "UNKNOWN"))

func _resolve_display_patient(data: Dictionary) -> Dictionary:
	var payload: Dictionary = _normalize_payload(data)
	var active_id: String = ""
	if patient_manager != null and patient_manager.has_method("get_active_patient_id"):
		active_id = str(patient_manager.get_active_patient_id())
	if not active_id.is_empty():
		var active_patient: Dictionary = _find_patient_by_id(payload, active_id)
		if not active_patient.is_empty():
			return active_patient
	var patients: Array = _extract_patients(payload)
	for patient_value in patients:
		if typeof(patient_value) == TYPE_DICTIONARY:
			return patient_value as Dictionary
	return {}

func _find_patient_by_id(data: Dictionary, patient_id: String) -> Dictionary:
	if patient_id.is_empty():
		return {}
	var payload: Dictionary = _normalize_payload(data)
	var patients: Array = _extract_patients(payload)
	for patient_value in patients:
		if typeof(patient_value) != TYPE_DICTIONARY:
			continue
		var patient_data: Dictionary = patient_value as Dictionary
		if str(patient_data.get("patient_id", "")) == patient_id:
			return patient_data
	return {}

func _normalize_payload(data: Dictionary) -> Dictionary:
	var payload_value: Variant = data.get("data", data)
	if typeof(payload_value) == TYPE_DICTIONARY:
		return payload_value as Dictionary
	return data

func _extract_patients(payload: Dictionary) -> Array:
	var patients_value: Variant = payload.get("patients", payload)
	if typeof(patients_value) == TYPE_ARRAY:
		return patients_value as Array
	if typeof(patients_value) == TYPE_DICTIONARY and not (patients_value as Dictionary).is_empty():
		return [patients_value as Dictionary]
	if payload.has("patient_id"):
		return [payload]
	return []
