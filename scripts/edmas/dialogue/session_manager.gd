extends Node
class_name SessionManager

const SESSION_PANEL_NAME := "InteractionSessionPanel"
const PLAYER_INTERVENTION_RADIUS := 120.0

@export var auto_start_demo: bool = true
@export var patient_case_id: String = "case_chest_pain"

var _factory: PatientFactory = PatientFactory.new()
var _active_session: InteractionSession = null
var _patient_node: Node2D = null
var _nurse_node: Node2D = null
var _doctor_node: Node2D = null
var _player_node: Node2D = null
var _panel: PanelContainer = null
var _panel_label: Label = null
var _result_label: Label = null
var _choice_row: HBoxContainer = null
var _buttons: Dictionary = {}
var _llm_case_data: Dictionary = {}

func _ready() -> void:
	_player_node = _find_node("Player")
	_nurse_node = _find_node("Nurse")
	_doctor_node = _find_node("ScrubsGreen")
	_build_panel()
	if auto_start_demo:
		call_deferred("_start_demo_session")

func _process(_delta: float) -> void:
	if _active_session == null:
		if _panel != null:
			_panel.visible = false
		return
	var near: bool = _is_player_near_session()
	_active_session.player_can_intervene = near and not _active_session.is_completed() and not _active_session.is_failed()
	if _panel != null:
		_panel.visible = _active_session.player_can_intervene or _active_session.current_phase == InteractionSession.SessionPhase.COMPLETED
	_update_panel()

func _start_demo_session() -> void:
	if _active_session != null:
		return
	_llm_case_data = await _fetch_llm_case_if_configured()
	_patient_node = _factory.spawn_patient(get_parent(), patient_case_id)
	if _patient_node == null:
		return
	_patient_node.position = Vector2(760.0, 790.0)
	if _patient_node.has_method("set_wander_enabled"):
		_patient_node.call("set_wander_enabled", false)
	_patient_node.set_meta("state", "ARRIVED")
	_patient_node.set_meta("location", "ED_ENTRANCE")
	_active_session = InteractionSession.new()
	_active_session.start("session_%d" % Time.get_ticks_msec(), {
		"patient": _patient_node,
		"nurse": _nurse_node,
		"doctor": _doctor_node,
	})
	_run_demo_flow()

func _run_demo_flow() -> void:
	if _active_session == null:
		return
	if _patient_node != null:
		_patient_node.set_meta("state", "TRIAGE")
		_patient_node.set_meta("location", "TRIAGE")
		_move_patient_to_triage()
	_say(_nurse_node, "您好，我是分诊护士。请先到分诊台，我会快速确认您的主诉。", "分诊护士先建立接触，准备采集主诉。")
	await get_tree().create_timer(1.0).timeout
	if _active_session == null:
		return
	_say(_patient_node, str(_get_case_value("patient_reply", "我有点不舒服。")), str(_get_case_value("chief_complaint", "")))
	await get_tree().create_timer(1.0).timeout
	if _active_session == null:
		return
	_say(_nurse_node, str(_get_case_value("triage_question", "请再说一下主要症状。")), "继续追问发病时间、诱因和危险信号。")
	await get_tree().create_timer(1.0).timeout
	if _active_session == null:
		return
	_say(_patient_node, str(_get_case_value("patient_detail", "症状还在持续，我有些担心。")), "患者补充症状变化和伴随表现。")
	await get_tree().create_timer(1.0).timeout
	if _active_session == null:
		return
	_say(_nurse_node, str(_get_case_value("vitals_line", "我先记录生命体征，并安排医生进一步评估。")), "分诊护士记录生命体征并判断优先级。")
	await get_tree().create_timer(1.0).timeout
	if _active_session == null:
		return
	var decision: String = str(_get_case_value("nurse_decision", "send_to_doctor"))
	if decision == "send_to_resus":
		_say(_nurse_node, "情况比较急，我会直接通知抢救区，请跟我过去。", "优先级提升，准备进入急救链路。")
		_active_session.complete(str(_get_case_value("local_result", "已进入急救链路。")))
	else:
		_say(_nurse_node, "我会把您的情况转给医生，请先在分诊台旁等待。", "转交医生进一步评估。")
		await get_tree().create_timer(0.8).timeout
		if _active_session == null:
			return
		_say(_doctor_node, str(_get_case_value("doctor_handoff", "我来接手，先进一步评估。")), "医生接手病人。")
		_active_session.complete(str(_get_case_value("local_result", "已转交医生进一步判断。")))
	_update_panel()

func _move_patient_to_triage() -> void:
	if _patient_node == null:
		return
	var path: Array[Vector2] = [
		Vector2(760.0, 790.0),
		Vector2(760.0, 690.0),
		Vector2(710.0, 620.0),
		Vector2(640.0, 540.0),
		Vector2(610.0, 390.0),
	]
	if _patient_node.has_method("move_along_path"):
		_patient_node.call("move_along_path", path)
	else:
		_patient_node.position = path[path.size() - 1]

func _say(node: Node2D, dialogue: String, think: String) -> void:
	if node == null or not is_instance_valid(node):
		return
	var entry: DialogueEntry = DialogueEntry.new(str(node.name), think, dialogue, "")
	if node.has_method("speak"):
		node.call("speak", entry)
	if node.has_method("record_dialogue"):
		node.call("record_dialogue", "session", think, dialogue, 5)
	if _active_session != null:
		_active_session.add_line(str(node.name), dialogue)

func _build_panel() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = SESSION_PANEL_NAME
	canvas.layer = 110
	add_child(canvas)

	_panel = PanelContainer.new()
	_panel.name = "SessionPanel"
	_panel.position = Vector2(24.0, 24.0)
	_panel.custom_minimum_size = Vector2(280.0, 180.0)
	canvas.add_child(_panel)

	var root: VBoxContainer = VBoxContainer.new()
	_panel.add_child(root)

	_panel_label = Label.new()
	_panel_label.text = "Session: idle"
	root.add_child(_panel_label)

	_result_label = Label.new()
	_result_label.text = "result: -"
	root.add_child(_result_label)

	_choice_row = HBoxContainer.new()
	root.add_child(_choice_row)

	_buttons = {}
	_create_button("patient", "Patient")
	_create_button("nurse", "Nurse")
	_create_button("doctor", "Doctor")
	_create_button("advance", "Advance")
	_panel.visible = false

func _create_button(role_key: String, label_text: String) -> void:
	var button: Button = Button.new()
	button.text = label_text
	button.pressed.connect(func(): _on_choice_pressed(role_key))
	_choice_row.add_child(button)
	_buttons[role_key] = button

func _on_choice_pressed(role_key: String) -> void:
	if _active_session == null:
		return
	_active_session.set_player_intervention(role_key)
	if role_key == "patient":
		_say(_patient_node, "我补充一下：症状没有完全缓解，活动后会更明显。", "玩家扮演病人补充症状。")
	elif role_key == "nurse":
		_say(_nurse_node, "我再核对一次生命体征和过敏史，然后更新分诊等级。", "玩家扮演护士确认信息。")
	elif role_key == "doctor":
		_say(_doctor_node, "我接手后会先做重点查体，再决定检查或治疗路径。", "玩家扮演医生接手。")
	elif role_key == "advance":
		_active_session.complete("玩家推进会话：完成本地分诊演示。")
	_update_panel()

func _update_panel() -> void:
	if _panel == null or _active_session == null:
		return
	var phase_name: String = _phase_name(_active_session.current_phase)
	_panel_label.text = "session: %s | phase: %s" % [_active_session.session_id, phase_name]
	_result_label.text = "result: %s" % _active_session.local_result
	var can_intervene: bool = _active_session.player_can_intervene
	for button_value: Variant in _buttons.values():
		var button: Button = button_value as Button
		if button != null:
			button.disabled = not can_intervene

func _phase_name(phase: InteractionSession.SessionPhase) -> String:
	match phase:
		InteractionSession.SessionPhase.CREATED:
			return "CREATED"
		InteractionSession.SessionPhase.ACTIVE:
			return "ACTIVE"
		InteractionSession.SessionPhase.WAITING_RESPONSE:
			return "WAITING_RESPONSE"
		InteractionSession.SessionPhase.PLAYER_INTERVENTION:
			return "PLAYER_INTERVENTION"
		InteractionSession.SessionPhase.COMPLETED:
			return "COMPLETED"
		InteractionSession.SessionPhase.FAILED:
			return "FAILED"
	return "UNKNOWN"

func _find_node(node_name: String) -> Node2D:
	var root: Node = get_parent()
	if root == null:
		return null
	return root.get_node_or_null(node_name) as Node2D

func _is_player_near_session() -> bool:
	if _player_node == null or _patient_node == null:
		return false
	return _player_node.global_position.distance_to(_patient_node.global_position) <= PLAYER_INTERVENTION_RADIUS

func _get_case_value(key: String, default_value: String) -> String:
	if _llm_case_data.has(key):
		return str(_llm_case_data.get(key, default_value))
	var case_data: Dictionary = PatientCasePool.get_case(patient_case_id)
	if case_data.is_empty():
		case_data = PatientCasePool.get_case(PatientCasePool.get_default_case_id())
	return str(case_data.get(key, default_value))

func _fetch_llm_case_if_configured() -> Dictionary:
	var api_url: String = OS.get_environment("EDMAS_LLM_API_URL")
	var api_key: String = OS.get_environment("EDMAS_LLM_API_KEY")
	if api_url.is_empty() or api_key.is_empty():
		return {}
	var model: String = OS.get_environment("EDMAS_LLM_MODEL")
	if model.is_empty():
		model = "gpt-4o-mini"
	var http := HTTPRequest.new()
	add_child(http)
	var prompt := "生成一个急诊分诊模拟患者病例。只输出 JSON，不要 Markdown。字段必须包含：chief_complaint, patient_reply, patient_detail, triage_question, vitals_line, nurse_decision, doctor_handoff, local_result。nurse_decision 只能是 send_to_doctor 或 send_to_resus。中文，适合医学教学 Demo，不要给真实医疗建议。"
	var body := {
		"model": model,
		"messages": [
			{"role": "system", "content": "你是急诊教学模拟系统的病例生成器。"},
			{"role": "user", "content": prompt},
		],
		"temperature": 0.7,
	}
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key,
	])
	var error: Error = http.request(api_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		push_warning("SessionManager: LLM case request failed to start: %s" % error)
		http.queue_free()
		return {}
	var response: Array = await http.request_completed
	http.queue_free()
	var response_code: int = int(response[1])
	if response_code < 200 or response_code >= 300:
		push_warning("SessionManager: LLM case request failed with HTTP %d" % response_code)
		return {}
	var bytes: PackedByteArray = response[3] as PackedByteArray
	return _parse_llm_case_response(bytes.get_string_from_utf8())

func _parse_llm_case_response(response_text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(response_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = parsed as Dictionary
	var content := ""
	var choices_value: Variant = payload.get("choices", [])
	if typeof(choices_value) == TYPE_ARRAY and not (choices_value as Array).is_empty():
		var first_choice: Variant = (choices_value as Array)[0]
		if typeof(first_choice) == TYPE_DICTIONARY:
			var message_value: Variant = (first_choice as Dictionary).get("message", {})
			if typeof(message_value) == TYPE_DICTIONARY:
				content = str((message_value as Dictionary).get("content", ""))
	if content.is_empty():
		return {}
	content = content.strip_edges()
	content = content.replace("```json", "").replace("```", "").strip_edges()
	var case_value: Variant = JSON.parse_string(content)
	if typeof(case_value) != TYPE_DICTIONARY:
		push_warning("SessionManager: LLM response was not a case JSON object")
		return {}
	var case_data: Dictionary = case_value as Dictionary
	for required_key: String in ["chief_complaint", "patient_reply", "triage_question", "nurse_decision", "local_result"]:
		if not case_data.has(required_key):
			push_warning("SessionManager: LLM case missing key %s" % required_key)
			return {}
	return case_data
