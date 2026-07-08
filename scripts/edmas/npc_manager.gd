extends Node

signal npc_registered(npc_id: String, npc: BaseNpc)
signal npc_removed(npc_id: String)
signal patient_arrived(npc_id: String, npc: BaseNpc)
signal patient_discharged(npc_id: String)
signal triage_started(npc_id: String)
signal triage_done(npc_id: String, target_room: String)
signal npc_arrived_at(npc_id: String, location: String)
signal all_triage_done()

var _npcs: Dictionary = {}
var _npc_to_id: Dictionary = {}
var _npc_data: Dictionary = {}
var _fsm: Node = null
var _ctx: ConversationContext = null

var _patient_counter: int = 0
var _nurse_counter: int = 0
var _doctor_counter: int = 0

const PATIENT_FRAMES: Array[String] = [
	"res://assets/patient_blue_frames/",
	"res://assets/patient_green_frames/",
]


func _ready() -> void:
	_fsm = load("res://scripts/edmas/npc_fsm.gd").new()
	_fsm.name = "NPC_FSM"
	add_child(_fsm)
	_ctx = ConversationContext.new(_fsm)

	await get_tree().process_frame
	for node in get_tree().get_nodes_in_group("npcs"):
		if node is BaseNpc:
			var npc_id: String = _infer_npc_id(node)
			if not npc_id.is_empty():
				_auto_register(npc_id, node)

	print("[NpcManager] Ready, %d NPCs registered" % _npcs.size())


func register_npc(npc_id: String, npc: BaseNpc, role: String, knowledge: Array) -> void:
	if _npcs.has(npc_id):
		return
	_npcs[npc_id] = npc
	_npc_to_id[npc] = npc_id
	_npc_data[npc_id] = {"role": role, "knowledge": knowledge}
	npc.reset_memory()
	_ctx.register(npc_id, npc, role, knowledge)
	npc_registered.emit(npc_id, npc)
	if role == "patient":
		patient_arrived.emit(npc_id, npc)
	print("[NpcManager] %s registered as %s (%s)" % [npc_id, role, npc.get_npc_name()])


func unregister(npc_id: String) -> void:
	if not _npcs.has(npc_id):
		return
	var role: String = get_role(npc_id)
	var npc: BaseNpc = _npcs[npc_id]
	npc.stop_speaking()
	DialogueManager.unregister(npc)
	_npcs.erase(npc_id)
	_npc_to_id.erase(npc)
	_npc_data.erase(npc_id)
	_ctx.unregister(npc_id)
	npc_removed.emit(npc_id)
	if role == "patient":
		patient_discharged.emit(npc_id)
	npc.queue_free()


func spawn_scenario(config: Dictionary) -> void:
	var nurse_names: Array = config.get("nurse_names", [])
	var nurse_positions: Array = config.get("nurse_positions", [])
	for i in range(int(config.get("triage_nurses", 0))):
		var name: String = str(nurse_names[i]) if i < nurse_names.size() else "分诊护士%d" % (i + 1)
		var pos: Vector2 = nurse_positions[i] if i < nurse_positions.size() else HospitalMapData.get_location("TRIAGE") + Vector2(i * 50, 0)
		await spawn_nurse(name, pos, ScenarioConfig.NURSE_FRAMES)

	var doctor_names: Array = config.get("doctor_names", [])
	var doctor_positions: Array = config.get("doctor_positions", [])
	for i in range(int(config.get("doctors", 0))):
		var name: String = str(doctor_names[i]) if i < doctor_names.size() else "医生%d" % (i + 1)
		var pos: Vector2 = doctor_positions[i] if i < doctor_positions.size() else HospitalMapData.get_location("DOCTOR") + Vector2(i * 60, 0)
		await spawn_doctor(name, pos, ScenarioConfig.DOCTOR_FRAMES)

	var patient_pool: Array = config.get("patient_pool", [])
	for i in range(int(config.get("patients", 0))):
		var data: Dictionary = patient_pool[i % patient_pool.size()] if not patient_pool.is_empty() else {"主诉": "不舒服", "症状": "描述不清", "持续时间": "今天"}
		await spawn_patient("患者%03d" % (i + 1), [data], HospitalMapData.get_location("ED_ENTRANCE") + Vector2((i % 3) * 45 - 45, int(i / 3) * 45))
	if ResourceRegistry and ResourceRegistry.has_method("print_status"):
		ResourceRegistry.print_status()


func spawn_patient(display_name: String, knowledge: Array, spawn_pos: Vector2 = Vector2.ZERO) -> String:
	_patient_counter += 1
	var npc_id: String = "patient_%03d" % _patient_counter
	var npc: BaseNpc = _create_map_npc(
		"NPC_Patient_%03d" % _patient_counter,
		display_name,
		PATIENT_FRAMES[(_patient_counter - 1) % PATIENT_FRAMES.size()],
		spawn_pos if spawn_pos != Vector2.ZERO else HospitalMapData.get_location("ED_ENTRANCE"),
		["up", "down"],
	)
	await get_tree().process_frame
	register_npc(npc_id, npc, "patient", knowledge)
	print("[NpcManager] Spawned patient %s: %s" % [npc_id, display_name])
	return npc_id


func spawn_nurse(display_name: String, spawn_pos: Vector2, frames_dir: String) -> String:
	_nurse_counter += 1
	var npc_id: String = "nurse_%03d" % _nurse_counter
	var npc: BaseNpc = _create_map_npc("NPC_Nurse_%03d" % _nurse_counter, display_name, frames_dir, spawn_pos)
	await get_tree().process_frame
	register_npc(npc_id, npc, "nurse", [{"role": "triage_nurse"}])
	print("[NpcManager] Spawned nurse %s: %s at %s" % [npc_id, display_name, str(spawn_pos)])
	return npc_id


func spawn_doctor(display_name: String, spawn_pos: Vector2, frames_dir: String) -> String:
	_doctor_counter += 1
	var npc_id: String = "doctor_%03d" % _doctor_counter
	var npc: BaseNpc = _create_map_npc("NPC_Doctor_%03d" % _doctor_counter, display_name, frames_dir, spawn_pos)
	await get_tree().process_frame
	register_npc(npc_id, npc, "doctor", [{"role": "doctor"}])
	print("[NpcManager] Spawned doctor %s: %s at %s" % [npc_id, display_name, str(spawn_pos)])
	return npc_id


func _create_map_npc(node_name: String, display_name: String, frames_dir: String, spawn_pos: Vector2, walk_flip: Array[String] = []) -> BaseNpc:
	var npc = CharacterBody2D.new()
	npc.name = node_name
	npc.position = spawn_pos
	npc.scale = Vector2(2.5, 2.5)
	npc.collision_layer = 2
	npc.collision_mask = 3
	npc.set_script(load("res://scripts/edmas/map_npc.gd"))
	npc.npc_display_name = display_name
	npc.npc_frames_dir = frames_dir
	npc.npc_walk_flip = walk_flip

	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	npc.add_child(sprite)

	var root: Node = get_tree().current_scene
	if root:
		root.add_child(npc)
	return npc as BaseNpc


func discharge(npc_id: String) -> void:
	var npc: BaseNpc = get_npc(npc_id)
	if not npc:
		return
	npc.set_state(BaseNpc.NpcState.DISCHARGED)
	unregister(npc_id)
	print("[NpcManager] Discharged %s" % npc_id)


func get_fsm() -> Node:
	return _fsm


func get_context() -> ConversationContext:
	return _ctx


func get_npc(npc_id: String) -> BaseNpc:
	return _npcs.get(npc_id, null) as BaseNpc


func get_npc_id(npc: BaseNpc) -> String:
	return _npc_to_id.get(npc, "")


func get_all_npcs() -> Array:
	return _npcs.values()


func get_npcs_by_role(role: String) -> Array:
	var result: Array = []
	for npc_id in _npc_data:
		if get_role(npc_id) == role:
			result.append(_npcs[npc_id])
	return result


func get_role(npc_id: String) -> String:
	return str(_npc_data.get(npc_id, {}).get("role", ""))


func get_knowledge(npc_id: String) -> Array:
	return _npc_data.get(npc_id, {}).get("knowledge", [])


func get_status() -> Dictionary:
	var summary: Dictionary = {}
	for npc_id in _npcs:
		var npc: BaseNpc = _npcs[npc_id]
		summary[npc_id] = {
			"name": npc.get_npc_name(),
			"role": get_role(npc_id),
			"state": npc.get_state_name(),
			"position": npc.global_position,
			"location": HospitalMapData.get_location_name(npc.global_position),
			"triage_done": _ctx.is_conversation_done(npc_id) if get_role(npc_id) == "patient" else false,
		}
	return summary


func print_status() -> void:
	print("\n=== NPC Status ===")
	for npc_id in get_status():
		var d: Dictionary = get_status()[npc_id]
		print("  %s: %s [%s] @ %s role=%s" % [
			npc_id,
			d.get("name", ""),
			d.get("state", ""),
			d.get("location", ""),
			d.get("role", ""),
		])
	print("==================\n")


func _auto_register(npc_id: String, npc: BaseNpc) -> void:
	var role: String = "patient"
	if "Nurse" in npc.name:
		role = "nurse"
	elif "Doctor" in npc.name or "Surgeon" in npc.name:
		role = "doctor"
	register_npc(npc_id, npc, role, [])


func _infer_npc_id(npc: BaseNpc) -> String:
	var nm: String = npc.name
	if "Nurse" in nm:
		_nurse_counter += 1
		return "nurse_%03d" % _nurse_counter
	if "Doctor" in nm or "Surgeon" in nm:
		_doctor_counter += 1
		return "doctor_%03d" % _doctor_counter
	if "Patient" in nm:
		_patient_counter += 1
		return "patient_%03d" % _patient_counter
	return ""
