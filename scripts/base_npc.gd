class_name BaseNpc
extends CharacterBody2D

## Base class for all NPC characters.
##
## Handles:
##   - 8-direction wander movement
##   - Code-generated SpriteFrames from per-direction PNGs
##   - configurable walk_flip for UP/DOWN (walk_a→walk_b)
##   - DialogueEntry interface (think / dialogue)
##   - Auto-registration with DialogueManager
##
## Subclasses override:
##   get_frames_dir() → String          REQUIRED
##   get_npc_name()   → String          (default: "NPC")
##   get_walk_flip_dirs() → Array[String]  (default: [])
##   get_npc_group()  → String          (default: "npcs")

# ═══════════════════════════════════════════════════════════════════════
#  Exports (tweak per-instance in the editor)
# ═══════════════════════════════════════════════════════════════════════

@export var speed: float = 60.0
@export var idle_min: float = 1.0
@export var idle_max: float = 4.0
@export var move_min: float = 0.8
@export var move_max: float = 2.5

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

# ── Memory & Conversation (lazy init) ──
var _memory = null  # MemoryStore, lazy-init
var _conv_status: String = "idle"


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

	# Register with ConversationManager (child of DialogueManager)
	var cm = DialogueManager.get_conversation_manager()
	if cm:
		cm.register(self)

	# Initialize memory store
	var mem_script = load("res://scripts/dialogue/memory_store.gd")
	if mem_script:
		_memory = mem_script.new(get_npc_name())

	# Add to discovery group for MockDialogueSystem
	add_to_group(get_npc_group())


func _exit_tree() -> void:
	DialogueManager.unregister(self)


# ═══════════════════════════════════════════════════════════════════════
#  Frame builder
# ═══════════════════════════════════════════════════════════════════════

func _build_frames() -> void:
	var frames_dir := get_frames_dir()
	var npc_tag := get_npc_name()
	if frames_dir.is_empty():
		push_error("BaseNpc: get_frames_dir() returned empty path for ", npc_tag)
		return

	var sf := SpriteFrames.new()
	var walk_flip := get_walk_flip_dirs()

	# ── Idle frames ──
	#       down direction uses a separate idle_down.png (standalone 32×32),
	#       all other orientations come from the 8-dir sheet.
	var idle_frames: Dictionary = {}
	for d: String in _dir_names:
		var path: String = frames_dir + ("idle_down.png" if d == "down" else "idle_%s.png" % d)
		var tex: Texture2D = load(path) as Texture2D
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
			push_error("BaseNpc (%s): missing walk frame: %s" % [npc_tag, path_a])
			return

		var anim_name: String = "walk_" + d
		sf.add_animation(anim_name)

		if d in walk_flip:
			# UP / DOWN: walk_a → walk_b (alternating leg-forward poses)
			var path_b: String = frames_dir + "walk_%s_b.png" % d
			var tex_b: Texture2D = load(path_b) as Texture2D
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


# ═══════════════════════════════════════════════════════════════════════
#  Physics
# ═══════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	_timer -= delta

	match _state:
		0:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_start_move()
		1:
			velocity = _dirs[_dir_idx] * speed
			if _timer <= 0.0:
				_start_idle()

	move_and_slide()
	if is_on_wall():
		_start_move()

	_update_anim()


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

## Record a dialogue exchange to this NPC's memory.
func record_dialogue(listener: String, think: String, dialogue: String, importance: int = 5) -> void:
	if _memory:
		_memory.add_dialogue(get_npc_name(), listener, think, dialogue, importance, PackedStringArray())

## Record an internal thought to memory.
func record_thought(content: String, importance: int = 3) -> void:
	if _memory:
		_memory.add_thought(content, importance)

## Get recent memory context as a string (for future LLM prompts).
func get_memory_context(count: int = 5) -> String:
	if _memory:
		return _memory.get_context_str(count)
	return ""

## Set conversation status for ConversationManager.
func set_conv_status(status: String) -> void:
	_conv_status = status

## Get conversation status.
func get_conv_status() -> String:
	return _conv_status
