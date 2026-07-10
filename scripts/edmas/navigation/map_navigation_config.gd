extends RefCounted
class_name MapNavigationConfig

const DEFAULT_CELL_SIZE := Vector2i(16, 16)
const DEFAULT_MAP_SIZE := Vector2i(64, 36)

const MAPS := {
	"MAP_ED_CORE": {
		"mask_path": "res://assets/maps/navigation/map_ed_core_mask.png",
		"cell_size": DEFAULT_CELL_SIZE,
		"map_size": DEFAULT_MAP_SIZE,
	},
	"MAP_DIAGNOSTICS": {
		"mask_path": "res://assets/maps/navigation/map_diagnostics_mask.png",
		"cell_size": DEFAULT_CELL_SIZE,
		"map_size": DEFAULT_MAP_SIZE,
	},
	"MAP_DOWNSTREAM": {
		"mask_path": "res://assets/maps/navigation/map_downstream_mask.png",
		"cell_size": DEFAULT_CELL_SIZE,
		"map_size": DEFAULT_MAP_SIZE,
	},
}

static func get_map_config(map_id: String) -> Dictionary:
	var config_value: Variant = MAPS.get(map_id, {})
	if typeof(config_value) == TYPE_DICTIONARY:
		return (config_value as Dictionary).duplicate(true)
	return {}
