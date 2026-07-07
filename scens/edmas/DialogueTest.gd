extends Node2D

## 分诊对话测试 — 管道模式
##
## LLM调用：管道预取（显示期间发下一个请求）
## 气泡显示：严格串行（等一个人说完再显示下一个）
## 对话结束：自动清除气泡 + 切换患者

var _fsm: Node = null
var _ctx: ConversationContext = null

var _response_queue: Array = []
var _displaying: bool = false
var _turn_id: int = 0
var _current_patient: String = ""

const SAFETY_TIMEOUT: float = 15.0
const TYPEWRITER_INTERVAL: float = 0.04
const THINK_PAUSE: float = 0.5
const FADE_DURATION: float = 0.25
const CHARS_PER_SEC: float = 10.0
const MIN_UTT_TIME: float = 1.5


func _ready() -> void:
	await get_tree().create_timer(1.5).timeout

	_fsm = load("res://scripts/edmas/npc_fsm.gd").new()
	add_child(_fsm)
	_fsm.action_ready.connect(_on_action_ready)

	_ctx = ConversationContext.new(_fsm)
	_ctx.response_received.connect(_on_response_routed)
	_ctx.conversation_done.connect(_on_conversation_done)

	await get_tree().process_frame
	await get_tree().process_frame

	var nurse_npc: BaseNpc = NpcManager.get_npc("nurse_001")
	var p1: BaseNpc = NpcManager.get_npc("patient_001")
	var p2: BaseNpc = NpcManager.get_npc("patient_002")
	if not nurse_npc or not p1 or not p2:
		push_error("Need nurse + 2 patients"); return

	_ctx.register("nurse_001", nurse_npc, "nurse", [
		{"condition": "头痛", "triage": "3级-急症"},
		{"condition": "发热38.5℃", "triage": "3级-急症"},
		{"condition": "腹痛", "triage": "2级-危重"},
		{"condition": "胸痛", "triage": "1级-即刻"},
	])
	_ctx.register("patient_001", p1, "patient", [
		{"主诉": "头痛", "症状": "前额胀痛,恶心畏光", "持续时间": "三天"},
	])
	_ctx.register("patient_002", p2, "patient", [
		{"主诉": "腹痛", "症状": "右下腹按压痛,低热", "持续时间": "半天"},
	])

	print("[Test] 分诊对话开始（管道模式）")
	_start_pipeline()


func _start_pipeline() -> void:
	_current_patient = _ctx.get_next_undone_patient()
	if _current_patient.is_empty():
		_all_done()
		return
	_ctx.set_active_patient(_current_patient)
	print("\n[Test] === 开始处理 %s ===" % _current_patient)
	_fire_next(_current_patient)
	_start_safety_timer()


func _fire_next(npc_id: String) -> void:
	_turn_id += 1
	print("[Test] [%s] 调LLM..." % npc_id)
	_ctx.tick(npc_id)


func _on_action_ready(npc_id: String, action: Dictionary) -> void:
	_response_queue.append({"npc_id": npc_id, "action": action})
	_try_process_queue()


func _try_process_queue() -> void:
	if _displaying or _response_queue.is_empty():
		return

	var item: Dictionary = _response_queue.pop_front()
	var npc_id: String = item["npc_id"]
	var action: Dictionary = item["action"]

	var think: String = action.get("think", "")
	var responses: Array = action.get("responses", [])
	var utts: Array = action.get("utterances", [])

	print("[Test]  [%s] think=%s" % [npc_id, think])
	if responses.size() > 0:
		for r in responses:
			var t: String = r.get("target", "?")
			var ru: Array = r.get("utterances", [])
			var done: bool = r.get("conversation_done", false)
			print("[Test]    → %s: %s (done=%s)" % [t, str(ru), done])
	else:
		print("[Test]    utterances: %s" % str(utts))

	_ctx.on_response(npc_id, action)
	_display(npc_id, action)

	# ★ 管道核心：立即发下一个LLM调用（不等显示完）
	var next_npc: String = _get_next_speaker(npc_id, action)
	if not next_npc.is_empty():
		_fire_next(next_npc)

	# ★ 显示串行：等当前bubble播完才处理下一个
	_displaying = true
	_wait_for_display(npc_id, action)


func _wait_for_display(npc_id: String, action: Dictionary) -> void:
	var my_turn: int = _turn_id

	# 估算实际显示时间（think打字机 + pause + fade + utterances）
	var think: String = action.get("think", "")
	var utts: Array = action.get("utterances", [])
	var responses: Array = action.get("responses", [])

	# 护士可能有多个response的utterances
	var all_utts: Array = utts
	if responses.size() > 0:
		all_utts = []
		for r in responses:
			var ru: Array = r.get("utterances", [])
			for u in ru:
				all_utts.append(u)

	# think时间：打字机 + pause + fade
	var think_time: float = 0.0
	if not think.is_empty():
		think_time = think.length() * TYPEWRITER_INTERVAL + THINK_PAUSE + FADE_DURATION

	# utterance时间：每条按字符数算
	var utt_time: float = 0.0
	for u in all_utts:
		utt_time += maxf(float(str(u).length()) / CHARS_PER_SEC, MIN_UTT_TIME)

	var est_time: float = think_time + utt_time
	print("[Test]    显示预计 %.1fs (think=%.1fs utt=%.1fs)" % [est_time, think_time, utt_time])

	await get_tree().create_timer(est_time).timeout

	if my_turn != _turn_id:
		return  # 被超时重置了

	_displaying = false

	# 检查是否有response在显示期间到达
	if not _response_queue.is_empty():
		_try_process_queue()
	elif _ctx.all_conversations_done():
		_all_done()


func _get_next_speaker(current_npc: String, action: Dictionary) -> String:
	if current_npc == "nurse_001":
		var responses: Array = action.get("responses", [])
		var conv_done: bool = false
		for r in responses:
			if r.get("conversation_done", false):
				conv_done = true
				break

		if conv_done:
			# 当前患者done，清除ta的bubble
			var done_npc: BaseNpc = NpcManager.get_npc(_current_patient)
			if done_npc:
				done_npc.stop_speaking()
			# 切下一个患者
			_current_patient = _ctx.get_next_undone_patient()
			if _current_patient.is_empty():
				return ""
			_ctx.set_active_patient(_current_patient)
			print("\n[Test] === 切换到 %s ===" % _current_patient)
			return _current_patient
		else:
			return _current_patient
	else:
		return "nurse_001"


func _start_safety_timer() -> void:
	var my_turn: int = _turn_id
	await get_tree().create_timer(SAFETY_TIMEOUT).timeout
	if my_turn != _turn_id:
		return
	if not _response_queue.is_empty() or _displaying:
		return
	print("[Test] 安全超时(%.0fs)，尝试推进" % SAFETY_TIMEOUT)
	if not _ctx.all_conversations_done():
		var next: String = _ctx.get_next_undone_patient()
		if not next.is_empty():
			_current_patient = next
			_ctx.set_active_patient(_current_patient)
			_fire_next(next)
	_start_safety_timer()


func _on_response_routed(_npc_id: String, _action: Dictionary) -> void:
	pass


func _on_conversation_done(patient_id: String) -> void:
	print("[Test] ✓ %s 分诊完成" % patient_id)
	# ★ 清除该患者的bubble
	var npc: BaseNpc = NpcManager.get_npc(patient_id)
	if npc:
		npc.set_state(BaseNpc.NpcState.WAITING)
		npc.stop_speaking()  # 气泡消失


func _display(npc_id: String, action: Dictionary) -> void:
	var npc: BaseNpc = NpcManager.get_npc(npc_id)
	if not npc: return
	var responses: Array = action.get("responses", [])
	var think: String = action.get("think", "")
	if npc_id == "nurse_001" and responses.size() > 0:
		var all_utts: Array = []
		for r in responses:
			var ru: Array = r.get("utterances", [])
			for u in ru:
				all_utts.append(u)
		if not all_utts.is_empty():
			npc.speak(DialogueEntry.new(npc.get_npc_name(), think, "", "", all_utts))
	else:
		var u: Array = action.get("utterances", [])
		var d: String = action.get("dialogue", "")
		if u.is_empty() and not d.is_empty(): u = [d]
		if u.is_empty(): u = ["..."]
		npc.speak(DialogueEntry.new(npc.get_npc_name(), think, "", "", u))


func _all_done() -> void:
	_turn_id += 1
	for nid in ["nurse_001", "patient_001", "patient_002"]:
		var npc: BaseNpc = NpcManager.get_npc(nid)
		if npc: npc.stop_speaking()
	print("\n[Test] 测试完成")
