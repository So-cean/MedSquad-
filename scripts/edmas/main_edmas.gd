extends Control

const _DemoProvider = preload("res://scripts/edmas/mock/mock_demo_provider.gd")
const _AgentProfiles = preload("res://scripts/edmas/mock/mock_agent_profiles.gd")
const MAP_SIZE := Vector2(1672.0, 941.0)

@onready var api_client: Node = $APIClient
@onready var map_root: Node2D = $MapRoot
@onready var hospital_map_manager: Node = $MapRoot/HospitalMapManager
@onready var patient_manager: Node = $MapRoot/PatientManager
@onready var fade_overlay: ColorRect = $CanvasLayer/FadeOverlay
@onready var mock_mode_toggle: CheckBox = $CanvasLayer/UI/VBox/MockModeToggle
@onready var current_location_label: Label = $CanvasLayer/UI/VBox/CurrentLocationLabel
@onready var current_state_label: Label = $CanvasLayer/UI/VBox/CurrentStateLabel
@onready var backend_status_label: Label = $CanvasLayer/UI/VBox/BackendStatusLabel
@onready var error_label: Label = $CanvasLayer/UI/VBox/ErrorLabel
@onready var load_demo_a_button: Button = $CanvasLayer/UI/VBox/LoadDemoAButton
@onready var load_demo_b_button: Button = $CanvasLayer/UI/VBox/LoadDemoBButton
@onready var load_demo_c_button: Button = $CanvasLayer/UI/VBox/LoadDemoCButton
@onready var step_button: Button = $CanvasLayer/UI/VBox/StepButton
@onready var reset_button: Button = $CanvasLayer/UI/VBox/ResetButton
@onready var dialogue_panel: Control = $CanvasLayer/UI/DialoguePanel
@onready var speaker_label: Label = $CanvasLayer/UI/DialoguePanel/VBox/SpeakerLabel
@onready var dialogue_text_label: Label = $CanvasLayer/UI/DialoguePanel/VBox/DialogueTextLabel
@onready var talk_button: Button = $CanvasLayer/UI/DialoguePanel/VBox/HBox/TalkButton
@onready var next_dialogue_button: Button = $CanvasLayer/UI/DialoguePanel/VBox/HBox/NextDialogueButton
var _mock_provider = _DemoProvider.new()
var _agent_profiles = _AgentProfiles.new()
var _use_mock_mode: bool = true
var _active_patient_id: String = ""
var _active_profile: Dictionary = {}
var _dialogue_lines: Array = []
var _dialogue_index: int = -1
var _dialogue_started: bool = false

func _ready() -> void:
	print("[EDMAS] Main_EDMAS scene loaded")
	backend_status_label.text = "ED-MAS Main Scene Loaded"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fit_map_to_viewport()
	var vp: Viewport = get_viewport()
	if vp != null and vp.has_signal("size_changed"):
		vp.size_changed.connect(_fit_map_to_viewport)
	_use_mock_mode = mock_mode_toggle.button_pressed
	mock_mode_toggle.toggled.connect(_on_mock_mode_toggled)
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
	talk_button.pressed.connect(_on_talk_pressed)
	next_dialogue_button.pressed.connect(_on_next_dialogue_pressed)
	if _use_mock_mode:
		_apply_snapshot(_mock_provider.get_snapshot())
	else:
		api_client.get_snapshot()
	_refresh_dialogue_panel()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_map_to_viewport()

func _fit_map_to_viewport() -> void:
	if map_root == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var scale_factor: float = min(viewport_size.x / MAP_SIZE.x, viewport_size.y / MAP_SIZE.y)
	map_root.scale = Vector2(scale_factor, scale_factor)
	map_root.position = Vector2(
		(viewport_size.x - MAP_SIZE.x * scale_factor) / 2.0,
		(viewport_size.y - MAP_SIZE.y * scale_factor) / 2.0
	)

func _on_mock_mode_toggled(button_pressed: bool) -> void:
	_use_mock_mode = button_pressed
	if _use_mock_mode:
		error_label.text = "mock mode enabled"
		_apply_snapshot(_mock_provider.get_snapshot())
	else:
		error_label.text = "real API mode enabled"
		api_client.get_snapshot()

func _on_load_demo(demo_id: String) -> void:
	if _use_mock_mode:
		_apply_snapshot(_mock_provider.load_demo(demo_id))
	else:
		api_client.load_demo(demo_id)

func _on_step_pressed() -> void:
	if _use_mock_mode:
		_apply_snapshot(_mock_provider.step_demo(1))
	else:
		api_client.post_step(1)

func _on_reset_pressed() -> void:
	if _use_mock_mode:
		_apply_snapshot(_mock_provider.reset_demo())
	else:
		api_client.reset_demo()

func _on_snapshot_received(data: Dictionary) -> void:
	if not _use_mock_mode:
		_apply_snapshot(data)

func _on_demo_loaded(data: Dictionary) -> void:
	if _use_mock_mode:
		return
	var snapshot_value: Variant = data.get("snapshot", {})
	if typeof(snapshot_value) == TYPE_DICTIONARY:
		_apply_snapshot(snapshot_value as Dictionary)

func _on_demo_reset(data: Dictionary) -> void:
	if _use_mock_mode:
		return
	var snapshot_value: Variant = data.get("snapshot", {})
	if typeof(snapshot_value) == TYPE_DICTIONARY:
		_apply_snapshot(snapshot_value as Dictionary)

func _on_step_completed(data: Dictionary) -> void:
	if _use_mock_mode:
		return
	var snapshot_value: Variant = data.get("snapshot", {})
	if typeof(snapshot_value) == TYPE_DICTIONARY:
		_apply_snapshot(snapshot_value as Dictionary)

func _on_api_error(endpoint: String, message: String) -> void:
	error_label.text = "%s: %s" % [endpoint, message]
	if not _use_mock_mode:
		_use_mock_mode = true
		mock_mode_toggle.button_pressed = true
		_apply_snapshot(_mock_provider.get_snapshot())

func _update_labels(data: Dictionary) -> void:
	var patient: Dictionary = _extract_patient(data)
	current_location_label.text = "location: %s" % str(patient.get("location", "UNKNOWN"))
	current_state_label.text = "state: %s" % str(patient.get("state", "UNKNOWN"))
	backend_status_label.text = "backend_status: %s" % str(data.get("backend_status", "UNKNOWN"))

func _apply_snapshot(snapshot: Dictionary) -> void:
	_update_labels(snapshot)
	patient_manager.apply_snapshot(snapshot)
	var patient: Dictionary = _extract_patient(snapshot)
	_set_active_patient(patient)
	_switch_map_with_fade(str(patient.get("location", "ED_ENTRANCE")))


func _switch_map_with_fade(location_name: String) -> void:
	if hospital_map_manager == null or not hospital_map_manager.has_method("show_map_for_location"):
		return
	var old_map: String = ""
	if hospital_map_manager.has_method("get_current_map_id"):
		old_map = hospital_map_manager.get_current_map_id()
	var new_map: String = hospital_map_manager.get_map_id_for_location(location_name)
	if old_map == new_map:
		# Same map, no fade needed
		hospital_map_manager.show_map_for_location(location_name)
		return

	# Cross-map: fade out → switch → fade in
	fade_overlay.modulate = Color(0, 0, 0, 0)
	var t := create_tween()
	t.tween_property(fade_overlay, "modulate", Color(0, 0, 0, 1), 0.2)
	t.tween_callback(func():
		hospital_map_manager.show_map_for_location(location_name)
	)
	t.tween_property(fade_overlay, "modulate", Color(0, 0, 0, 0), 0.2)

func _set_active_patient(patient: Dictionary) -> void:
	var patient_id: String = str(patient.get("patient_id", ""))
	if patient_id == "":
		_active_patient_id = ""
		_active_profile = {}
		_dialogue_lines = []
		_dialogue_index = -1
		_dialogue_started = false
		_refresh_dialogue_panel()
		return
	if patient_id != _active_patient_id:
		_active_patient_id = patient_id
		_load_active_profile(patient_id)
	_refresh_dialogue_panel()

func _load_active_profile(patient_id: String) -> void:
	var profile_value: Variant = _agent_profiles.get_profile(patient_id)
	if typeof(profile_value) == TYPE_DICTIONARY:
		_active_profile = profile_value as Dictionary
	else:
		_active_profile = {}
	var lines_value: Variant = _active_profile.get("dialogue_lines", [])
	_dialogue_lines = []
	if typeof(lines_value) == TYPE_ARRAY:
		_dialogue_lines = lines_value as Array
	_dialogue_index = -1
	_dialogue_started = false

func _refresh_dialogue_panel() -> void:
	var has_active_patient: bool = _active_patient_id != ""
	talk_button.disabled = not has_active_patient
	next_dialogue_button.disabled = not has_active_patient or not _dialogue_started
	if not has_active_patient:
		speaker_label.text = "No active patient."
		dialogue_text_label.text = "No active patient."
		return

	var display_name: String = str(_active_profile.get("display_name", _active_patient_id))
	var triage_level: String = str(_active_profile.get("triage_level", "UNKNOWN"))
	var chief_complaint: String = str(_active_profile.get("chief_complaint", ""))
	speaker_label.text = "%s (%s)" % [display_name, triage_level]

	if not _dialogue_started:
		dialogue_text_label.text = "Press Talk to begin mock dialogue.\nChief complaint: %s" % chief_complaint
		return

	if _dialogue_index >= 0 and _dialogue_index < _dialogue_lines.size():
		dialogue_text_label.text = str(_dialogue_lines[_dialogue_index])
	else:
		dialogue_text_label.text = "End of mock dialogue."
		next_dialogue_button.disabled = true

func _on_talk_pressed() -> void:
	if _active_patient_id == "":
		_refresh_dialogue_panel()
		return
	_dialogue_started = true
	_dialogue_index = 0
	_refresh_dialogue_panel()

func _on_next_dialogue_pressed() -> void:
	if _active_patient_id == "":
		_refresh_dialogue_panel()
		return
	if not _dialogue_started:
		_on_talk_pressed()
		return
	if _dialogue_index < _dialogue_lines.size() - 1:
		_dialogue_index += 1
	else:
		_dialogue_index = _dialogue_lines.size()
	_refresh_dialogue_panel()

func _extract_patient(data: Dictionary) -> Dictionary:
	var payload_value: Variant = data.get("data", data)
	var payload: Dictionary = data
	if typeof(payload_value) == TYPE_DICTIONARY:
		payload = payload_value as Dictionary
	if payload.has("patient"):
		var nested_value: Variant = payload.get("patient", {})
		if typeof(nested_value) == TYPE_DICTIONARY:
			return nested_value as Dictionary
	var patients_value: Variant = payload.get("patients", {})
	var patients: Variant = patients_value
	if typeof(patients) == TYPE_ARRAY and patients.size() > 0:
		var patient_value: Variant = patients[0]
		if typeof(patient_value) == TYPE_DICTIONARY:
			return patient_value as Dictionary
	if typeof(patients) == TYPE_DICTIONARY:
		return patients as Dictionary
	if payload.has("patient_id"):
		return payload
	return {}
