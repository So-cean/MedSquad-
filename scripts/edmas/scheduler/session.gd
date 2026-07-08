class_name Session
extends RefCounted

signal activated(session)
signal ended(session, result: Dictionary)

enum State { PENDING, WAITING_FOR_RESOURCES, ACTIVE, ENDED }

const CHARS_PER_SEC: float = 10.0
const COMPACT_MAX_CHARS: int = 26
const COMPACT_MIN_TIME: float = 2.2
const SAFETY_TIMEOUT: float = 15.0

var participants: Dictionary = {}
var required_resources: Array = []
var goal: String = ""
var state: int = State.PENDING
var result: Dictionary = {}

var _resource_ids: Array[String] = []
var _response_queue: Array = []
var _displaying: bool = false
var _turn_id: int = 0
var _ended: bool = false
var _session_id: String = ""


func _init(p_participants: Dictionary = {}, p_required_resources: Array = [], p_goal: String = "") -> void:
	participants = p_participants
	required_resources = p_required_resources
	goal = p_goal
	_session_id = "session_%d" % Time.get_ticks_usec()
	print("[Session] class registered %s goal=%s" % [_session_id, goal])


func get_patient_id() -> String:
	var patient: BaseNpc = participants.get("patient", null) as BaseNpc
	return NpcManager.get_npc_id(patient) if patient else _session_id


func try_activate() -> bool:
	var patient_id: String = get_patient_id()
	var waiting: bool = false
	_resource_ids.clear()
	for res in required_resources:
		if res == null:
			continue
		var reply: Dictionary = res.request(patient_id)
		_resource_ids.append(res.id)
		if not reply.get("granted", false):
			waiting = true
			print("[Session] %s queued for %s (position=%d)" % [patient_id, res.id, int(reply.get("position", -1)) + 1])
	if waiting:
		state = State.WAITING_FOR_RESOURCES
		return false
	state = State.ACTIVE
	return true


func activate() -> void:
	if _ended:
		return
	state = State.ACTIVE
	_connect_fsm()
	activated.emit(self)
	_start_safety_timer()
	_start()


func _start() -> void:
	pass


func end(p_result: Dictionary = {}) -> void:
	if _ended:
		return
	_ended = true
	result = p_result
	state = State.ENDED
	_clear_participant_speech()
	_disconnect_fsm()
	_release_resources()
	ended.emit(self, result)


func _connect_fsm() -> void:
	var fsm: Node = NpcManager.get_fsm()
	if fsm and not fsm.action_ready.is_connected(_on_action_ready):
		fsm.action_ready.connect(_on_action_ready)


func _disconnect_fsm() -> void:
	var fsm: Node = NpcManager.get_fsm()
	if fsm and fsm.action_ready.is_connected(_on_action_ready):
		fsm.action_ready.disconnect(_on_action_ready)


func _release_resources() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return
	var reg: Node = tree.root.get_node_or_null("/root/ResourceRegistry")
	if not reg:
		return
	for res_id in _resource_ids:
		var res = reg.get_resource(res_id)
		if res:
			res.release()
	_resource_ids.clear()


func _on_action_ready(npc_id: String, action: Dictionary) -> void:
	if _ended or not _owns_npc(npc_id):
		return
	_response_queue.append({"npc_id": npc_id, "action": action})
	_try_process_queue()


func _owns_npc(npc_id: String) -> bool:
	for npc in participants.values():
		if NpcManager.get_npc_id(npc) == npc_id:
			return true
	return false


func _try_process_queue() -> void:
	if _displaying or _response_queue.is_empty() or _ended:
		return
	var item: Dictionary = _response_queue.pop_front()
	var npc_id: String = item["npc_id"]
	var action: Dictionary = item["action"]
	_turn_id += 1
	_displaying = true
	_handle_action(npc_id, action)
	_wait_display(npc_id, action)


func _handle_action(_npc_id: String, _action: Dictionary) -> void:
	pass


func _display(npc_id: String, action: Dictionary) -> void:
	var npc: BaseNpc = NpcManager.get_npc(npc_id)
	if not npc:
		return
	_clear_participant_speech(npc)
	var think: String = action.get("think", "")
	var utterances: Array = _collect_utterances(action)
	if utterances.is_empty():
		utterances = ["..."]
	npc.speak(DialogueEntry.new(npc.get_npc_name(), think, "", "", utterances))


func _clear_participant_speech(except_npc: BaseNpc = null) -> void:
	for participant in participants.values():
		var npc: BaseNpc = participant as BaseNpc
		if not npc or npc == except_npc:
			continue
		npc.stop_speaking()


func _collect_utterances(action: Dictionary) -> Array:
	var result: Array = []
	for resp in action.get("responses", []):
		for utt in resp.get("utterances", []):
			result.append(str(utt))
	for utt in action.get("utterances", []):
		result.append(str(utt))
	if result.is_empty() and not str(action.get("dialogue", "")).is_empty():
		result.append(str(action.get("dialogue", "")))
	return result


func _wait_display(npc_id: String, action: Dictionary) -> void:
	var my_turn: int = _turn_id
	var utterances: Array = _collect_utterances(action)
	var compact_text: String = _compact_display_text(utterances)
	var display_time: float = maxf(float(compact_text.length()) / CHARS_PER_SEC, COMPACT_MIN_TIME)
	await NpcManager.get_tree().create_timer(display_time).timeout
	if _ended or my_turn != _turn_id:
		return
	_displaying = false
	_after_display(npc_id, action)
	if not _response_queue.is_empty():
		_try_process_queue()


func _compact_display_text(utterances: Array) -> String:
	var full_text: String = ""
	for utt in utterances:
		var text: String = str(utt).strip_edges()
		if text.is_empty():
			continue
		full_text += (" " if not full_text.is_empty() else "") + text
	if full_text.is_empty():
		full_text = "..."
	if full_text.length() > COMPACT_MAX_CHARS:
		return full_text.left(COMPACT_MAX_CHARS).strip_edges() + " ..."
	return full_text


func _after_display(_npc_id: String, _action: Dictionary) -> void:
	pass


func _start_safety_timer() -> void:
	var start_turn: int = _turn_id
	await NpcManager.get_tree().create_timer(SAFETY_TIMEOUT).timeout
	if _ended:
		return
	if start_turn == _turn_id and _response_queue.is_empty() and not _displaying:
		push_warning("[Session] safety timeout, force ending %s" % _session_id)
		end({"next_step": {"next_role": "discharge", "target_room": "DISCHARGE", "reason": "session timeout", "orders": []}})


func _wait_for_arrival(npc: BaseNpc, timeout: float) -> void:
	var elapsed: float = 0.0
	while is_instance_valid(npc) and npc.is_walking() and elapsed < timeout:
		await NpcManager.get_tree().process_frame
		elapsed += NpcManager.get_process_delta_time()
	if is_instance_valid(npc) and npc.is_walking():
		npc._is_walking = false
