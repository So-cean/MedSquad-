class_name InteractionSession
extends Session

var professional_npc: BaseNpc = null
var patient_npc: BaseNpc = null
var prompt_role: String = "triage_nurse"
var _professional_id: String = ""
var _patient_id: String = ""
var _last_action: Dictionary = {}


func _init(p_professional_npc: BaseNpc = null, p_patient_npc: BaseNpc = null, p_resources: Array = [], p_prompt_role: String = "triage_nurse") -> void:
	super({"professional": p_professional_npc, "patient": p_patient_npc}, p_resources, p_prompt_role)
	professional_npc = p_professional_npc
	patient_npc = p_patient_npc
	prompt_role = p_prompt_role


func get_patient_id() -> String:
	if _patient_id.is_empty() and patient_npc:
		_patient_id = NpcManager.get_npc_id(patient_npc)
	return _patient_id


func _start() -> void:
	if not professional_npc or not patient_npc:
		end({"next_step": {"next_role": "discharge", "reason": "missing participant", "orders": []}})
		return
	_professional_id = NpcManager.get_npc_id(professional_npc)
	_patient_id = NpcManager.get_npc_id(patient_npc)
	print("[Session] started %s patient=%s professional=%s" % [prompt_role, _patient_id, _professional_id])
	patient_npc.approach_and_face(professional_npc, 60.0)
	await _wait_for_arrival(patient_npc, 15.0)
	if _ended:
		return
	patient_npc.stop_speaking()
	professional_npc.stop_speaking()
	patient_npc.face_toward(professional_npc.global_position)
	professional_npc.face_toward(patient_npc.global_position)
	_fire_llm(_professional_id)


func _fire_llm(npc_id: String) -> void:
	var npc: BaseNpc = NpcManager.get_npc(npc_id)
	if not npc:
		end({"next_step": {"next_role": "discharge", "reason": "speaker missing", "orders": []}})
		return
	var partner: BaseNpc = professional_npc if npc_id == _patient_id else patient_npc
	var role: String = "patient" if npc_id == _patient_id else prompt_role
	var memory: String = npc.get_memory().get_context_for_partner(NpcManager.get_npc_id(partner), 8) if partner else ""
	var patient_visible_memory: String = patient_npc.get_memory_context(10) if patient_npc else ""
	var patient_knowledge: Array = NpcManager.get_knowledge(_patient_id) if role == "patient" else []
	var prompt: String = PromptContext.build_agent_prompt(role, npc, partner, memory, {
		"patient_id": _patient_id,
		"patient_knowledge": patient_knowledge,
		"patient_visible_memory": patient_visible_memory,
	})
	NpcManager.get_fsm().request(npc_id, prompt)


func _handle_action(npc_id: String, action: Dictionary) -> void:
	_last_action = action
	NpcManager.get_context().on_response(npc_id, action, _partner_id(npc_id))
	_display(npc_id, action)


func _after_display(npc_id: String, action: Dictionary) -> void:
	if _ended:
		return
	# Max-turn cap: prevent endless LLM loops even if LLM never sets conversation_done
	if _turn_id >= MAX_TURNS:
		var forced_role: String = "doctor" if prompt_role == "triage_nurse" else "discharge"
		print("[Session] max turns reached (%d), force ending %s → %s" % [_turn_id, prompt_role, forced_role])
		end({"next_step": {"next_role": forced_role, "reason": "max_turns_reached", "orders": []}, "patient_id": _patient_id, "professional_id": _professional_id})
		return
	if _is_done(action):
		var final_result: Dictionary = _result_from_action(action)
		print("[Session] ended %s patient=%s result=%s" % [prompt_role, _patient_id, str(final_result)])
		end(final_result)
		return
	var next_id: String = _partner_id(npc_id)
	if not next_id.is_empty():
		_fire_llm(next_id)


func _partner_id(npc_id: String) -> String:
	return _professional_id if npc_id == _patient_id else _patient_id


func _is_done(action: Dictionary) -> bool:
	for resp in action.get("responses", []):
		if resp.get("conversation_done", false):
			return true
	return false


func _result_from_action(action: Dictionary) -> Dictionary:
	var next_step: Dictionary = {}
	if action.get("next_step", null) is Dictionary:
		next_step = action.get("next_step")
	var next_role: String = str(next_step.get("next_role", next_step.get("target_role", ""))).to_lower()
	if next_role.is_empty():
		next_role = "doctor" if prompt_role == "triage_nurse" else "discharge"
	next_step["next_role"] = next_role
	if not next_step.has("orders"):
		next_step["orders"] = []
	return {"next_step": next_step, "patient_id": _patient_id, "professional_id": _professional_id}
