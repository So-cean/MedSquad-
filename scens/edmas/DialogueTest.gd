extends Node2D

## 10-round dialogue test using GDScript NPC FSM — directly calls Gitee AI.
## No Python backend, no mock. Godot -> HTTPRequest -> Gitee API -> Bubble.

var _fsm: Node = null
var _round := 0
var _nurse = null
var _patient1 = null
var _patient2 = null
var _pending_actions := 0
var _round_actions := []  # actions collected for current round


func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	_nurse = _find_npc("分诊护士")
	_patient1 = _find_npc("患者")
	if not _nurse or not _patient1:
		push_error("NPCs not found")
		return

	# Create NPC FSM (direct Gitee AI calls, no backend)
	_fsm = load("res://scripts/edmas/npc_fsm.gd").new()
	add_child(_fsm)
	_fsm.action_ready.connect(_on_action_ready)

	# Register NPCs with FSM
	_fsm.register_npc("nurse_001", "分诊护士", "nurse",
		[{"condition": "头痛", "action": "建议CT检查"}])
	_fsm.register_npc("patient_001", "患者", "patient", [])
	_fsm.register_npc("patient_002", "患者", "patient", [])

	print("[Test] FSM ready, starting 10 rounds...")
	_start_round()


func _start_round() -> void:
	if _round >= 10:
		print("\n[Test] 10 rounds complete")
		return

	_round += 1
	print("\n[Test] === Round %d ===" % _round)
	_pending_actions = 0
	_round_actions.clear()

	# Tick all 3 NPCs — each sends a concurrent LLM request
	_pending_actions = 3
	_fsm.tick_all()
	# Safety timeout: if some NPCs don't respond within 20s, proceed anyway
	await get_tree().create_timer(20.0).timeout
	if _pending_actions > 0:
		print("[Test] Round %d: %d NPC(s) timed out, proceeding" % [_round, _pending_actions])
		_execute_round()


func _on_action_ready(npc_id: String, action: Dictionary) -> void:
	action["npc_id"] = npc_id
	_round_actions.append(action)

	_pending_actions -= 1
	if _pending_actions > 0:
		return

	# All actions received — proceed (cancel the safety timer)
	_execute_round()


func _execute_round() -> void:
	for action in _round_actions:
		await _execute_action(action)

	# All done, start next round
	await get_tree().create_timer(0.5).timeout
	_start_round()


func _execute_action(action: Dictionary) -> void:
	var npc_id = action.get("npc_id", "")
	var atype = action.get("type", "wait")
	var utterances = action.get("utterances", [])
	var dialogue = action.get("dialogue", "")
	var think = action.get("think", "")

	var npc = _nurse if npc_id == "nurse_001" else _patient1

	if atype == "speak":
		if utterances.is_empty() and not dialogue.is_empty():
			utterances = [dialogue]
		if utterances.is_empty():
			utterances = ["..."]
		var entry := DialogueEntry.new(npc.get_npc_name(), think, "", "", utterances)
		npc.speak(entry)
		print("[Test]  [%s] %d utterances" % [npc_id, utterances.size()])
		await get_tree().create_timer(maxf(utterances.size() * 2.5, 3.0)).timeout
	else:
		print("[Test]  [%s] %s" % [npc_id, atype])
		await get_tree().create_timer(action.get("duration", 1.0)).timeout

	_fsm.report_complete(npc_id)


func _find_npc(name: String):
	for node in get_tree().get_nodes_in_group("npcs"):
		if node is BaseNpc and node.get_npc_name() == name:
			return node
	return null
