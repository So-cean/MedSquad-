class_name BaseNpc
extends CharacterBody2D

## Base class for all NPC characters.
##
## Handles:
##   - 8-direction wander movement + NavigationAgent2D pathfinding
##   - Code-generated SpriteFrames from per-direction PNGs
##   - DialogueEntry interface (think / dialogue)
##   - Auto-registration with DialogueManager + NpcManager
##   - NPC state machine (arrived → waiting → examined → discharged)

enum NpcState {
	ARRIVED,          # 刚到，还没跟护士说话
	WAITING,          # 护士让等着
	GOING_TO_ROOM,    # 正在走去某房间
	BEING_EXAMINED,   # 正在检查中
	DISCHARGED,       # 出院了
}
##
## Subclasses override:
##   get_frames_dir() → String          REQUIRED
##   get_npc_name()   → String          (default: "NPC")
##   get_walk_flip_dirs() → Array[String]  (default: [])
##   get_npc_group()  → String          (default: "npcs")

# ═══════════════════════════════════════════════════════════════════════
#  Exports (tweak per-instance in the editor)
# ═══════════════════════════════════════════════════════════════════════

@export var speed: float = 90.0
@export var idle_min: float = 2.0
@export var idle_max: float = 6.0
@export var move_min: float = 0.5
@export var move_max: float = 1.5
@export var can_wander: bool = false  # 默认不自由移动

# ═══════════════════════════════════════════════════════════════════════
#  Virtual overrides (subclasses MUST override get_frames_dir)
# ═══════════════════════════════════════════════════════════════════════

## Path to the per-direction PNG frame directory, e.g. "res://assets/nurse_frames/"
func get_frames_dir() -> String:
	return ""

## Display name shown in dialogue bubbles.
func get_npc_name() -> String:
	return "NPC"

## Directions whose walk animation uses walk_a→walk_b (flipped) instead of
## idle→walk_a. Override in subclass e.g. return ["up", "down"]
func get_walk_flip_dirs() -> Array[String]:
	return []

## Godot group name for auto-discovery by MockDialogueSystem.
func get_npc_group() -> String:
	return "npcs"

# ═══════════════════════════════════════════════════════════════════════
#  Direction constants (shared by all NPCs)
# ═══════════════════════════════════════════════════════════════════════

static var _dirs: Dictionary = {
	0: Vector2.DOWN,
	1: Vector2(0.707, 0.707),
	2: Vector2.RIGHT,
	3: Vector2(0.707, -0.707),
	4: Vector2.UP,
	5: Vector2(-0.707, -0.707),
	6: Vector2.LEFT,
	7: Vector2(-0.707, 0.707),
}

static var _dir_names: Array[String] = [
	"down", "down_right", "right", "up_right",
	"up", "up_left", "left", "down_left",
]

# ═══════════════════════════════════════════════════════════════════════
#  State
# ═══════════════════════════════════════════════════════════════════════

var _state: int = 0  # 0 = idle, 1 = walking
var _timer: float = 0.0
var _dir_idx: int = 0
var _anim: AnimatedSprite2D

# ── Dialogue ──
var _current_entry: DialogueEntry = null

# ── Memory ──
var _memory: MemoryStore = null

# ── NPC State ──
var _npc_state: int = NpcState.ARRIVED
var _state_target: String = ""  # 目标房间名 (e.g. "TRIAGE", "ED_RESUS")

# ── Navigation ──
var _nav_agent: NavigationAgent2D = null
var _is_walking: bool = false
var _walk_target: String = ""


# ═══════════════════════════════════════════════════════════════════════
#  Lifecycle
# ═══════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_anim = $AnimatedSprite2D as AnimatedSprite2D
	_build_frames()
	_anim.animation = "idle_down"
	_anim.frame = 0
	_pick_timer()

	# Register with DialogueManager (autoload singleton, always alive)
	DialogueManager.register(self)

	# Initialize memory store (use node name for unique file path)
	_memory = MemoryStore.new(name, get_npc_name())

	# Setup navigation agent (created lazily if needed)
	_ensure_nav_agent()

	# Add to discovery group
	add_to_group(get_npc_group())


func _exit_tree() -> void:
	DialogueManager.unregister(self)


# ═══════════════════════════════════════════════════════════════════════
#  Frame builder
# ═══════════════════════════════════════════════════════════════════════

func _build_frames() -> void:
	var frames_dir: String = get_frames_dir()
	var npc_tag: String = get_npc_name()
	if frames_dir.is_empty():
		push_error("BaseNpc: get_frames_dir() returned empty path for ", npc_tag)
		return

	var sf: SpriteFrames = SpriteFrames.new()
	var walk_flip: Array[String] = get_walk_flip_dirs()

	# ── Idle frames ──
	#       down direction uses a separate idle_down.png (standalone 32×32),
	#       all other orientations come from the 8-dir sheet.
	var idle_frames: Dictionary = {}
	for d: String in _dir_names:
		var path: String = frames_dir + ("idle_down.png" if d == "down" else "idle_%s.png" % d)
		var tex: Texture2D = load(path) as Texture2D
		if not tex:
			tex = _load_legacy_doctor_idle(frames_dir, d)
		if not tex:
			push_error("BaseNpc (%s): missing idle frame: %s" % [npc_tag, path])
			return
		idle_frames[d] = tex
		sf.add_animation("idle_" + d)
		sf.add_frame("idle_" + d, tex)

	# ── Walk frames ──
	for d: String in _dir_names:
		var path_a: String = frames_dir + "walk_%s_a.png" % d
		var tex_a: Texture2D = load(path_a) as Texture2D
		if not tex_a:
			tex_a = _load_legacy_doctor_walk(frames_dir, d, "a")
		if not tex_a:
			push_error("BaseNpc (%s): missing walk frame: %s" % [npc_tag, path_a])
			return

		var anim_name: String = "walk_" + d
		sf.add_animation(anim_name)

		if d in walk_flip:
			# UP / DOWN: walk_a → walk_b (alternating leg-forward poses)
			var path_b: String = frames_dir + "walk_%s_b.png" % d
			var tex_b: Texture2D = load(path_b) as Texture2D
			if not tex_b:
				tex_b = _load_legacy_doctor_walk(frames_dir, d, "b")
			if not tex_b:
				push_error("BaseNpc (%s): missing flipped walk frame: %s" % [npc_tag, path_b])
				return
			sf.add_frame(anim_name, tex_a)
			sf.add_frame(anim_name, tex_b)
		else:
			# Other directions: idle → walk_a (legs together → apart)
			sf.add_frame(anim_name, idle_frames[d])
			sf.add_frame(anim_name, tex_a)

		sf.set_animation_speed(anim_name, 6.0)

	_anim.sprite_frames = sf


func _load_legacy_doctor_idle(frames_dir: String, dir_name: String) -> Texture2D:
	var file_name: String = "side_idle.png"
	if dir_name == "down":
		file_name = "down_idle.png"
	elif dir_name == "up":
		file_name = "up_idle.png"
	return load(frames_dir + file_name) as Texture2D


func _load_legacy_doctor_walk(frames_dir: String, dir_name: String, phase: String) -> Texture2D:
	var file_name: String = "side_walk_r.png"
	if dir_name == "down":
		file_name = "down_walk_b.png" if phase == "b" else "down_walk_a.png"
	elif dir_name == "up":
		file_name = "up_walk_b.png" if phase == "b" else "up_walk_a.png"
	elif dir_name in ["left", "up_left", "down_left"]:
		file_name = "side_walk_l.png"
	return load(frames_dir + file_name) as Texture2D


# ═══════════════════════════════════════════════════════════════════════
#  Physics
# ═══════════════════════════════════════════════════════════════════════

# ── Wander anchor — NPC wanders in small radius around this point ──
var _anchor_pos: Vector2 = Vector2.ZERO
var _wander_radius: float = 40.0


func _physics_process(delta: float) -> void:
	# Navigation (walk_to) takes priority
	if _is_walking and _nav_agent:
		_nav_step()
		_update_anim()
		_separate_from_npcs()
		return

	# No wandering by default — NPCs stay in place unless can_wander=true
	if can_wander:
		_timer -= delta
		match _state:
			0:
				if _timer <= 0.0:
					_start_move()
			1:
				velocity = _dirs[_dir_idx] * speed * 0.3
				var d: float = get_physics_process_delta_time()
				global_position += velocity * d
				var dist_from_anchor: float = global_position.distance_to(_anchor_pos)
				if dist_from_anchor > _wander_radius:
					var back_dir: Vector2 = (_anchor_pos - global_position).normalized()
					_dir_idx = _dir_to_idx(back_dir)
				if _timer <= 0.0:
					_start_idle()

	# Soft collision: push away from other NPCs even when standing
	_separate_from_npcs()
	_update_anim()


# ── Navigation ───────────────────────────────────────────────

## Ensure NavigationAgent2D exists with signals connected.
## Creates lazily if missing. Returns the existing or newly created agent.
func _ensure_nav_agent() -> NavigationAgent2D:
	if _nav_agent:
		return _nav_agent

	# Check for existing NavigationAgent2D child
	var existing: Node = get_node_or_null("NavigationAgent2D")
	if existing is NavigationAgent2D:
		_nav_agent = existing as NavigationAgent2D
	else:
		# Try MapSystem first
		var map_sys: Node = get_node_or_null("/root/MapSystem")
		if map_sys and map_sys.has_method("ensure_nav_agent"):
			_nav_agent = map_sys.ensure_nav_agent(self)
		else:
			# Fallback: create directly
			_nav_agent = NavigationAgent2D.new()
			_nav_agent.name = "NavigationAgent2D"
			_nav_agent.path_desired_distance = 8.0
			_nav_agent.target_desired_distance = 8.0
			add_child(_nav_agent)

	if _nav_agent:
		_nav_agent.path_desired_distance = 8.0
		_nav_agent.target_desired_distance = 8.0
		if not _nav_agent.velocity_computed.is_connected(_on_nav_velocity_computed):
			_nav_agent.velocity_computed.connect(_on_nav_velocity_computed)
		if not _nav_agent.target_reached.is_connected(_on_nav_target_reached):
			_nav_agent.target_reached.connect(_on_nav_target_reached)
		if not _nav_agent.navigation_finished.is_connected(_on_nav_finished):
			_nav_agent.navigation_finished.connect(_on_nav_finished)

	return _nav_agent


## Walk to a named location (e.g. "TRIAGE", "ED_RESUS").
## Auto-creates NavigationAgent2D if missing.
func walk_to(location_name: String) -> void:
	_walk_target = location_name

	# Auto-create NavigationAgent2D if not present
	_ensure_nav_agent()
	if not _nav_agent:
		push_warning("BaseNpc: cannot create NavigationAgent2D")
		return

	var target: Vector2 = HospitalMapData.get_location(location_name)
	_nav_agent.target_position = target
	_is_walking = true
	_state = 1
	print("[Nav] %s → %s (%s)" % [get_npc_name(), location_name, target])


func _nav_step() -> void:
	if not _nav_agent or _nav_agent.is_navigation_finished():
		_is_walking = false
		velocity = Vector2.ZERO
		_start_idle()
		return

	var next_pos: Vector2 = _nav_agent.get_next_path_position()
	var new_vel: Vector2 = global_position.direction_to(next_pos) * speed
	# NPC不做物理碰撞，直接移动position（导航路径已绕开墙体）
	var delta: float = get_physics_process_delta_time()
	global_position += new_vel * delta
	_update_walk_dir(new_vel)


func _on_nav_velocity_computed(_safe_velocity: Vector2) -> void:
	# Not used — NPC moves via position directly, no move_and_slide
	pass


func _on_nav_target_reached() -> void:
	print("[Nav] %s arrived at %s" % [get_npc_name(), _walk_target if not _walk_target.is_empty() else "pos"])
	_is_walking = false
	velocity = Vector2.ZERO
	_walk_target = ""
	_state = 0  # idle
	# If we were approaching an NPC, face them
	if _face_target_npc and is_instance_valid(_face_target_npc):
		face_toward(_face_target_npc.global_position)
		_face_target_npc = null
	_update_anim()


func _on_nav_finished() -> void:
	_is_walking = false
	velocity = Vector2.ZERO
	_state = 0
	if not _walk_target.is_empty():
		_walk_target = ""
	_update_anim()


func _update_walk_dir(vel: Vector2) -> void:
	# Pick facing direction based on velocity for walk anim
	if vel.length() < 1.0:
		return
	var angle: float = vel.angle()
	# Map angle to dir_idx (0=down, 2=right, 4=up, 6=left)
	var idx: int = int(round(angle / (PI / 4))) % 8
	if idx < 0: idx += 8
	# angle 0 = right (idx 2), PI/2 = down (idx 0), PI = left (idx 6), -PI/2 = up (idx 4)
	# Simpler: just use 4-direction
	if abs(vel.x) > abs(vel.y):
		_dir_idx = 2 if vel.x > 0 else 6  # right or left
	else:
		_dir_idx = 0 if vel.y > 0 else 4  # down or up
	_update_anim()


func is_walking() -> bool:
	return _is_walking


## Face toward a target position (for dialogue). Sets idle animation facing the target.
func face_toward(target_pos: Vector2) -> void:
	var diff: Vector2 = target_pos - global_position
	if diff.length() < 1.0:
		return
	_state = 0  # idle
	if abs(diff.x) > abs(diff.y):
		_dir_idx = 2 if diff.x > 0 else 6  # face right or left
	else:
		_dir_idx = 0 if diff.y > 0 else 4  # face down or up
	_update_anim()


## Walk to a position near another NPC, then face them.
## offset = distance to stop from target (default 60px)
func approach_and_face(target_npc: BaseNpc, offset: float = 60.0) -> void:
	var target_pos: Vector2 = target_npc.global_position
	var dir: Vector2 = (global_position - target_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var stop_pos: Vector2 = target_pos + dir * offset
	# Walk to stop position
	walk_to_pos(stop_pos)
	# Will face target when arrived (handled in _on_nav_target_reached)
	_face_target_npc = target_npc


var _face_target_npc: BaseNpc = null


## Walk to a raw position (not a named location).
func walk_to_pos(target: Vector2) -> void:
	_ensure_nav_agent()
	if not _nav_agent:
		return
	_nav_agent.target_position = target
	_is_walking = true
	_state = 1
	print("[Nav] %s → (%.0f, %.0f)" % [get_npc_name(), target.x, target.y])


# ═══════════════════════════════════════════════════════════════════════
#  Animation
# ═══════════════════════════════════════════════════════════════════════

func _update_anim() -> void:
	var prefix: String = "walk" if _state == 1 else "idle"
	var target: String = prefix + _dir_name(_dir_idx)

	if _anim.animation == target:
		return
	_anim.animation = target
	_anim.frame = 0
	if _state == 1:
		_anim.play()
	else:
		_anim.stop()


static func _dir_to_idx(dir: Vector2) -> int:
	var angle: float = dir.angle()
	var idx: int = int(round(angle / (PI / 4))) % 8
	if idx < 0:
		idx += 8
	# angle 0=right(idx2), PI/2=down(idx0), PI=left(idx6), -PI/2=up(idx4)
	# Remap to our _dir_names order: 0=down,1=down_right,2=right,3=up_right,4=up,5=up_left,6=left,7=down_left
	if abs(dir.x) > abs(dir.y):
		return 2 if dir.x > 0 else 6
	else:
		return 0 if dir.y > 0 else 4


static func _dir_name(idx: int) -> String:
	match idx:
		0:  return "_down"
		1:  return "_down_right"
		2:  return "_right"
		3:  return "_up_right"
		4:  return "_up"
		5:  return "_up_left"
		6:  return "_left"
		7:  return "_down_left"
		_:  return "_down"


# ═══════════════════════════════════════════════════════════════════════
#  Movement state machine
# ═══════════════════════════════════════════════════════════════════════

func _start_idle() -> void:
	_state = 0
	_pick_timer()


func _start_move() -> void:
	_state = 1
	_dir_idx = randi_range(0, 7)
	_timer = randf_range(move_min, move_max)


func _pick_timer() -> void:
	_timer = randf_range(idle_min, idle_max)


## Soft collision: push away from nearby NPCs so they don't overlap.
## Uses simple distance check, no physics body needed.
func _separate_from_npcs() -> void:
	var push_radius: float = 35.0  # minimum distance between NPCs
	var push_strength: float = 200.0  # pixels/sec push force
	var delta: float = get_physics_process_delta_time()
	var group_npcs: Array = get_tree().get_nodes_in_group("npcs")
	for other in group_npcs:
		if other == self or not other is BaseNpc:
			continue
		if not is_instance_valid(other):
			continue
		var diff: Vector2 = global_position - other.global_position
		var dist: float = diff.length()
		if dist < push_radius and dist > 0.1:
			var push: Vector2 = diff.normalized() * push_strength * delta
			global_position += push
		elif dist <= 0.1:
			# Exactly overlapping — push in random direction
			global_position += Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * push_strength * delta


# ═══════════════════════════════════════════════════════════════════════
#  Dialogue API
# ═══════════════════════════════════════════════════════════════════════

## Set the current dialogue entry. The DialogueManager will pick it up
## on the next frame and show it in an assigned bubble.
func speak(entry: DialogueEntry) -> void:
	_current_entry = entry

## Clear the current dialogue entry — hides the NPC's bubble.
func stop_speaking() -> void:
	_current_entry = null

## Called by DialogueManager each frame. Return the current entry or null.
func get_dialogue_entry() -> DialogueEntry:
	return _current_entry

## Get the NPC's memory store for conversation context.
func get_memory() -> MemoryStore:
	return _memory


func reset_memory() -> void:
	if _memory:
		_memory.clear()

## Record a dialogue exchange to this NPC's memory.
func record_dialogue(listener: String, think: String, dialogue: String, importance: int = 5) -> void:
	if _memory:
		_memory.add_dialogue(get_npc_name(), listener, think, dialogue, importance, [])

## Record an internal thought to memory.
func record_thought(content: String, importance: int = 3) -> void:
	if _memory:
		_memory.add_thought(content, importance)

## Get recent memory context as a string (for future LLM prompts).
func get_memory_context(count: int = 5) -> String:
	if _memory:
		return _memory.get_context_str(count)
	return ""

## Get NPC state name (for LLM prompt).
func get_state_name() -> String:
	match _npc_state:
		NpcState.ARRIVED: return "刚到"
		NpcState.WAITING: return "候诊等待中"
		NpcState.GOING_TO_ROOM: return "正前往" + _state_target
		NpcState.BEING_EXAMINED: return "检查中(" + _state_target + ")"
		NpcState.DISCHARGED: return "已出院"
	return "未知"

## Set NPC state.
func set_state(new_state: int, target: String = "") -> void:
	_npc_state = new_state
	_state_target = target
	if new_state == NpcState.GOING_TO_ROOM and not target.is_empty():
		walk_to(target)

## Get raw state enum value.
func get_state() -> int:
	return _npc_state
