extends Camera2D

@export var zoom_min: float = 0.3
@export var zoom_max: float = 3.0
@export var zoom_step: float = 0.1
@export var pan_speed: float = 1.0

var _dragging: bool = false
var _drag_start_mouse: Vector2
var _drag_start_offset: Vector2


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0


func _unhandled_input(event: InputEvent) -> void:
	# ── Zoom ──
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_set_zoom(zoom.x + zoom_step)
				MOUSE_BUTTON_WHEEL_DOWN:
					_set_zoom(zoom.x - zoom_step)
				MOUSE_BUTTON_MIDDLE:
					_dragging = true
					_drag_start_mouse = mb.position
					_drag_start_offset = position

		if not mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = false

	# ── Pan ──
	if event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		position = _drag_start_offset - (mm.position - _drag_start_mouse) * pan_speed / zoom.x


func _set_zoom(value: float) -> void:
	var z: float = clampf(value, zoom_min, zoom_max)
	zoom = Vector2(z, z)
