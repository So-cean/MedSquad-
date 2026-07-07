class_name MockDialogueSystem
extends Node

## Generates mock dialogue flows loaded from data/mock_flows.json.
##
## Uses ConversationManager for 1v1 pairing + priority interruption.
## When a speaker is busy and the new request has higher priority,
## the speaker switches. Otherwise the requester gets a "please wait"
## response and enters the target's queue.

const FLOWS_PATH := "res://data/mock_flows.json"

var _all_flows: Array = []
var _current_flow: Dictionary = {}
var _flow_idx: int = 0
var _last_speaker: BaseNpc = null
var _last_listener: BaseNpc = null
var _npc_map: Dictionary = {}  # npc_name → BaseNpc
var _paused := false


func _ready() -> void:
	_load_flows()
	_tree_timer(1.5, _scan_npcs)


# ═══════════════════════════════════════════════════════════════════════
#  JSON loading
# ═══════════════════════════════════════════════════════════════════════

func _load_flows() -> void:
	var file := FileAccess.open(FLOWS_PATH, FileAccess.READ)
	if not file:
		push_error("MockDialogueSystem: cannot open ", FLOWS_PATH)
		return
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary and parsed.has("flows"):
		_all_flows = parsed["flows"] as Array
		print("MockDialogueSystem: loaded %d flows" % _all_flows.size())
	else:
		push_error("MockDialogueSystem: invalid format in ", FLOWS_PATH)


# ═══════════════════════════════════════════════════════════════════════
#  NPC scanning
# ═══════════════════════════════════════════════════════════════════════

func _scan_npcs() -> void:
	_npc_map.clear()
	for node in get_tree().get_nodes_in_group("npcs"):
		if node is BaseNpc:
			_npc_map[node.get_npc_name()] = node

	if _all_flows.size() > 0:
		_start_random_flow()


func _find_npc(npc_name: String) -> BaseNpc:
	return _npc_map.get(npc_name) as BaseNpc


# ═══════════════════════════════════════════════════════════════════════
#  Flow execution
# ═══════════════════════════════════════════════════════════════════════

func _start_random_flow() -> void:
	if _all_flows.size() == 0:
		return
	var idx := randi() % _all_flows.size()
	start_flow_by_index(idx)


func start_flow_by_index(idx: int) -> void:
	if idx < 0 or idx >= _all_flows.size():
		return
	_current_flow = _all_flows[idx].duplicate(true)
	_flow_idx = 0
	_last_speaker = null
	_last_listener = null
	_paused = false
	_execute_next()


func _execute_next() -> void:
	if _paused:
		return

	# Check if flow finished
	var steps: Array = _current_flow.get("steps", [])
	if _flow_idx >= steps.size():
		# Clear last speaker's bubble so it doesn't linger forever
		if _last_speaker:
			_last_speaker.stop_speaking()
			_last_speaker = null
		_tree_timer(2.0, _start_random_flow)
		return

	var step: Dictionary = steps[_flow_idx]
	var speaker_name: String = step.get("speaker", "")
	var listener_name: String = step.get("listener", "")
	var think: String = step.get("think", "")
	var dialogue: String = step.get("dialogue", "")
	var duration: float = step.get("duration", 3.0)
	var priority: int = step.get("priority", 1)

	var speaker := _find_npc(speaker_name)
	var listener := _find_npc(listener_name)

	if not speaker or not listener:
		_flow_idx += 1
		_execute_next()  # skip missing NPC
		return

	# Check with ConversationManager (child of DialogueManager)
	var cm = DialogueManager.get_conversation_manager()
	if cm:
		var result: Dictionary = cm.request_speak(speaker, listener, priority)
		if not result.get("ok", false):
			# Speaker is not free to speak right now
			if result.get("reason", "") == "busy" and result.get("notify_self", false):
				# Speaker needs to inform listener they're busy
				var busy_entry := DialogueEntry.new(speaker_name,
					"正在处理其他事务，需要让对方等待",
					"请稍等，我正在处理其他患者的事情。")
				speaker.speak(busy_entry)
				_tree_timer(1.5, _retry_step)
				return
			else:
				# Skip this step and try next
				_flow_idx += 1
				_execute_next()
				return

	# Clear previous speaker if different
	if _last_speaker and _last_speaker != speaker:
		_last_speaker.stop_speaking()
		if _last_listener:
			_last_listener.stop_speaking()

	# Speak!
	var entry := DialogueEntry.new(speaker_name, think, dialogue, listener_name)
	speaker.speak(entry)

	# Record to memory
	speaker.record_dialogue(listener_name, think, dialogue, priority + 2)

	_last_speaker = speaker
	_last_listener = listener
	_flow_idx += 1

	# Schedule next step
	_tree_timer(duration, _execute_next)


func _retry_step() -> void:
	# Re-try the current step (flow_idx was NOT incremented on failure)
	_execute_next()


func _tree_timer(delay: float, callback: Callable) -> void:
	if not is_inside_tree():
		return
	get_tree().create_timer(delay).timeout.connect(callback)
