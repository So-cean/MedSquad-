extends Node2D

const Config = preload("res://scripts/edmas/config.gd")

@onready var map_ed_core: Sprite2D = $Map_ED_Core
@onready var map_diagnostics: Sprite2D = $Map_Diagnostics
@onready var map_downstream: Sprite2D = $Map_Downstream

const MAP_BY_LOCATION := Config.LOCATION_TO_MAP
const MARKER_BY_LOCATION := Config.LOCATION_TO_MARKER
const MAP_TEXTURE_PATHS := Config.MAP_TEXTURE_PATHS

func _ready() -> void:
	show_map_for_location("ED_ENTRANCE")

func show_map_for_location(location_name: String) -> void:
	var map_id: String = get_map_id_for_location(location_name)
	map_ed_core.visible = map_id == "MAP_ED_CORE"
	map_diagnostics.visible = map_id == "MAP_DIAGNOSTICS"
	map_downstream.visible = map_id == "MAP_DOWNSTREAM"

func get_map_id_for_location(location_name: String) -> String:
	var map_value: Variant = MAP_BY_LOCATION.get(location_name, "MAP_ED_CORE")
	return str(map_value)

func get_marker_position(location_name: String) -> Vector2:
	var marker_value: Variant = MARKER_BY_LOCATION.get(location_name, "Marker_ED_Entrance")
	var marker_name: String = str(marker_value)
	var marker: Node = get_node_or_null(marker_name)
	if marker == null:
		push_warning("hospital_map_manager: missing marker %s, fallback to ED_ENTRANCE" % marker_name)
		marker = get_node_or_null("Marker_ED_Entrance")
	if marker == null:
		return Vector2.ZERO
	var marker_2d: Marker2D = marker as Marker2D
	if marker_2d == null:
		push_warning("hospital_map_manager: marker is not Marker2D: %s" % marker_name)
		return Vector2.ZERO
	return marker_2d.global_position

func get_map_texture_path(location_name: String) -> String:
	var map_id: String = get_map_id_for_location(location_name)
	var path_value: Variant = MAP_TEXTURE_PATHS.get(map_id, "res://assets/maps/normalized/map1_norm.png")
	return str(path_value)
