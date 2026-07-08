extends Node

var _active_sessions: Array = []
var _pending_sessions: Array = []
var _patient_plans: Dictionary = {}
var _started_patients: Dictionary = {}


func _ready() -> void:
	print("[Scheduler] ready")
	await get_tree().process_frame
	if NpcManager and not NpcManager.patient_arrived.is_connected(_on_patient_arrived):
		NpcManager.patient_arrived.connect(_on_patient_arrived)
	if NpcManager and not NpcManager.patient_discharged.is_connected(_on_patient_discharged):
		NpcManager.patient_discharged.connect(_on_patient_discharged)
	if ResourceRegistry and not ResourceRegistry.resource_state_changed.is_connected(_on_resource_state_changed):
		ResourceRegistry.resource_state_changed.connect(_on_resource_state_changed)


func submit(session: Session) -> void:
	if not session.ended.is_connected(_on_session_ended):
		session.ended.connect(_on_session_ended)
	if session.try_activate():
		_active_sessions.append(session)
		print("[Scheduler] session_started active=%d pending=%d" % [_active_sessions.size(), _pending_sessions.size()])
		session.activate()
	else:
		_pending_sessions.append(session)
		_send_patient_to_waiting(session)
		print("[Scheduler] session_pending active=%d pending=%d" % [_active_sessions.size(), _pending_sessions.size()])


func get_active_count() -> int:
	return _active_sessions.size()


func get_pending_count() -> int:
	return _pending_sessions.size()


func _on_patient_arrived(patient_id: String, npc: BaseNpc) -> void:
	if _started_patients.has(patient_id):
		return
	_started_patients[patient_id] = true
	_patient_plans[patient_id] = PatientPlan.new(patient_id)
	_dispatch_triage(patient_id, npc)


func _on_patient_discharged(_patient_id: String) -> void:
	_check_all_discharged()


func _dispatch_triage(patient_id: String, patient: BaseNpc) -> void:
	var nurse_res = ResourceRegistry.find_idle_by_role("nurse")
	if not nurse_res:
		nurse_res = ResourceRegistry.find_by_role("nurse")
	if not nurse_res:
		push_warning("[Scheduler] no nurse resource for %s" % patient_id)
		return
	var nurse_id: String = nurse_res.id.trim_prefix("staff_")
	var nurse: BaseNpc = NpcManager.get_npc(nurse_id)
	if not nurse:
		push_warning("[Scheduler] nurse npc missing: %s" % nurse_id)
		return
	submit(InteractionSession.new(nurse, patient, [nurse_res], "triage_nurse"))


func _dispatch_doctor(patient_id: String) -> void:
	var patient: BaseNpc = NpcManager.get_npc(patient_id)
	if not patient:
		return
	var doctor_res = ResourceRegistry.find_idle_by_role("doctor")
	if not doctor_res:
		doctor_res = ResourceRegistry.find_by_role("doctor")
	if not doctor_res:
		push_warning("[Scheduler] no doctor resource for %s" % patient_id)
		NpcManager.discharge(patient_id)
		return
	var doctor_id: String = doctor_res.id.trim_prefix("staff_")
	var doctor: BaseNpc = NpcManager.get_npc(doctor_id)
	if not doctor:
		push_warning("[Scheduler] doctor npc missing: %s" % doctor_id)
		NpcManager.discharge(patient_id)
		return
	submit(InteractionSession.new(doctor, patient, [doctor_res], "doctor"))


func _on_resource_state_changed(_res_id: String) -> void:
	var copy: Array = _pending_sessions.duplicate()
	for session in copy:
		if session.state == Session.State.ENDED:
			_pending_sessions.erase(session)
			continue
		if session.try_activate():
			_pending_sessions.erase(session)
			_active_sessions.append(session)
			print("[Scheduler] pending_session_activated active=%d pending=%d" % [_active_sessions.size(), _pending_sessions.size()])
			session.activate()


func _on_session_ended(session: Session, result: Dictionary) -> void:
	_active_sessions.erase(session)
	_pending_sessions.erase(session)
	var patient_id: String = result.get("patient_id", session.get_patient_id())
	var plan: PatientPlan = _patient_plans.get(patient_id, null)
	if plan:
		plan.advance_from_result(result)
	_dispatch_from_result(patient_id, result)
	_check_all_discharged()


func _dispatch_from_result(patient_id: String, result: Dictionary) -> void:
	var next_step: Dictionary = result.get("next_step", result)
	var orders: Array = next_step.get("orders", [])
	if not orders.is_empty():
		push_warning("[Scheduler] orders ignored in 4A for %s: %s" % [patient_id, str(orders)])
		NpcManager.discharge(patient_id)
		return

	var next_role: String = str(next_step.get("next_role", next_step.get("target_role", ""))).to_lower()
	match next_role:
		"doctor":
			_dispatch_doctor(patient_id)
		"discharge":
			NpcManager.discharge(patient_id)
		_:
			NpcManager.discharge(patient_id)


func _send_patient_to_waiting(session: Session) -> void:
	var patient_id: String = session.get_patient_id()
	var patient: BaseNpc = NpcManager.get_npc(patient_id)
	if patient:
		patient.set_state(BaseNpc.NpcState.GOING_TO_ROOM, "WAITING_AREA")
		patient.speak(DialogueEntry.new(patient.get_npc_name(), "", "", "", ["我先去等着。"]))


func _check_all_discharged() -> void:
	var any_patient: bool = false
	for entry in NpcManager.get_status().values():
		if entry.get("role", "") == "patient":
			any_patient = true
			break
	if not any_patient and not _started_patients.is_empty():
		print("[Scheduler] All patients discharged")
