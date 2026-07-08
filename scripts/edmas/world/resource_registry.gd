extends Node

## ResourceRegistry — global registry of MedicalResource instances.
##
## Autoload. Discovers staff resources from NpcManager (nurses, doctors)
## and static resources (devices, rooms) from a manifest.
##
## Step 2: registry only. Populates on scene ready; nothing yet acquires
## resources. NpcManager still runs the current triage ping-pong loop.
## In Step 4 the Scheduler will call request()/release() around Sessions.

signal resource_registered(res)
signal resource_state_changed(res_id: String)

# resource_id → MedicalResource
var _resources: Dictionary = {}
# npc_id → resource_id  (reverse lookup for staff-backed resources)
var _npc_to_resource: Dictionary = {}


# ══════════════════════════════════════════════════════════════════════
#  Manifest of static resources (devices + rooms).
#  Staff resources are added dynamically from NpcManager.
# ══════════════════════════════════════════════════════════════════════

const STATIC_MANIFEST: Array = [
	# Rooms (map to named locations in HospitalMapData)
	{"id": "room_triage", "kind": "room", "name": "分诊台", "role": "triage_room", "location": "TRIAGE"},
	{"id": "room_resus", "kind": "room", "name": "抢救室", "role": "resus_bay", "location": "ED_RESUS"},
	{"id": "room_doctor", "kind": "room", "name": "医生诊室", "role": "exam_room", "location": "DOCTOR"},

	# Devices (planned floors 2-3; safe to register even if not yet in current scene)
	{"id": "device_ct", "kind": "device", "name": "CT机", "role": "ct_scanner", "location": "IMAGING"},
	{"id": "device_lab", "kind": "device", "name": "化验分析仪", "role": "lab_analyzer", "location": "LAB"},
	{"id": "device_ecg", "kind": "device", "name": "心电监护", "role": "ecg_monitor", "location": "ED_RESUS"},
]


# ══════════════════════════════════════════════════════════════════════
#  Lifecycle
# ══════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Register static resources immediately.
	for entry in STATIC_MANIFEST:
		_register_static(entry)

	# Wait one frame so NpcManager finishes its auto-discovery,
	# then register each staff NPC as a resource.
	await get_tree().process_frame
	await get_tree().process_frame
	_sync_staff_from_npc_manager()
	var mgr: Node = get_node_or_null("/root/NpcManager")
	if mgr and not mgr.npc_registered.is_connected(_on_npc_registered):
		mgr.npc_registered.connect(_on_npc_registered)
	print("[ResourceRegistry] Ready with %d resources:" % _resources.size())
	print_status()


func _register_static(entry: Dictionary) -> void:
	var id: String = entry.get("id", "")
	if id.is_empty() or _resources.has(id):
		return
	var res: MedicalResource = MedicalResource.new(
		id,
		entry.get("kind", ""),
		entry.get("name", id),
		entry.get("role", ""),
		entry.get("location", ""),
	)
	_wire_resource_signals(res)
	_resources[id] = res
	resource_registered.emit(res)


func _sync_staff_from_npc_manager() -> void:
	# NpcManager is an autoload; snapshot its status dict for reliable
	# npc_id → node lookup.
	var mgr: Node = get_node_or_null("/root/NpcManager")
	if not mgr or not mgr.has_method("get_status") or not mgr.has_method("get_npc"):
		return

	var status: Dictionary = mgr.get_status()
	for npc_id in status:
		var role: String = status[npc_id].get("role", "")
		if role != "nurse" and role != "doctor":
			continue
		var npc: Object = mgr.get_npc(npc_id)
		if npc:
			_register_staff(npc_id, npc, role)


func _register_staff(npc_id: String, npc: Object, role: String) -> void:
	var res_id: String = "staff_" + npc_id
	if _resources.has(res_id):
		return

	var display_name: String = npc_id
	if npc.has_method("get_npc_name"):
		display_name = npc.get_npc_name()

	var location: String = ""
	if npc is Node2D:
		location = HospitalMapData.get_location_name((npc as Node2D).global_position)

	var res: MedicalResource = MedicalResource.new(res_id, MedicalResource.KIND_STAFF, display_name, role, location)
	_wire_resource_signals(res)
	_resources[res_id] = res
	_npc_to_resource[npc_id] = res_id
	resource_registered.emit(res)
	print("[ResourceRegistry] Registered staff %s role=%s" % [res_id, role])


func _on_npc_registered(npc_id: String, npc: BaseNpc) -> void:
	var mgr: Node = get_node_or_null("/root/NpcManager")
	if not mgr or not mgr.has_method("get_role"):
		return
	var role: String = mgr.get_role(npc_id)
	if role == "nurse" or role == "doctor":
		_register_staff(npc_id, npc, role)


func _wire_resource_signals(res: MedicalResource) -> void:
	res.occupied.connect(func(_pid): resource_state_changed.emit(res.id))
	res.released.connect(func(): resource_state_changed.emit(res.id))
	res.queue_changed.connect(func(): resource_state_changed.emit(res.id))


# ══════════════════════════════════════════════════════════════════════
#  Public queries
# ══════════════════════════════════════════════════════════════════════

func get_resource(res_id: String) -> MedicalResource:
	return _resources.get(res_id, null)


func get_resource_for_npc(npc_id: String) -> MedicalResource:
	var rid: String = _npc_to_resource.get(npc_id, "")
	if rid.is_empty():
		return null
	return _resources.get(rid, null)


func get_all() -> Array:
	return _resources.values()


func get_by_kind(kind: String) -> Array:
	var result: Array = []
	for r in _resources.values():
		if r.kind == kind:
			result.append(r)
	return result


func get_by_role(role: String) -> Array:
	var result: Array = []
	for r in _resources.values():
		if r.role == role:
			result.append(r)
	return result


## Find the first idle resource matching a role, or null.
func find_idle_by_role(role: String) -> MedicalResource:
	for r in _resources.values():
		if r.role == role and not r.is_busy():
			return r
	return null


## Find any resource matching a role (busy or not) — for queueing.
func find_by_role(role: String) -> MedicalResource:
	var matches: Array = get_by_role(role)
	if matches.is_empty():
		return null
	return matches[0]


func print_status() -> void:
	print("=== Resource Registry ===")
	for r in _resources.values():
		var occ: String = r.occupant_id if r.is_busy() else "(idle)"
		print("  %s [%s/%s] @%s occ=%s queue=%d" % [
			r.id, r.kind, r.role, r.location, occ, r.queue_size()
		])
	print("=========================")
