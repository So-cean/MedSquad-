extends RefCounted

## Per-NPC associative memory store (Stanford-inspired).
##
## Each NPC has a JSON file at npc_memories/{npc_name}/nodes.json
## containing their memory nodes (events, thoughts, dialogues).
##
## For now: simple JSON append. Future: SQLite.

const MEMORY_DIR := "user://npc_memories/"

var _npc_name: String
var _nodes: Array = []
var _dirty := false


func _init(npc_name: String) -> void:
	_npc_name = npc_name
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
	var time_str := ""
	if Engine.has_singleton("TimeSystem"):
		time_str = TimeSystem.get_full_time_str()
	else:
		time_str = Time.get_datetime_string_from_system()

	var node := {
		id = "mem_%s_%d" % [_npc_name, _nodes.size() + 1],
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
	var time_str := ""
	if Engine.has_singleton("TimeSystem"):
		time_str = TimeSystem.get_full_time_str()
	else:
		time_str = Time.get_datetime_string_from_system()

	var node := {
		id = "mem_%s_%d" % [_npc_name, _nodes.size() + 1],
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
	var start = max(0, _nodes.size() - count)
	for i in range(start, _nodes.size()):
		result.append(_nodes[i])
	return result


## Get all memories.
func get_all() -> Array:
	return _nodes.duplicate()


## Get memory as a formatted string for context prompts.
func get_context_str(count: int = 5) -> String:
	var recent := get_recent(count)
	var lines: Array[String] = []
	for node in recent:
		var t = node.get("type", "?")
		var s = node.get("subject", "")
		var o = node.get("object", "")
		var time = node.get("created", "")
		if t == "dialogue":
			lines.append("[%s] %s: %s" % [time, s, o])
		elif t == "thought":
			lines.append("[%s] %s 思考: %s" % [time, s, o])
	return "\n".join(lines)


# ═══════════════════════════════════════════════════════════════════════
#  Internal
# ═══════════════════════════════════════════════════════════════════════

func _load() -> void:
	var dir := MEMORY_DIR + _npc_name + "/"
	var path := dir + "nodes.json"
	if not DirAccess.dir_exists_absolute(dir):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		_nodes = parsed as Array


func _save() -> void:
	if not _dirty:
		return
	var dir := MEMORY_DIR + _npc_name + "/"
	var path := dir + "nodes.json"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("MemoryStore: cannot write ", path)
		return
	var json_str := JSON.stringify(_nodes, "\t")
	file.store_string(json_str)
	_dirty = false
