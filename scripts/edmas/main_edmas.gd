extends Control

const _DemoProvider = preload("res://scripts/edmas/mock/mock_demo_provider.gd")
const _AgentProfiles = preload("res://scripts/edmas/mock/mock_agent_profiles.gd")
const FLOOR_SCENES := {
	"MAP_ED_CORE": "res://scens/edmas/Floor_ED_Core.tscn",
	"MAP_DIAGNOSTICS": "res://scens/edmas/Floor_Diagnostics.tscn",
	"MAP_DOWNSTREAM": "res://scens/edmas/Floor_Downstream.tscn",
}

@onready var api_client: Node = $APIClient
@onready var map_root: Node2D = $MapRoot
@onready var floor_container: Node2D = $MapRoot/FloorContainer
@onready var fade_overlay: ColorRect = $CanvasLayer/FadeOverlay
@onready var elevator_zone: Area2D = $MapRoot/ElevatorZone
@onready var elevator_hint: Label = $CanvasLayer/UI/ElevatorHint
@onready var npc_hint: Label = $CanvasLayer/UI/NPCInteractionHint
var _nearby_npc = null
var _current_floor: String = ""
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

const MAP_ORDER: Array[String] = ["MAP_ED_CORE", "MAP_DIAGNOSTICS", "MAP_DOWNSTREAM"]

func _ready() -> void:
	print("[EDMAS] Main_EDMAS scene loaded")
	backend_status_label.text = "ED-MAS Main Scene Loaded"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_floor("MAP_ED_CORE")
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

func _process(_delta: float) -> void:
	# Elevator interaction
	if elevator_zone and elevator_zone.is_player_inside():
		var idx = MAP_ORDER.find(_current_floor)
		elevator_hint.text = ""
		if idx > 0:
			elevator_hint.text += "按 Q 下楼  "
		if idx < MAP_ORDER.size() - 1:
			elevator_hint.text += "按 E 上楼"
		elevator_hint.visible = elevator_hint.text != ""
	else:
		elevator_hint.visible = false

	# NPC interaction - scan all NPC interaction zones
	_nearby_npc = null
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		var zone_node = npc.get_node_or_null("InteractionZone")
		if zone_node and zone_node.has_method("is_player_inside") and zone_node.is_player_inside():
			_nearby_npc = npc
			break
	npc_hint.visible = _nearby_npc != null


func _unhandled_input(event: InputEvent) -> void:
	# Elevator interaction (E/Q keys)
	if elevator_zone and elevator_zone.is_player_inside():
		if event.is_action_pressed("elevator_up") or (event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo):
			get_viewport().set_input_as_handled()
			_elevator_go(1)
			return
		elif event.is_action_pressed("elevator_down") or (event is InputEventKey and event.keycode == KEY_Q and event.pressed and not event.echo):
			get_viewport().set_input_as_handled()
			_elevator_go(-1)
			return

	# NPC interaction (E key when near an NPC)
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		if _nearby_npc:
			get_viewport().set_input_as_handled()
			_talk_to_npc(_nearby_npc)


func _talk_to_npc(npc) -> void:
	var npc_name = npc.get_npc_name()
	var knowledge = NPCDataLoader.get_knowledge(npc_name)
	var response = "我是%s。" % [npc_name]
	if knowledge.size() > 0:
		var topic = knowledge[randi() % knowledge.size()]
		var condition = topic.get("condition", "")
		var action = topic.get("action", "")
		if condition != "":
			response = "我是%s。%s的患者，建议%s。" % [npc_name, condition, action]
	var entry := DialogueEntry.new(npc_name, "与玩家对话", response)
	npc.speak(entry)
	print("[NPC] 玩家与 %s 对话" % npc_name)


func _elevator_go(dir: int) -> void:
	var idx = MAP_ORDER.find(_current_floor)
	var new_idx = idx + dir
	if new_idx < 0 or new_idx >= MAP_ORDER.size():
		return
	_load_floor(MAP_ORDER[new_idx])

func _load_floor(map_id: String) -> void:
	if map_id == _current_floor:
		return
	# Clear current floor immediately
	for child in floor_container.get_children():
		child.free()
	# Load new floor
	var path = FLOOR_SCENES.get(map_id, "")
	if path == "":
		return
	var scn = load(path)
	if not scn:
		return
	var instance = scn.instantiate()
	floor_container.add_child(instance)
	_current_floor = map_id
	print("[EDMAS] Loaded floor: ", map_id)


func _fit_map_to_viewport() -> void:
	if map_root == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var scale_factor: float = min(viewport_size.x / 1672.0, viewport_size.y / 941.0)
	map_root.scale = Vector2(scale_factor, scale_factor)
	map_root.position = Vector2(
		(viewport_size.x - 1672.0 * scale_factor) / 2.0,
		(viewport_size.y - 941.0 * scale_factor) / 2.0
	)


func _get_map_id_for_location(location_name: String) -> String:
	var config = load("res://scripts/edmas/config.gd")
	if config and config.LOCATION_TO_MAP.has(location_name):
		return config.LOCATION_TO_MAP[location_name]
	return "MAP_ED_CORE"

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
	var patient: Dictionary = _extract_patient(snapshot)
	_set_active_patient(patient)
	_switch_map_with_fade(str(patient.get("location", "ED_ENTRANCE")))


func _switch_map_with_fade(location_name: String) -> void:
	var new_map: String = _get_map_id_for_location(location_name)
	if new_map == _current_floor:
		return

	fade_overlay.modulate = Color(0, 0, 0, 0)
	var t := create_tween()
	t.tween_property(fade_overlay, "modulate", Color(0, 0, 0, 1), 0.2)
	t.tween_callback(func():
		_load_floor(new_map)
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
