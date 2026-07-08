class_name ConversationContext
extends RefCounted

var fsm: Node
var _npcs: Dictionary = {}
var _done_patients: Dictionary = {}


func _init(p_fsm: Node) -> void:
	fsm = p_fsm


func register(npc_id: String, npc: BaseNpc, role: String, knowledge: Array) -> void:
	_npcs[npc_id] = {
		"node": npc,
		"role": role,
		"knowledge": knowledge,
	}


func unregister(npc_id: String) -> void:
	_npcs.erase(npc_id)
	_done_patients.erase(npc_id)


func is_conversation_done(patient_id: String) -> bool:
	return _done_patients.get(patient_id, false)


func mark_done(patient_id: String) -> void:
	_done_patients[patient_id] = true


func on_response(npc_id: String, action: Dictionary, partner_id: String = "") -> void:
	var d: Dictionary = _npcs.get(npc_id, {})
	var npc: BaseNpc = d.get("node", null) as BaseNpc
	if not npc:
		return

	var think: String = action.get("think", "")
	var responses: Array = action.get("responses", [])
	if responses.is_empty():
		var utterances: Array = action.get("utterances", [])
		if not utterances.is_empty() and not partner_id.is_empty():
			responses = [{"target": partner_id, "utterances": utterances}]

	if responses.is_empty() and not partner_id.is_empty():
		var dialogue: String = str(action.get("dialogue", ""))
		if not dialogue.is_empty():
			responses = [{"target": partner_id, "utterances": [dialogue]}]

	for resp in responses:
		var target_id: String = str(resp.get("target", partner_id))
		var target_npc: BaseNpc = _npcs.get(target_id, {}).get("node", null) as BaseNpc
		var utterances: Array = resp.get("utterances", [])
		var text: String = str(utterances[0]) if not utterances.is_empty() else ""
		if text.is_empty():
			continue
		# CRITICAL: use npc_id (not display name) for speaker and listener
		# so get_context_for_partner(npc_id) can find entries
		npc.get_memory().add_dialogue(npc_id, target_id, think, text, 5, [])
		if target_npc:
			target_npc.get_memory().add_dialogue(npc_id, target_id, think, text, 5, [])
		if resp.get("conversation_done", false):
			var role: String = _npcs.get(target_id, {}).get("role", "")
			var done_id: String = target_id if role == "patient" else partner_id
			if not done_id.is_empty():
				mark_done(done_id)



func get_knowledge(npc_id: String) -> Array:
	return _npcs.get(npc_id, {}).get("knowledge", [])
