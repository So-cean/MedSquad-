extends Node

## NpcManager — God-view manager for all NPCs in the scene.
##
## Responsibilities:
##   - Track all NPCs (npc_id → BaseNpc node)
##   - Dynamically add patients/doctors (event-triggered)
##   - Handle patient discharge (remove from scene)
##   - Emit events: patient_arrived, patient_discharged, npc_registered
##
## Usage:
##   NpcManager.spawn_patient("patient_003", symptom_data)
##   NpcManager.discharge("patient_001")

signal npc_registered(npc_id: String, npc: BaseNpc)
signal npc_removed(npc_id: String)
signal patient_arrived(npc_id: String, npc: BaseNpc)
signal patient_discharged(npc_id: String)

# npc_id → BaseNpc
var _npcs: Dictionary = {}
# Auto-incrementing ID counter for spawned patients
var _patient_counter: int = 0
var _nurse_counter: int = 0
var _doctor_counter: int = 0

# Patient templates for spawning
const PATIENT_FRAMES := [
	"res://assets/patient_blue_frames/",
	"res://assets/patient_green_frames/",
]


func register(npc_id: String, npc: BaseNpc) -> void:
	if _npcs.has(npc_id):
		return
	_npcs[npc_id] = npc
	npc_registered.emit(npc_id, npc)
	print("[NpcManager] Registered %s (%s)" % [npc_id, npc.get_npc_name()])


func unregister(npc_id: String) -> void:
	if not _npcs.has(npc_id):
		return
	var npc: BaseNpc = _npcs[npc_id]
	_npcs.erase(npc_id)
	npc_removed.emit(npc_id)
	if npc.get_npc_group() == "patients" or "Patient" in npc.name:
		patient_discharged.emit(npc_id)
	print("[NpcManager] Removed %s" % npc_id)


func get_npc(npc_id: String) -> BaseNpc:
	return _npcs.get(npc_id) as BaseNpc


func get_all_npcs() -> Array:
	return _npcs.values()


func get_npcs_by_role(role: String) -> Array:
	var result: Array = []
	for npc_id in _npcs:
		var npc: BaseNpc = _npcs[npc_id]
		if npc.has_method("get_role") and npc.get_role() == role:
			result.append(npc)
	return result


## Spawn a new patient dynamically. Returns npc_id.
func spawn_patient(display_name: String, knowledge: Array, spawn_pos: Vector2 = Vector2.ZERO) -> String:
	_patient_counter += 1
	var npc_id: String = "patient_%03d" % _patient_counter

	# Create scene node
	var npc: CharacterBody2D = CharacterBody2D.new()
	npc.name = "NPC_Patient_%d" % _patient_counter
	npc.position = spawn_pos if spawn_pos != Vector2.ZERO else HospitalMapData.get_location("ED_ENTRANCE")
	npc.scale = Vector2(2.5, 2.5)
	npc.collision_layer = 2
	npc.collision_mask = 3

	# Attach MapNpc script
	var script: GDScript = load("res://scripts/edmas/map_npc.gd")
	npc.set_script(script)
	npc.npc_display_name = display_name
	npc.npc_frames_dir = PATIENT_FRAMES[(_patient_counter - 1) % PATIENT_FRAMES.size()]

	# Add sprite
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	npc.add_child(sprite)

	# Add to scene tree (current scene root)
	var root: Node = get_tree().current_scene
	if root:
		root.add_child(npc)

	# Register with manager
	register(npc_id, npc)
	patient_arrived.emit(npc_id, npc)

	print("[NpcManager] Spawned patient %s: %s at %s" % [npc_id, display_name, npc.position])
	return npc_id


## Discharge a patient — remove from scene.
func discharge(npc_id: String) -> void:
	var npc: BaseNpc = _npcs.get(npc_id) as BaseNpc
	if not npc:
		push_warning("[NpcManager] Cannot discharge unknown NPC: %s" % npc_id)
		return

	# Stop any active dialogue
	npc.stop_speaking()

	# Unregister from DialogueManager
	DialogueManager.unregister(npc)

	# Remove from tracking
	_npcs.erase(npc_id)
	npc_removed.emit(npc_id)
	patient_discharged.emit(npc_id)

	# Queue free the node
	npc.queue_free()

	print("[NpcManager] Discharged %s" % npc_id)


## Get a summary of all NPCs for debugging.
func get_status() -> Dictionary:
	var summary: Dictionary = {}
	for npc_id in _npcs:
		var npc: BaseNpc = _npcs[npc_id]
		summary[npc_id] = {
			name = npc.get_npc_name(),
			position = npc.global_position,
			location = HospitalMapData.get_location_name(npc.global_position),
		}
	return summary


## Auto-discover NPCs in scene on _ready (for static scene NPCs).
func _ready() -> void:
	# Wait one frame for scene to be ready
	await get_tree().process_frame
	for node in get_tree().get_nodes_in_group("npcs"):
		if node is BaseNpc:
			var npc_id: String = _infer_npc_id(node)
			if not npc_id.is_empty():
				register(npc_id, node)


func _infer_npc_id(npc: BaseNpc) -> String:
	var nm: String = npc.name
	if "TriageNurse" in nm or "Nurse" in nm:
		return "nurse_001"
	elif "Patient1" in nm or "Patient" in nm:
		var idx: int = 1
		if "2" in nm: idx = 2
		elif "3" in nm: idx = 3
		return "patient_%03d" % idx
	elif "Doctor" in nm or "Surgeon" in nm:
		return "doctor_001"
	return ""
