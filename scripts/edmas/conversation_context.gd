class_name ConversationContext
extends RefCounted

## Multi-party conversation orchestrator.
##
## Triage flow (per patient):
##   1. Patient initiates (main complaint)
##   2. Nurse probes (asks follow-up)
##   3. Patient reveals more symptoms
##   4. Nurse assesses + triages
##   5. Nurse gives instructions
##   6. Patient acknowledges
##   7. conversation_done = true → patient moves to next state
##
## The nurse handles patients ONE AT A TIME (sequential triage).
## When one patient's conversation is done, nurse moves to the next.

signal response_received(npc_id: String, action: Dictionary)
signal conversation_done(patient_id: String)

var fsm: Node
var _npcs: Dictionary = {}  # npc_id → { node, role, knowledge }
var _active_patient: String = ""  # who the nurse is currently talking to
var _done_patients: Dictionary = {}  # patient_id → true (conversation finished)


func _init(p_fsm: Node) -> void:
	fsm = p_fsm


func register(npc_id: String, npc: BaseNpc, role: String, knowledge: Array) -> void:
	_npcs[npc_id] = {
		node = npc,
		role = role,
		knowledge = knowledge,
	}


func get_active_patient() -> String:
	return _active_patient


func set_active_patient(npc_id: String) -> void:
	_active_patient = npc_id


func is_conversation_done(patient_id: String) -> bool:
	return _done_patients.get(patient_id, false)


func all_conversations_done() -> bool:
	for pid in _npcs:
		if _npcs[pid].get("role") == "patient" and not is_conversation_done(pid):
			return false
	return true


func get_next_undone_patient() -> String:
	for pid in _npcs:
		if _npcs[pid].get("role") == "patient" and not is_conversation_done(pid):
			return pid
	return ""


## Tick one NPC — build prompt, fire LLM request.
func tick(npc_id: String) -> void:
	var d: Dictionary = _npcs.get(npc_id, {})
	var npc: BaseNpc = d.get("node", null) as BaseNpc
	if not npc:
		return

	var prompt: String
	if d.get("role") == "nurse":
		prompt = _build_nurse_prompt(npc_id, d)
	else:
		prompt = _build_patient_prompt(npc_id, d)

	fsm.request(npc_id, prompt)


## Route response to the right NPCs' memories.
func on_response(npc_id: String, action: Dictionary) -> void:
	var d: Dictionary = _npcs.get(npc_id, {})
	var npc: BaseNpc = d.get("node", null) as BaseNpc
	if not npc:
		return

	var role: String = d.get("role", "")
	var think: String = action.get("think", "")

	if role == "nurse":
		var responses: Array = action.get("responses", [])
		if responses.is_empty():
			var utts: Array = action.get("utterances", [])
			if utts.size() > 0:
				responses = [{"target": _active_patient, "utterances": utts}]

		for resp in responses:
			var target_id: String = resp.get("target", _active_patient)
			var utts2: Array = resp.get("utterances", [])
			var text: String = utts2[0] if utts2.size() > 0 else ""
			var done: bool = resp.get("conversation_done", false)

			if text.is_empty():
				continue

			# Save to nurse's memory (labeled with target)
			npc.get_memory().add_dialogue(npc.get_npc_name(), target_id, think, text, 5, [])

			# Route to target patient's memory
			_route_to_patient(target_id, text, think)

			# Check conversation done
			if done:
				_done_patients[target_id] = true
				conversation_done.emit(target_id)
				print("[Context] 对话完成: %s" % target_id)
	else:
		# Patient → propagate to nurse
		var utts: Array = action.get("utterances", [])
		var text: String = utts[0] if utts.size() > 0 else ""
		if not text.is_empty():
			npc.get_memory().add_dialogue(npc.get_npc_name(), "护士", think, text, 5, [])
			for nid in _npcs:
				if _npcs[nid].get("role") == "nurse":
					var nnpc: BaseNpc = _npcs[nid].get("node", null) as BaseNpc
					if nnpc:
						nnpc.get_memory().add_dialogue(npc_id, "护士", "", text, 5, [])

	response_received.emit(npc_id, action)


func _route_to_patient(patient_id: String, text: String, think: String) -> void:
	var pd: Dictionary = _npcs.get(patient_id, {})
	var pnpc: BaseNpc = pd.get("node", null) as BaseNpc
	if pnpc:
		pnpc.get_memory().add_dialogue("护士", pnpc.get_npc_name(), think, text, 5, [])


# ── Prompt builders ──────────────────────────────────────────

func _build_patient_prompt(npc_id: String, d: Dictionary) -> String:
	var npc: BaseNpc = d.get("node", null) as BaseNpc
	# 只看自己跟护士之间的对话
	var mem_ctx: String = npc.get_memory().get_context_for_partner("护士", 6)
	var mem_str: String = ""
	if not mem_ctx.is_empty():
		mem_str = "你跟护士的对话：\n" + mem_ctx + "\n\n"

	var loc_name: String = HospitalMapData.get_location_name(npc.global_position)
	var floor_name: String = HospitalMapData.get_floor_name()
	var state_name: String = npc.get_state_name()

	# 如果护士已经说了话，就回答护士的问题；否则才说主诉
	var instruction: String
	if not mem_ctx.is_empty():
		instruction = "护士刚才问了你话，回答ta的问题。护士问什么你答什么，不要一次把所有症状都倒出来。如果护士已经给了你指示（比如'去候诊区'或'进抢救室'），你说'好的'然后闭嘴。"
	else:
		instruction = "你是第一次跟护士说话。只说你最难受的一个症状，不要一次全说完。比如只说'我头疼'，等护士追问再补充细节。"

	return ("你是一个普通老百姓，来医院看病。你完全不懂医学，只会用大白话说哪儿难受。\n"
		+ "你在：" + floor_name + "的" + loc_name + "。\n"
		+ "你的状态：" + state_name + "\n"
		+ mem_str
		+ "你的身体情况（护士问你才说对应的，别主动背出来）：\n"
		+ str(d.get("knowledge", [])) + "\n\n"
		+ instruction + "\n"
		+ "必须返回JSON，不要加任何其他文字：\n"
		+ '{"think": "你心里想什么30字内", "utterances": ["1句大白话10-20字"]}')


func _build_nurse_prompt(npc_id: String, d: Dictionary) -> String:
	var npc: BaseNpc = d.get("node", null) as BaseNpc

	var loc_name: String = HospitalMapData.get_location_name(npc.global_position)
	var floor_name: String = HospitalMapData.get_floor_name()

	# 如果有active_patient，护士只跟ta对话
	if _active_patient.is_empty() or is_conversation_done(_active_patient):
		# 找下一个未完成的患者
		_active_patient = get_next_undone_patient()

	if _active_patient.is_empty():
		# 所有患者都处理完了
		return ("你是急诊分诊护士。所有患者的分诊都完成了。\n"
			+ "说一句总结：\n"
			+ '{"think": "总结30字", "utterances": ["一句话总结今天的分诊情况"]}')

	# 获取当前患者的对话历史
	var pd: Dictionary = _npcs.get(_active_patient, {})
	var pnpc: BaseNpc = pd.get("node", null) as BaseNpc
	var p_mem: String = ""
	if pnpc:
		p_mem = npc.get_memory().get_context_for_partner(_active_patient, 6)

	var p_state: String = "未知"
	var p_loc: String = "未知"
	var p_knowledge: String = "无"
	if pnpc:
		p_state = pnpc.get_state_name()
		p_loc = HospitalMapData.get_location_name(pnpc.global_position)
		p_knowledge = str(pd.get("knowledge", []))

	# 还有几个患者等着
	var waiting_count: int = 0
	for pid in _npcs:
		if _npcs[pid].get("role") == "patient" and not is_conversation_done(pid) and pid != _active_patient:
			waiting_count += 1

	var waiting_str: String = ""
	if waiting_count > 0:
		waiting_str = "\n注意：还有%d个患者在等着你看。处理完当前患者要尽快看下一个。" % waiting_count

	return ("你是急诊分诊护士" + npc.get_npc_name() + "。\n"
		+ "你在：" + floor_name + "的" + loc_name + "。\n\n"
		+ "你正在跟" + _active_patient + "做分诊问诊。\n"
		+ "患者状态：" + p_state + " 位置：" + p_loc + "\n"
		+ "患者情况：" + p_knowledge + "\n"
		+ "对话历史：\n" + (p_mem if not p_mem.is_empty() else "（还没说过话）") + "\n\n"
		+ "分诊问诊流程：\n"
		+ "1. 如果患者刚到还没说什么，问ta怎么了\n"
		+ "2. 如果患者说了主诉，追问细节（多久了？还有什么不舒服？）\n"
		+ "3. 如果症状问够了，给出分诊判断和指示\n"
		+ "4. 如果已经给了指示，设conversation_done=true\n"
		+ waiting_str + "\n\n"
		+ "重要：不要重复之前说过的话。根据对话进度往前推进。\n"
		+ "必须返回JSON，不要加任何其他文字：\n"
		+ '{"think": "你的判断30字内", '
		+ '"responses": [{"target": "' + _active_patient + '", "utterances": ["对'+_active_patient+'说1句话"], "conversation_done": false}]}')
