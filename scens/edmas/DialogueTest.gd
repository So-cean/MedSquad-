extends Node2D

## 10-round dialogue test using LLM backend API calls.
## Starts a simulation with 1 nurse + 2 patients, drives conversation via /api/sim/tick.

var _sim_client = null
var _round := 0
var _nurse = null
var _patient1 = null
var _patient2 = null


func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	_nurse = _find_npc("分诊护士")
	_patient1 = _find_npc("患者")
	_patient2 = _patient1  # both are "患者", same name
	if not _nurse or not _patient1:
		push_error("NPCs not found")
		return

	# Wait for BackendBridge to be ready
	var bb = get_node_or_null("/root/BackendBridge")
	if not bb:
		push_error("BackendBridge not found")
		return

	_sim_client = bb.get_sim_client()
	if not _sim_client:
		push_error("SimClient not available")
		return

	# Wait for backend to be ready
	if not bb.is_ready:
		print("[Test] Waiting for backend...")
		await bb.backend_ready
		print("[Test] Backend ready")

	_init_sim()
	_run_rounds()


func _init_sim() -> void:
	var npcs = [
		{"id": "nurse_001", "display_name": "分诊护士", "role": "nurse",
		 "knowledge": [{"condition": "头痛", "action": "建议CT检查"}],
		 "position": {"x": 400, "y": 300}},
		{"id": "patient_001", "display_name": "患者", "role": "patient",
		 "knowledge": [], "position": {"x": 600, "y": 280}},
		{"id": "patient_002", "display_name": "患者", "role": "patient",
		 "knowledge": [], "position": {"x": 600, "y": 360}},
	]
	_sim_client.init_simulation(npcs, {
		"chief_complaint": "头痛2天伴发热38度",
		"symptoms": ["头痛", "发热"],
		"state": "等待中"
	})
	print("[Test] Simulation initialized")


func _run_rounds() -> void:
	_round = 0
	while _round < 10:
		_round += 1
		print("\n[Test] === Round %d ===" % _round)

		# Tick the backend — returns actions for all NPCs
		_sim_client.request_tick()
		await _sim_client.actions_received
		var actions = _sim_client.get_last_response().get("actions", [])
		print("[Test] Received %d actions" % actions.size())

		for action in actions:
			await _execute_action(action)

	await get_tree().create_timer(2.0).timeout
	print("\n[Test] 10 rounds complete")


func _execute_action(action: Dictionary) -> void:
	var npc_id = action.get("npc_id", "")
	var atype = action.get("type", "wait")
	var utterances = action.get("utterances", [])
	var dialogue = action.get("dialogue", "")
	var think = action.get("think", "")

	# Find matching NPC
	var npc = _nurse if npc_id == "nurse_001" else _patient1

	if atype == "speak":
		if utterances.is_empty() and not dialogue.is_empty():
			utterances = [dialogue]
		if utterances.is_empty():
			print("[Test]  [%s] (empty speak)" % npc_id)
			return

		var entry := DialogueEntry.new(
			npc.get_npc_name(), think, "", "", utterances
		)
		npc.speak(entry)
		print("[Test]  [%s] spoke %d utterances" % [npc_id, utterances.size()])
		# Wait for all utterances to play
		await get_tree().create_timer(maxf(utterances.size() * 2.5, 3.0)).timeout
	else:
		print("[Test]  [%s] %s (%.1fs)" % [npc_id, atype, action.get("duration", 1.0)])
		await get_tree().create_timer(action.get("duration", 1.0)).timeout

	# Report completion
	_sim_client.report_complete(npc_id)


func _find_npc(name: String):
	for node in get_tree().get_nodes_in_group("npcs"):
		if node is BaseNpc and node.get_npc_name() == name:
			return node
	return null
