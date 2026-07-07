extends Area2D

## NPC interaction zone. Player walks in → shows "按 E" prompt → presses E to talk.

var player_inside := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false


func is_player_inside() -> bool:
	return player_inside
