extends RefCounted
class_name PatientFactory

var _sequence: int = 0

func create_patient_record(case_id: String = "") -> Dictionary:
	var case_data: Dictionary = PatientCasePool.get_case(case_id)
	if case_data.is_empty():
		case_data = PatientCasePool.get_case(PatientCasePool.get_default_case_id())
	_sequence += 1
	var patient_id: String = "patient_%03d" % _sequence
	return {
		"patient_id": patient_id,
		"case_id": str(case_data.get("case_id", case_id)),
		"chief_complaint": str(case_data.get("chief_complaint", "")),
		"acuity_hint": str(case_data.get("acuity_hint", "send_to_doctor")),
		"state": "ARRIVED",
		"location": "ED_ENTRANCE",
		"local_result": "",
	}

func spawn_patient(parent: Node, case_id: String = "") -> Node2D:
	var case_data: Dictionary = PatientCasePool.get_case(case_id)
	if case_data.is_empty():
		case_data = PatientCasePool.get_case(PatientCasePool.get_default_case_id())
	var scene_path: String = "res://scens/patient_blue.tscn"
	if str(case_data.get("acuity_hint", "")) == "send_to_resus":
		scene_path = "res://scens/patient_green.tscn"
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("PatientFactory: missing patient scene: %s" % scene_path)
		return null
	var instance: Node = packed_scene.instantiate()
	var patient_node: Node2D = instance as Node2D
	if patient_node == null:
		push_error("PatientFactory: patient scene is not Node2D")
		return null
	var patient_record: Dictionary = create_patient_record(case_id)
	var patient_id: String = str(patient_record.get("patient_id", ""))
	patient_node.name = patient_id
	for key: String in patient_record.keys():
		patient_node.set_meta(key, patient_record[key])
	if parent != null:
		parent.add_child(patient_node)
	return patient_node

