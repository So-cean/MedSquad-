extends Node

## Receives actions from the backend FSM engine and executes them visually.
##
## Each action is dispatched to the appropriate subsystem:
##   speak    → DialogueBubble (via NPC's speak method)
##   move_to  → Tween actor position
##   wait     → Timer delay
##   use_device → (future)

signal sequence_done()
signal action_started(npc_id: String, type: String)

var _queue: Array = []
var _busy := false
var _sim_client = null  # SimClient reference


func setup(client: Node) -> void:
	_sim_client = client
	if _sim_client and _sim_client.has_signal("actions_received"):
		_sim_client.actions_received.connect(_on_actions_received)


func _on_actions_received(actions: Array) -> void:
	for action in actions:
		_queue.append(action)
	if not _busy:
		_process_next()


func _process_next() -> void:
	if _queue.is_empty():
		_busy = false
		return

	_busy = true
	var action = _queue.pop_front()
	var npc_id: String = action.get("npc_id", "")
	var atype: String = action.get("type", "wait")
	var dialogue: String = action.get("dialogue", "")
	var think: String = action.get("think", "")
	var duration: float = action.get("duration", 2.0)
	var target: String = action.get("target", "")
	var pos: Dictionary = action.get("position", {})

	action_started.emit(npc_id, atype)

	match atype:
		"speak":
			_do_speak(npc_id, think, dialogue, target, duration)
		"move_to":
			_do_move(npc_id, pos, duration)
		"wait":
			_do_wait(duration)
		_:
			_do_wait(duration)


func _do_speak(npc_id: String, think: String, dialogue: String, target: String, duration: float) -> void:
	# Find the NPC by npc_id in the current floor
	var npc = _find_npc_on_floor(npc_id)
	if npc:
		var entry := DialogueEntry.new(npc.get_npc_name(), think, dialogue, target)
		npc.speak(entry)
	# Wait for the dialogue duration + a small buffer for the think animation
	await get_tree().create_timer(maxf(duration, 2.0)).timeout
	_complete(npc_id)


func _do_move(npc_id: String, pos: Dictionary, duration: float) -> void:
	var npc = _find_npc_on_floor(npc_id)
	if npc and pos.has("x") and pos.has("y"):
		var target_pos := Vector2(pos["x"], pos["y"])
		var tween := create_tween()
		tween.tween_property(npc, "position", target_pos, duration)
		await tween.finished
	_complete(npc_id)


func _do_wait(duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	_complete("")


func _complete(npc_id: String) -> void:
	# Report completion to backend
	if _sim_client:
		_sim_client.report_complete(npc_id)
	_busy = false
	_process_next()


func _find_npc_on_floor(npc_id: String):
	# Scan all NPCs in the current scene
	for node in get_tree().get_nodes_in_group("npcs"):
		if node is BaseNpc and node.name == npc_id:
			return node
	# Fallback: try name-based matching
	for node in get_tree().get_nodes_in_group("npcs"):
		if node is BaseNpc and node.get_npc_name() == npc_id:
			return node
	return null
