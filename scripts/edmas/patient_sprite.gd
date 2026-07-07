extends Node2D

var patient_id := ""
var target_position := Vector2.ZERO

func setup(p_patient_id: String) -> void:
	patient_id = p_patient_id
	z_index = 100
	if not has_node("Body"):
		var rect := ColorRect.new()
		rect.name = "Body"
		rect.color = Color(0.2, 0.8, 1.0, 0.85)
		rect.size = Vector2(16, 16)
		rect.position = Vector2(-8, -8)
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
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", p_target_position, 0.25)
