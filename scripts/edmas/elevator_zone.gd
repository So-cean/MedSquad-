class_name ElevatorZone
extends Area2D

## Elevator interaction zone. Player walks in → hint shows → E/Q to change floor.

signal request_switch_map(direction: int)  # +1 = next, -1 = prev

@onready var _player_ref = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_ref = body


func _on_body_exited(body: Node) -> void:
	if body == _player_ref:
		_player_ref = null


func is_player_inside() -> bool:
	return _player_ref != null
