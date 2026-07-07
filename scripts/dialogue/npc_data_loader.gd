class_name NPCDataLoader
extends RefCounted

## Loads NPC configuration from JSON files in data/npcs/.
##
## Each NPC type has a JSON file with identity, knowledge, and scratch state.
## NPC instances in the scene reference their type via get_npc_name().

const NPC_DATA_DIR := "res://data/npcs/"


## Returns the raw JSON data for an NPC type, or null on failure.
static func load_npc(npc_name: String) -> Dictionary:
	var path := NPC_DATA_DIR + npc_name + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("NPCDataLoader: cannot open ", path)
		return {}
	var text := file.get_as_text()
	var result: Variant = JSON.parse_string(text)
	if not result is Dictionary:
		push_error("NPCDataLoader: invalid JSON in ", path)
		return {}
	return result as Dictionary


## Returns the knowledge list for an NPC.
static func get_knowledge(npc_name: String) -> Array:
	var data := load_npc(npc_name)
	return data.get("knowledge", [])


## Returns the default priority for an NPC.
static func get_default_priority(npc_name: String) -> int:
	var data := load_npc(npc_name)
	return data.get("priority_default", 0)


## Returns the scratch state for an NPC.
static func get_scratch(npc_name: String) -> Dictionary:
	var data := load_npc(npc_name)
	return data.get("scratch", {})


## Returns the personality description.
static func get_personality(npc_name: String) -> String:
	var data := load_npc(npc_name)
	return data.get("personality", "")
