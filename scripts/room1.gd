extends Node2D

## room1 main script — handles NPC dialogue and map overlay toggle.

@onready var map_overlay: CanvasLayer = $MapOverlay


func _ready() -> void:
	if map_overlay:
		map_overlay.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_M and event.pressed and not event.echo:
		if map_overlay:
			map_overlay.visible = not map_overlay.visible
			get_viewport().set_input_as_handled()
