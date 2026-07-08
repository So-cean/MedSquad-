extends RefCounted
class_name MemoryStore

## Per-NPC associative memory store (Stanford-inspired).
##
## Each NPC has a JSON file at npc_memories/{unique_id}/nodes.json
## containing their memory nodes (events, thoughts, dialogues).
##
## IMPORTANT: unique_id must be UNIQUE per NPC instance (use node name).
## display_name is used for thought subjects, not file paths.

const MEMORY_DIR: String = "user://npc_memories/"

var _npc_id: String  # unique ID for file path (node name)
var _npc_name: String  # display name for thought subjects
var _nodes: Array = []
var _dirty: bool = false


func _init(p_id: String, p_display_name: String = "") -> void:
	_npc_id = p_id
	_npc_name = p_display_name if not p_display_name.is_empty() else p_id
	_load()


# ═══════════════════════════════════════════════════════════════════════
#  Public API
# ═══════════════════════════════════════════════════════════════════════

## Add a dialogue event to memory.
func add_dialogue(
	speaker: String, listener: String,
	think: String, dialogue: String,
	importance: int,
	keywords: Array[String]
) -> Dictionary:
	var time_str: String = ""
	if Engine.has_singleton("TimeSystem"):
		time_str = TimeSystem.get_full_time_str()
	else:
		time_str = Time.get_datetime_string_from_system()

	var node: Dictionary = {
		id = "mem_%s_%d" % [_npc_id, _nodes.size() + 1],
		type = "dialogue",
		created = time_str,
		subject = speaker,
		predicate = "对%s说" % [listener],
		object = dialogue,
		think = think,
		dialogue = dialogue,
		participants = [speaker, listener],
		importance = importance,
		keywords = keywords,
	}
	_nodes.append(node)
	_dirty = true
	_save()
	return node


## Add an internal thought (no dialogue bubble).
func add_thought(content: String, importance: int) -> Dictionary:
	var time_str: String = ""
	if Engine.has_singleton("TimeSystem"):
		time_str = TimeSystem.get_full_time_str()
	else:
		time_str = Time.get_datetime_string_from_system()

	var node: Dictionary = {
		id = "mem_%s_%d" % [_npc_id, _nodes.size() + 1],
		type = "thought",
		created = time_str,
		subject = _npc_name,
		predicate = "思考了",
		object = content,
		think = "",
		dialogue = "",
		importance = importance,
		keywords = [],
	}
	_nodes.append(node)
	_dirty = true
	_save()
	return node


## Get recent N memory nodes for building LLM context.
func get_recent(count: int = 10) -> Array:
	var result: Array = []
	var start: int = max(0, _nodes.size() - count)
	for i in range(start, _nodes.size()):
		result.append(_nodes[i])
	return result


## Get all memories.
func get_all() -> Array:
	return _nodes.duplicate()


## Clear persisted memory for a fresh simulation run.
func clear() -> void:
	_nodes.clear()
	_dirty = true
	_save()


## Get memory as a formatted string for context prompts.
func get_context_str(count: int = 5) -> String:
	var recent: Array = get_recent(count)
	var lines: Array[String] = []
	for node in recent:
		var t: String = node.get("type", "?")
		var s: String = node.get("subject", "")
		var o: String = node.get("object", "")
		var time: String = node.get("created", "")
		if t == "dialogue":
			lines.append("[%s] %s: %s" % [time, s, o])
		elif t == "thought":
			lines.append("[%s] %s 思考: %s" % [time, s, o])
	return "\n".join(lines)


## Get memory filtered by a conversation partner (speaker or listener matches).
## Used by the nurse to get per-patient conversation history.
func get_context_for_partner(partner_id: String, count: int = 5) -> String:
	var filtered: Array = []
	# Iterate in reverse (most recent first)
	var i: int = _nodes.size() - 1
	while i >= 0 and filtered.size() < count:
		var node: Dictionary = _nodes[i]
		var s: String = node.get("subject", "")
		var participants: Array = node.get("participants", [])
		# Match if subject is the partner, or listener (predicate) mentions partner
		if s == partner_id or partner_id in participants:
			filtered.append(node)
		i -= 1
	# Reverse to chronological order
	filtered.reverse()
	var lines: Array[String] = []
	for node in filtered:
		var s2: String = node.get("subject", "")
		var o2: String = node.get("object", "")
		lines.append("%s: %s" % [s2, o2])
	return "\n".join(lines)


# ═══════════════════════════════════════════════════════════════════════
#  Internal
# ═══════════════════════════════════════════════════════════════════════

func _load() -> void:
	var dir: String = MEMORY_DIR + _npc_id + "/"
	var path: String = dir + "nodes.json"
	if not DirAccess.dir_exists_absolute(dir):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		_nodes = parsed as Array


func _save() -> void:
	if not _dirty:
		return
	var dir: String = MEMORY_DIR + _npc_id + "/"
	var path: String = dir + "nodes.json"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("MemoryStore: cannot write %s" % path)
		return
	var json_str: String = JSON.stringify(_nodes, "\t")
	file.store_string(json_str)
	_dirty = false
