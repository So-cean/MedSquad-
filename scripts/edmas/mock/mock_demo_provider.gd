extends RefCounted
class_name MockDemoProvider

const DEMO_PATHS: Dictionary = {
	"demo_A": [
		{"state": "ED_READY", "location": "ED_ENTRANCE"},
		{"state": "TRIAGE_WAITING", "location": "TRIAGE"},
		{"state": "WAITING_AREA", "location": "WAITING_AREA"},
		{"state": "DOCTOR_ASSESSMENT", "location": "DOCTOR"},
		{"state": "LAB_PENDING", "location": "LAB"},
		{"state": "RESULT_REVIEW", "location": "RESULT_REVIEW"},
		{"state": "DISPOSITION", "location": "DISPOSITION"},
		{"state": "DISCHARGED", "location": "DISCHARGE"},
	],
	"demo_B": [
		{"state": "ED_READY", "location": "ED_ENTRANCE"},
		{"state": "TRIAGE_WAITING", "location": "TRIAGE"},
		{"state": "WAITING_AREA", "location": "WAITING_AREA"},
		{"state": "DOCTOR_ASSESSMENT", "location": "DOCTOR"},
		{"state": "LAB_PENDING", "location": "LAB"},
		{"state": "IMAGING_PENDING", "location": "IMAGING"},
		{"state": "RESULT_REVIEW", "location": "RESULT_REVIEW"},
		{"state": "DISPOSITION", "location": "DISPOSITION"},
		{"state": "WARD", "location": "WARD"},
	],
	"demo_C": [
		{"state": "ED_READY", "location": "ED_ENTRANCE"},
		{"state": "TRIAGE_WAITING", "location": "TRIAGE"},
		{"state": "RESUS", "location": "ED_RESUS"},
		{"state": "DOCTOR_ASSESSMENT", "location": "DOCTOR"},
		{"state": "IMAGING_PENDING", "location": "IMAGING"},
		{"state": "DISPOSITION", "location": "DISPOSITION"},
		{"state": "ICU", "location": "ICU"},
	],
}

var _current_demo_id: String = ""
var _cursor: int = 0

func list_demos() -> Array:
	return [
		{"demo_id": "demo_A", "patient_id": "mock_patient_A", "final_location": "DISCHARGE"},
		{"demo_id": "demo_B", "patient_id": "mock_patient_B", "final_location": "WARD"},
		{"demo_id": "demo_C", "patient_id": "mock_patient_C", "final_location": "ICU"},
	]

func load_demo(demo_id: String) -> Dictionary:
	_current_demo_id = _normalize_demo_id(demo_id)
	_cursor = 0
	return get_snapshot()

func reset_demo(demo_id: String = "") -> Dictionary:
	if demo_id != "":
		_current_demo_id = _normalize_demo_id(demo_id)
	_cursor = 0
	return get_snapshot()

func step_demo(steps: int = 1) -> Dictionary:
	if steps < 1:
		steps = 1
	_cursor = mini(_cursor + steps, _current_path().size() - 1)
	return get_snapshot()

func get_snapshot() -> Dictionary:
	var path: Array = _current_path()
	var index: int = _safe_cursor(path)
	var step_info: Dictionary = path[index]
	var patient_id: String = _patient_id_for_demo(_current_demo_id)
	return {
		"backend_status": "mock",
		"demo_id": _current_demo_id if _current_demo_id != "" else "demo_A",
		"cursor": index,
		"patient": {
			"patient_id": patient_id,
			"state": str(step_info.get("state", "ED_READY")),
			"location": str(step_info.get("location", "ED_ENTRANCE")),
		},
	}

func _normalize_demo_id(demo_id: String) -> String:
	match demo_id:
		"demo_A", "demo_B", "demo_C":
			return demo_id
		_:
			return "demo_A"

func _current_path() -> Array:
	var demo_id: String = _current_demo_id if _current_demo_id != "" else "demo_A"
	var path_value: Variant = DEMO_PATHS.get(demo_id, DEMO_PATHS["demo_A"])
	if typeof(path_value) == TYPE_ARRAY:
		return path_value as Array
	return DEMO_PATHS["demo_A"] as Array

func _safe_cursor(path: Array) -> int:
	if path.is_empty():
		return 0
	return clamp(_cursor, 0, path.size() - 1)

func _patient_id_for_demo(demo_id: String) -> String:
	match demo_id:
		"demo_B":
			return "mock_patient_B"
		"demo_C":
			return "mock_patient_C"
		_:
			return "mock_patient_A"

