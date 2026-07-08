extends Node

## NpcManager — God-view autonomous NPC orchestration system.
##
## Owns:
##   - All NPCs (npc_id → BaseNpc)
##   - ConversationContext (multi-party dialogue)
##   - NPC_FSM (stateless LLM caller)
##   - Event bus (patient_arrived / triage_done / exam_done / discharged)
##   - Autonomous dialogue loop (no manual ticking needed)
##   - Autonomous movement (triage_done → walk_to target room)
##
## Player is NOT an NPC. Player is controlled by the user.
## NPCs are fully autonomous: they talk, move, and interact on their own.

# ══════════════════════════════════════════════════════════════════════
#  Signals (Event Bus)
# ══════════════════════════════════════════════════════════════════════

signal npc_registered(npc_id: String, npc: BaseNpc)
signal npc_removed(npc_id: String)
signal patient_arrived(npc_id: String, npc: BaseNpc)
signal patient_discharged(npc_id: String)
signal triage_started(npc_id: String)
signal triage_done(npc_id: String, target_room: String)
signal npc_arrived_at(npc_id: String, location: String)
signal all_triage_done()

# ══════════════════════════════════════════════════════════════════════
#  State
# ══════════════════════════════════════════════════════════════════════

var _npcs: Dictionary = {}  # npc_id → BaseNpc
var _fsm: Node = null
var _ctx: ConversationContext = null

# Dialogue pipeline state
var _response_queue: Array = []
var _displaying: bool = false
var _turn_id: int = 0
var _current_patient: String = ""
var _auto_mode: bool = false  # autonomous dialogue loop running?

# NPC data (role + knowledge for prompt building)
var _npc_data: Dictionary = {}  # npc_id → {role, knowledge}

# Counters
var _patient_counter: int = 0
const PATIENT_FRAMES: Array[String] = [
	"res://assets/patient_blue_frames/",
	"res://assets/patient_green_frames/",
]

# Patient symptom pool for random spawning
const PATIENT_POOL: Array = [
	{"主诉": "头痛", "症状": "前额胀痛,恶心畏光", "持续时间": "三天"},
	{"主诉": "腹痛", "症状": "右下腹按压痛,低热", "持续时间": "半天"},
	{"主诉": "胸痛", "症状": "胸口闷痛,出汗", "持续时间": "一小时"},
	{"主诉": "外伤", "症状": "手臂割伤,出血", "持续时间": "刚发生"},
	{"主诉": "发热", "症状": "38.5度,全身酸痛", "持续时间": "两天"},
]

# Display timing constants
const TYPEWRITER_INTERVAL: float = 0.04
const THINK_PAUSE: float = 0.5
const FADE_DURATION: float = 0.25
const CHARS_PER_SEC: float = 10.0
const MIN_UTT_TIME: float = 1.5
const SAFETY_TIMEOUT: float = 15.0


# ══════════════════════════════════════════════════════════════════════
#  Lifecycle
# ══════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Create FSM (stateless LLM caller)
	_fsm = load("res://scripts/edmas/npc_fsm.gd").new()
	_fsm.name = "NPC_FSM"
	add_child(_fsm)
	_fsm.action_ready.connect(_on_action_ready)

	# Create ConversationContext
	_ctx = ConversationContext.new(_fsm)
	_ctx.response_received.connect(_on_response_routed)
	_ctx.conversation_done.connect(_on_conversation_done)

	# Auto-discover NPCs in scene after one frame
	await get_tree().process_frame
	for node in get_tree().get_nodes_in_group("npcs"):
		if node is BaseNpc:
			var npc_id: String = _infer_npc_id(node)
			if not npc_id.is_empty():
				_auto_register(npc_id, node)

	print("[NpcManager] Ready, %d NPCs registered" % _npcs.size())


# ══════════════════════════════════════════════════════════════════════
#  Registration
# ══════════════════════════════════════════════════════════════════════

func register_npc(npc_id: String, npc: BaseNpc, role: String, knowledge: Array) -> void:
	if _npcs.has(npc_id):
		return
	_npcs[npc_id] = npc
	_npc_data[npc_id] = {"role": role, "knowledge": knowledge}
	_ctx.register(npc_id, npc, role, knowledge)
	npc_registered.emit(npc_id, npc)
	if role == "patient":
		patient_arrived.emit(npc_id, npc)
	print("[NpcManager] %s registered as %s (%s)" % [npc_id, role, npc.get_npc_name()])


func _auto_register(npc_id: String, npc: BaseNpc) -> void:
	var role: String = "patient"
	var knowledge: Array = []
	if "Nurse" in npc.name:
		role = "nurse"
		knowledge = [
			{"condition": "头痛", "triage": "3级-急症"},
			{"condition": "发热38.5℃", "triage": "3级-急症"},
			{"condition": "腹痛", "triage": "2级-危重"},
			{"condition": "胸痛", "triage": "1级-即刻"},
		]
	elif "Doctor" in npc.name or "Surgeon" in npc.name:
		role = "doctor"
	else:
		# Patient — assign random symptoms if not already set
		var idx: int = (_patient_counter % PATIENT_POOL.size())
		knowledge = [PATIENT_POOL[idx]]
		_patient_counter += 1
	register_npc(npc_id, npc, role, knowledge)


func unregister(npc_id: String) -> void:
	if not _npcs.has(npc_id):
		return
	var npc: BaseNpc = _npcs[npc_id]
	npc.stop_speaking()
	DialogueManager.unregister(npc)
	_npcs.erase(npc_id)
	_npc_data.erase(npc_id)
	npc_removed.emit(npc_id)
	if _npc_data.get(npc_id, {}).get("role", "") == "patient":
		patient_discharged.emit(npc_id)
	npc.queue_free()


# ══════════════════════════════════════════════════════════════════════
#  Dynamic patient spawning
# ══════════════════════════════════════════════════════════════════════

func spawn_patient(display_name: String, knowledge: Array, spawn_pos: Vector2 = Vector2.ZERO) -> String:
	_patient_counter += 1
	var npc_id: String = "patient_%03d" % _patient_counter

	var npc: CharacterBody2D = CharacterBody2D.new()
	npc.name = "NPC_Patient_%d" % _patient_counter
	npc.position = spawn_pos if spawn_pos != Vector2.ZERO else HospitalMapData.get_location("ED_ENTRANCE")
	npc.scale = Vector2(2.5, 2.5)
	npc.collision_layer = 2
	npc.collision_mask = 3

	var script: GDScript = load("res://scripts/edmas/map_npc.gd")
	npc.set_script(script)
	npc.npc_display_name = display_name
	npc.npc_frames_dir = PATIENT_FRAMES[(_patient_counter - 1) % PATIENT_FRAMES.size()]

	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	npc.add_child(sprite)

	var root: Node = get_tree().current_scene
	if root:
		root.add_child(npc)

	# Wait for _ready to run
	await get_tree().process_frame

	register_npc(npc_id, npc, "patient", knowledge)
	return npc_id


func spawn_random_patient() -> String:
	var idx: int = randi() % PATIENT_POOL.size()
	var data: Dictionary = PATIENT_POOL[idx]
	return await spawn_patient(str(data["主诉"], "患者"), [data])


func discharge(npc_id: String) -> void:
	var npc: BaseNpc = _npcs.get(npc_id) as BaseNpc
	if not npc:
		return
	npc.set_state(BaseNpc.NpcState.DISCHARGED)
	unregister(npc_id)
	print("[NpcManager] Discharged %s" % npc_id)


# ══════════════════════════════════════════════════════════════════════
#  Autonomous dialogue loop
# ══════════════════════════════════════════════════════════════════════

func start_auto_loop() -> void:
	if _auto_mode:
		return
	_auto_mode = true
	print("[NpcManager] Auto loop started")
	_start_next_triage()


func stop_auto_loop() -> void:
	_auto_mode = false
	_turn_id += 1  # invalidate pending timers


func _start_next_triage() -> void:
	if not _auto_mode:
		return
	_current_patient = _ctx.get_next_undone_patient()
	if _current_patient.is_empty():
		all_triage_done.emit()
		print("[NpcManager] All triage done")
		_auto_mode = false
		return
	_ctx.set_active_patient(_current_patient)
	triage_started.emit(_current_patient)
	print("\n[NpcManager] === Triage %s ===" % _current_patient)
	
	# Patient walks to nurse first, then dialogue starts
	var patient_npc: BaseNpc = _npcs.get(_current_patient) as BaseNpc
	var nurse_npc: BaseNpc = _npcs.get("nurse_001") as BaseNpc
	if patient_npc and nurse_npc:
		# Check if already near nurse
		var dist: float = patient_npc.global_position.distance_to(nurse_npc.global_position)
		if dist > 80.0:
			print("[NpcManager] %s walking to nurse (%.0fpx away)..." % [_current_patient, dist])
			patient_npc.approach_and_face(nurse_npc, 60.0)
			# Wait for arrival
			await _wait_for_arrival(patient_npc, 15.0)
		# Face each other
		patient_npc.face_toward(nurse_npc.global_position)
		nurse_npc.face_toward(patient_npc.global_position)
	
	# Now start dialogue
	_fire_llm(_current_patient)
	_start_safety_timer()


func _wait_for_arrival(npc: BaseNpc, timeout: float) -> void:
	var elapsed: float = 0.0
	while npc.is_walking() and elapsed < timeout:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if npc.is_walking():
		print("[NpcManager] %s arrival timeout, forcing stop" % npc.get_npc_name())
		npc._is_walking = false


func _fire_llm(npc_id: String) -> void:
	_turn_id += 1
	_ctx.tick(npc_id)


func _on_action_ready(npc_id: String, action: Dictionary) -> void:
	_response_queue.append({"npc_id": npc_id, "action": action})
	_try_process_queue()


func _try_process_queue() -> void:
	if _displaying or _response_queue.is_empty():
		return

	var item: Dictionary = _response_queue.pop_front()
	var npc_id: String = item["npc_id"]
	var action: Dictionary = item["action"]

	var think: String = action.get("think", "")
	var responses: Array = action.get("responses", [])
	var utts: Array = action.get("utterances", [])

	print("[NpcManager] [%s] think=%s" % [npc_id, think])
	if responses.size() > 0:
		for r in responses:
			var t: String = r.get("target", "?")
			var ru: Array = r.get("utterances", [])
			var done: bool = r.get("conversation_done", false)
			print("[NpcManager]   → %s: %s (done=%s)" % [t, str(ru), done])
	else:
		print("[NpcManager]   utterances: %s" % str(utts))

	var next_step: Variant = action.get("next_step", null)
	if next_step is Dictionary:
		print("[NpcManager]   next_step=%s" % str(next_step))

	_ctx.on_response(npc_id, action)
	_display(npc_id, action)

	# Pipeline: fire next LLM immediately (may await for patient to walk to nurse)
	var next_npc: String = await _get_next_speaker(npc_id, action)
	if not next_npc.is_empty():
		_fire_llm(next_npc)

	# Wait for display to finish (sequential)
	_displaying = true
	_wait_display(npc_id, action)


func _wait_display(npc_id: String, action: Dictionary) -> void:
	var my_turn: int = _turn_id
	var think: String = action.get("think", "")
	var responses: Array = action.get("responses", [])
	var utts: Array = action.get("utterances", [])

	var all_utts: Array = utts
	if responses.size() > 0:
		all_utts = []
		for r in responses:
			var ru: Array = r.get("utterances", [])
			for u in ru:
				all_utts.append(u)

	var think_time: float = 0.0
	if not think.is_empty():
		think_time = think.length() * TYPEWRITER_INTERVAL + THINK_PAUSE + FADE_DURATION

	var utt_time: float = 0.0
	for u in all_utts:
		utt_time += maxf(float(str(u).length()) / CHARS_PER_SEC, MIN_UTT_TIME)

	var est_time: float = think_time + utt_time
	await get_tree().create_timer(est_time).timeout

	if my_turn != _turn_id:
		return
	_displaying = false

	if not _response_queue.is_empty():
		_try_process_queue()
	elif _auto_mode and _ctx.all_conversations_done():
		all_triage_done.emit()
		_auto_mode = false
		print("[NpcManager] All triage done")


func _get_next_speaker(current_npc: String, action: Dictionary) -> String:
	if current_npc == "nurse_001":
		var responses: Array = action.get("responses", [])
		var conv_done: bool = false
		var target_room: String = ""
		for r in responses:
			if r.get("conversation_done", false):
				conv_done = true
				break

		if conv_done:
			# Patient's triage is done — walk to target room, then mark complete
			var done_npc: BaseNpc = _npcs.get(_current_patient) as BaseNpc
			if done_npc:
				done_npc.stop_speaking()
				# Determine target room from nurse's instruction
				target_room = _extract_target_room(action)
				triage_done.emit(_current_patient, target_room)
				if not target_room.is_empty():
					# Patient walks to target room
					print("[NpcManager] %s walking to %s..." % [_current_patient, target_room])
					done_npc.set_state(BaseNpc.NpcState.GOING_TO_ROOM, target_room)
					# Don't wait here — pipeline continues, patient moves in background
				else:
					done_npc.set_state(BaseNpc.NpcState.WAITING)
			
			# Nurse faces next patient (will be set when they approach)
			var next_p: String = _ctx.get_next_undone_patient()
			if next_p.is_empty():
				return ""
			_current_patient = next_p
			_ctx.set_active_patient(_current_patient)
			triage_started.emit(_current_patient)
			print("\n[NpcManager] === Triage %s ===" % _current_patient)
			
			# Next patient walks to nurse
			var next_patient_npc: BaseNpc = _npcs.get(_current_patient) as BaseNpc
			var nurse_npc2: BaseNpc = _npcs.get("nurse_001") as BaseNpc
			if next_patient_npc and nurse_npc2:
				var dist2: float = next_patient_npc.global_position.distance_to(nurse_npc2.global_position)
				if dist2 > 80.0:
					print("[NpcManager] %s walking to nurse..." % _current_patient)
					next_patient_npc.approach_and_face(nurse_npc2, 60.0)
					await _wait_for_arrival(next_patient_npc, 15.0)
				next_patient_npc.face_toward(nurse_npc2.global_position)
				nurse_npc2.face_toward(next_patient_npc.global_position)
			
			return _current_patient
		else:
			return _current_patient
	else:
		return "nurse_001"


const VALID_ROOMS: Array[String] = [
	"ED_RESUS", "DOCTOR", "WAITING_AREA", "IMAGING", "LAB",
]


func _extract_target_room(action: Dictionary) -> String:
	# Primary: structured next_step from the nurse LLM response.
	var next_step: Variant = action.get("next_step", null)
	if next_step is Dictionary:
		var room: String = str((next_step as Dictionary).get("target_room", "")).strip_edges()
		if room in VALID_ROOMS:
			return room
		if not room.is_empty():
			push_warning("[NpcManager] Nurse returned unknown target_room=%s, falling back to keyword grep" % room)

	# Fallback: legacy keyword scan over utterances. Kept so an older LLM
	# response format (missing next_step) still routes patients correctly.
	var responses: Array = action.get("responses", [])
	for r in responses:
		var utts: Array = r.get("utterances", [])
		for u in utts:
			var text: String = str(u)
			if "抢救" in text:
				return "ED_RESUS"
			if "候诊" in text or "等候" in text:
				return "WAITING_AREA"
			if "CT" in text or "影像" in text:
				return "IMAGING"
			if "检验" in text or "抽血" in text or "化验" in text:
				return "LAB"
			if "诊室" in text or "医生" in text:
				return "DOCTOR"
	return ""


func _start_safety_timer() -> void:
	var my_turn: int = _turn_id
	await get_tree().create_timer(SAFETY_TIMEOUT).timeout
	if my_turn != _turn_id:
		return
	if not _response_queue.is_empty() or _displaying:
		return
	print("[NpcManager] Safety timeout (%.0fs)" % SAFETY_TIMEOUT)
	if _auto_mode:
		var next: String = _ctx.get_next_undone_patient()
		if not next.is_empty():
			_current_patient = next
			_ctx.set_active_patient(_current_patient)
			_fire_llm(next)
	_start_safety_timer()


# ══════════════════════════════════════════════════════════════════════
#  Callbacks
# ══════════════════════════════════════════════════════════════════════

func _on_response_routed(_npc_id: String, _action: Dictionary) -> void:
	pass


func _on_conversation_done(patient_id: String) -> void:
	print("[NpcManager] ✓ %s triage conversation done" % patient_id)


# ══════════════════════════════════════════════════════════════════════
#  Display
# ══════════════════════════════════════════════════════════════════════

func _display(npc_id: String, action: Dictionary) -> void:
	var npc: BaseNpc = _npcs.get(npc_id) as BaseNpc
	if not npc:
		return
	var responses: Array = action.get("responses", [])
	var think: String = action.get("think", "")
	if npc_id == "nurse_001" and responses.size() > 0:
		var all_utts: Array = []
		for r in responses:
			var ru: Array = r.get("utterances", [])
			for u in ru:
				all_utts.append(u)
		if not all_utts.is_empty():
			npc.speak(DialogueEntry.new(npc.get_npc_name(), think, "", "", all_utts))
	else:
		var u: Array = action.get("utterances", [])
		var d: String = action.get("dialogue", "")
		if u.is_empty() and not d.is_empty():
			u = [d]
		if u.is_empty():
			u = ["..."]
		npc.speak(DialogueEntry.new(npc.get_npc_name(), think, "", "", u))


# ══════════════════════════════════════════════════════════════════════
#  Queries (global status dashboard)
# ══════════════════════════════════════════════════════════════════════

func get_npc(npc_id: String) -> BaseNpc:
	return _npcs.get(npc_id) as BaseNpc


func get_all_npcs() -> Array:
	return _npcs.values()


func get_npcs_by_role(role: String) -> Array:
	var result: Array = []
	for npc_id in _npc_data:
		if _npc_data[npc_id].get("role") == role:
			var npc: BaseNpc = _npcs.get(npc_id) as BaseNpc
			if npc:
				result.append(npc)
	return result


func get_active_patient() -> String:
	return _current_patient


func get_status() -> Dictionary:
	var summary: Dictionary = {}
	for npc_id in _npcs:
		var npc: BaseNpc = _npcs[npc_id]
		var role: String = _npc_data.get(npc_id, {}).get("role", "?")
		summary[npc_id] = {
			name = npc.get_npc_name(),
			role = role,
			state = npc.get_state_name(),
			position = npc.global_position,
			location = HospitalMapData.get_location_name(npc.global_position),
			triage_done = _ctx.is_conversation_done(npc_id) if role == "patient" else false,
		}
	return summary


func print_status() -> void:
	var s: Dictionary = get_status()
	print("\n=== NPC Status ===")
	for npc_id in s:
		var d: Dictionary = s[npc_id]
		print("  %s: %s [%s] @ %s (triage=%s)" % [
			npc_id, d.name, d.state, d.location, d.triage_done
		])
	print("==================\n")


# ══════════════════════════════════════════════════════════════════════
#  NPC ID inference from node name
# ══════════════════════════════════════════════════════════════════════

func _infer_npc_id(npc: BaseNpc) -> String:
	var nm: String = npc.name
	if "Nurse" in nm:
		return "nurse_001"
	elif "Patient" in nm:
		var idx: int = 1
		if "2" in nm: idx = 2
		elif "3" in nm: idx = 3
		elif "4" in nm: idx = 4
		elif "5" in nm: idx = 5
		return "patient_%03d" % idx
	elif "Doctor" in nm or "Surgeon" in nm:
		return "doctor_001"
	return ""
