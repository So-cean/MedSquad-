extends RefCounted
class_name NavigationService

const MapConfig = preload("res://scripts/edmas/navigation/map_navigation_config.gd")

var _grid: AStarGrid2D = null
var _map_id: String = ""
var _cell_size := Vector2i(16, 16)
var _map_size := Vector2i(64, 36)
var _built := false

func build_for_map(map_id: String) -> bool:
	_map_id = map_id
	_built = false
	var config: Dictionary = MapConfig.get_map_config(map_id)
	if config.is_empty():
		push_warning("navigation_service: missing map config for %s" % map_id)
		_grid = null
		return false

	var configured_cell_size: Variant = config.get("cell_size", _cell_size)
	var configured_map_size: Variant = config.get("map_size", _map_size)
	if typeof(configured_cell_size) == TYPE_VECTOR2I:
		_cell_size = configured_cell_size as Vector2i
	if typeof(configured_map_size) == TYPE_VECTOR2I:
		_map_size = configured_map_size as Vector2i
	var mask_path: String = str(config.get("mask_path", ""))
	var mask_image: Image = _load_mask(mask_path)
	if mask_image == null:
		push_warning("navigation_service: missing mask for %s at %s" % [map_id, mask_path])
		_grid = null
		return false

	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(Vector2i.ZERO, _map_size)
	_grid.cell_size = Vector2(float(_cell_size.x), float(_cell_size.y))
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	_grid.update()
	_apply_mask(mask_image)
	_built = true
	return true

func get_path(start_world: Vector2, end_world: Vector2) -> Array[Vector2]:
	if not _built or _grid == null:
		push_warning("navigation_service: get_path called before build_for_map")
		return []
	var start_cell: Vector2i = world_to_cell(start_world)
	var end_cell: Vector2i = world_to_cell(end_world)
	if not _is_cell_in_region(start_cell) or not _is_cell_in_region(end_cell):
		push_warning("navigation_service: path endpoints outside map %s" % _map_id)
		return []
	if _grid.is_point_solid(start_cell) or _grid.is_point_solid(end_cell):
		push_warning("navigation_service: path endpoint blocked on %s" % _map_id)
		return []
	var cells: Array[Vector2i] = _grid.get_id_path(start_cell, end_cell)
	if cells.is_empty():
		push_warning("navigation_service: path failed on %s" % _map_id)
		return []
	var points: Array[Vector2] = []
	for cell: Vector2i in cells:
		points.append(cell_to_world(cell))
	if points.size() > 0:
		points[0] = start_world
		points[points.size() - 1] = end_world
	return points

func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / float(_cell_size.x)), floori(world_position.y / float(_cell_size.y)))

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * float(_cell_size.x), (float(cell.y) + 0.5) * float(_cell_size.y))

func _load_mask(mask_path: String) -> Image:
	if mask_path.is_empty() or not FileAccess.file_exists(mask_path):
		return null
	var image := Image.new()
	var error: Error = image.load(mask_path)
	if error != OK:
		push_warning("navigation_service: failed reading mask %s" % mask_path)
		return null
	return image

func _apply_mask(mask_image: Image) -> void:
	var width: int = min(_map_size.x, mask_image.get_width())
	var height: int = min(_map_size.y, mask_image.get_height())
	for y in range(height):
		for x in range(width):
			var pixel: Color = mask_image.get_pixel(x, y)
			var blocked: bool = pixel.a > 0.0 and pixel.get_luminance() < 0.5
			_grid.set_point_solid(Vector2i(x, y), blocked)

func _is_cell_in_region(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _map_size.x and cell.y < _map_size.y
