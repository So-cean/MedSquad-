class_name TimelineLoader
extends RefCounted


func load_timeline(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("TimelineLoader: cannot open timeline: ", path)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary

	push_error("TimelineLoader: invalid timeline JSON: ", path)
	return {}
