class_name Session
extends RefCounted

signal activated(session)
signal ended(session, result: Dictionary)

enum State { PENDING, WAITING_FOR_RESOURCES, ACTIVE, ENDED }

const CHARS_PER_SEC: float = 10.0
const COMPACT_MAX_CHARS: int = 26
const COMPACT_MIN_TIME: float = 2.2
const SAFETY_TIMEOUT: float = 30.0  # wall-clock seconds since activation
const MAX_TURNS: int = 8  # hard cap: 4 professional + 4 patient

var participants: Dictionary = {}
var required_resources: Array = []
var required_role: String = ""  # role of the required_resources (for rebind)
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
	# Derive required_role from the first required resource (for rebind logic)
	if not required_resources.is_empty():
		var first_res = required_resources[0]
		if first_res is MedicalResource:
			required_role = (first_res as MedicalResource).role
	_session_id = "session_%d" % Time.get_ticks_usec()
	print("[Session] class registered %s goal=%s" % [_session_id, goal])


func get_patient_id() -> String:
	var patient: BaseNpc = participants.get("patient", null) as BaseNpc
	return NpcManager.get_npc_id(patient) if patient else _session_id


func try_activate() -> bool:
	var patient_id: String = get_patient_id()
	var waiting: bool = false
	_resource_ids.clear()
	for i in range(required_resources.size()):
		var res = required_resources[i]
		if res == null:
			continue
		# Rebind: if the originally-bound resource is busy/queued AND another
		# same-role resource is idle, swap to the idle one so patients distribute
		# across multiple staff of the same role instead of all queueing on one.
		if not required_role.is_empty() and res.is_busy():
			var reg: Node = Engine.get_main_loop().root.get_node_or_null("/root/ResourceRegistry")
			if reg and reg.has_method("find_idle_by_role"):
				var idle_res = reg.find_idle_by_role(required_role)
				if idle_res and idle_res != res:
					# Cancel any prior queue position on the old resource
					if res.has_method("cancel"):
						res.cancel(patient_id)
					res = idle_res
					required_resources[i] = res
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
		if resp is Dictionary:
			for utt in (resp as Dictionary).get("utterances", []):
				var s: String = str(utt).strip_edges()
				if not s.is_empty():
					result.append(s)
	for utt in action.get("utterances", []):
		var s2: String = str(utt).strip_edges()
		if not s2.is_empty():
			result.append(s2)
	if result.is_empty() and not str(action.get("dialogue", "")).strip_edges().is_empty():
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
	# Wall-clock timer: fires SAFETY_TIMEOUT seconds after activation, regardless
	# of how many LLM turns happened. Previous version compared _turn_id which
	# reset every turn and never fired during active conversation.
	var start_msec: float = float(Time.get_ticks_msec())
	await NpcManager.get_tree().create_timer(SAFETY_TIMEOUT).timeout
	if _ended:
		return
	var elapsed: float = (float(Time.get_ticks_msec()) - start_msec) / 1000.0
	if elapsed >= SAFETY_TIMEOUT:
		push_warning("[Session] safety timeout (%.1fs), force ending %s" % [elapsed, _session_id])
		end({"next_step": {"next_role": "discharge", "target_room": "DISCHARGE", "reason": "session timeout", "orders": []}})


func _wait_for_arrival(npc: BaseNpc, timeout: float) -> void:
	var start_msec: float = float(Time.get_ticks_msec())
	while is_instance_valid(npc) and npc.is_walking():
		var elapsed_sec: float = (float(Time.get_ticks_msec()) - start_msec) / 1000.0
		if elapsed_sec >= timeout:
			break
		await NpcManager.get_tree().process_frame
	if is_instance_valid(npc) and npc.is_walking():
		npc._is_walking = false
