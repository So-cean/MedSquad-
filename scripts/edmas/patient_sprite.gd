extends Node2D

var patient_id := ""
var target_position := Vector2.ZERO
var _move_tween: Tween = null

func setup(p_patient_id: String) -> void:
	patient_id = p_patient_id
	if not has_node("Body"):
		var rect := ColorRect.new()
		rect.name = "Body"
		rect.color = Color(0.2, 0.8, 1.0, 0.85)
		rect.size = Vector2(18, 18)
		rect.position = Vector2(-9, -9)
		add_child(rect)

func apply_patient_state(patient_data: Dictionary) -> void:
	var location_name: String = str(patient_data.get("location", "ED_ENTRANCE"))
	var state_name: String = str(patient_data.get("state", "UNKNOWN"))
	patient_id = str(patient_data.get("patient_id", patient_id))
	if location_name == "":
		location_name = "ED_ENTRANCE"
	if state_name == "":
		state_name = "UNKNOWN"

func move_to(p_target_position: Vector2) -> void:
	target_position = p_target_position
	_stop_move_tween()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", p_target_position, 0.25)

func move_along_path(path_points: Array[Vector2]) -> void:
	if path_points.is_empty():
		push_warning("patient_sprite: empty path for %s" % patient_id)
		return
	_stop_move_tween()
	_move_tween = create_tween()
	var current_point: Vector2 = position
	for point: Vector2 in path_points:
		var distance: float = current_point.distance_to(point)
		var duration: float = max(distance / 140.0, 0.05)
		_move_tween.tween_property(self, "position", point, duration)
		current_point = point
	target_position = path_points[path_points.size() - 1]

func _stop_move_tween() -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null
