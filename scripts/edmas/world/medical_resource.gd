class_name MedicalResource
extends RefCounted

## A shared medical resource — staff, device, or room.
##
## At most one occupant at a time; further requests join a FIFO queue.
## Pure data + signals: no scene node dependency. The Scheduler (Step 4)
## calls request()/release() around each Session.
##
## Not enforced yet in Step 2 — Registry populates but nothing requests.

signal occupied(patient_id: String)
signal released()
signal queue_changed()

const KIND_STAFF: String = "staff"     # nurse, doctor, surgeon, technician
const KIND_DEVICE: String = "device"   # ct_scanner, lab_analyzer, ecg_monitor
const KIND_ROOM: String = "room"       # triage_room, resus_bay, exam_room

var id: String
var kind: String
var display_name: String
var role: String       # subtype within kind: "nurse", "ct_scanner", "resus_bay", ...
var location: String   # named location key from HospitalMapData

var occupant_id: String = ""    # patient_id currently using this, "" if idle
var queue: Array = []           # [patient_id, ...] in FIFO order


func _init(p_id: String, p_kind: String, p_display: String, p_role: String, p_loc: String) -> void:
	id = p_id
	kind = p_kind
	display_name = p_display
	role = p_role
	location = p_loc


func is_busy() -> bool:
	return not occupant_id.is_empty()


func queue_size() -> int:
	return queue.size()


func has_pending(patient_id: String) -> bool:
	return occupant_id == patient_id or queue.has(patient_id)


## Try to acquire this resource for a patient.
## Returns { granted: bool, position: int }.
##   granted=true, position=0  → patient now occupies the resource
##   granted=false, position=N → patient is Nth in queue (0-indexed)
func request(patient_id: String) -> Dictionary:
	if occupant_id == patient_id:
		return {"granted": true, "position": 0}
	if queue.has(patient_id):
		return {"granted": false, "position": queue.find(patient_id)}
	if occupant_id.is_empty():
		occupant_id = patient_id
		occupied.emit(patient_id)
		return {"granted": true, "position": 0}
	queue.append(patient_id)
	queue_changed.emit()
	return {"granted": false, "position": queue.size() - 1}


## Release the resource. Promotes the next queued patient (if any).
## Returns the newly-promoted patient_id, or "" if queue was empty.
func release() -> String:
	occupant_id = ""
	released.emit()
	if queue.is_empty():
		return ""
	var next_id: String = queue.pop_front()
	occupant_id = next_id
	queue_changed.emit()
	occupied.emit(next_id)
	return next_id


## Remove a patient from occupant or queue, wherever they are.
func cancel(patient_id: String) -> void:
	if occupant_id == patient_id:
		release()
		return
	var idx: int = queue.find(patient_id)
	if idx >= 0:
		queue.remove_at(idx)
		queue_changed.emit()


func status() -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"role": role,
		"location": location,
		"occupant": occupant_id,
		"queue": queue.duplicate(),
	}
