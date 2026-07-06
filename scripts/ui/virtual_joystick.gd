class_name VirtualJoystick
extends Control

## Mobile virtual joystick.
##
## Touch anywhere on this control to activate. Drag to set direction.
## Returns a normalized Vector2 via get_vector(). Falls back to (0,0).
##
## Place as a child of a CanvasLayer covering the game area.

@export var deadzone: float = 0.15
@export var knob_radius: float = 40.0
@export var base_radius: float = 60.0
@export var color_base: Color = Color(1, 1, 1, 0.15)
@export var color_knob: Color = Color(1, 1, 1, 0.40)

var _active: bool = false
var _touch_id: int = -1
var _center: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE  # only touch


func _draw() -> void:
	if not _active:
		return
	# Base circle
	draw_circle(_center, base_radius, color_base)
	# Knob
	var knob_pos := _center + _direction * knob_radius
	draw_circle(knob_pos, knob_radius * 0.6, color_knob)


func _gui_input(event: InputEvent) -> void:
	# Touch start
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed and not _active:
			_active = true
			_touch_id = st.index
			_center = st.position
			_direction = Vector2.ZERO
			queue_redraw()
			accept_event()
		elif not st.pressed and st.index == _touch_id:
			_deactivate()

	# Touch drag
	if event is InputEventScreenDrag and _active and event.index == _touch_id:
		var offset := event.position - _center
		var len := offset.length()
		if len > deadzone * base_radius:
			_direction = offset.normalized() * minf(1.0, len / base_radius)
		else:
			_direction = Vector2.ZERO
		queue_redraw()


func _deactivate() -> void:
	_active = false
	_touch_id = -1
	_direction = Vector2.ZERO
	queue_redraw()


## Returns a normalized direction vector. `(0,0)` when idle.
func get_vector() -> Vector2:
	if not _active:
		return Vector2.ZERO
	return _direction.normalized() if _direction.length_squared() > 0.01 else Vector2.ZERO
