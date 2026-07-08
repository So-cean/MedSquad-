class_name PatientPlan
extends RefCounted

enum PhaseState { IDLE, IN_SESSION, IN_TRANSIT, IN_TESTING, DISCHARGED }

var patient_id: String = ""
var current_state: int = PhaseState.IDLE
var current_phase: String = "triage_needed"
var last_doctor_id: String = ""


func _init(p_patient_id: String = "") -> void:
	patient_id = p_patient_id


func advance_from_result(result: Dictionary) -> String:
	var next_step: Dictionary = result.get("next_step", result)
	var orders: Array = next_step.get("orders", [])
	if not orders.is_empty():
		push_warning("[PatientPlan] orders are ignored in Step 4A for %s: %s" % [patient_id, str(orders)])
		current_phase = "done"
		current_state = PhaseState.DISCHARGED
		return current_phase

	var next_role: String = str(next_step.get("next_role", next_step.get("target_role", ""))).to_lower()
	match next_role:
		"doctor":
			current_phase = "exam_needed"
			current_state = PhaseState.IDLE
		"discharge":
			current_phase = "done"
			current_state = PhaseState.DISCHARGED
		_:
			current_phase = "done"
			current_state = PhaseState.DISCHARGED
	return current_phase
