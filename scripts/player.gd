extends CharacterBody2D

@export var speed: float = 200.0

enum Dir { DOWN, LEFT, RIGHT, UP }

var _anim: AnimatedSprite2D
var _facing: Dir = Dir.DOWN
var _moving: bool = false
var _state: String = "idle_down"
var _frame_time: float = 0.0


# ── ready ──────────────────────────────────────────────────────

func _ready() -> void:
	_anim = $AnimatedSprite2D as AnimatedSprite2D
	_setup_inputs()
	_build_frames()
	_anim.animation = "idle_down"
	_anim.frame = 0


func _setup_inputs() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	var keys := {
		"move_left":  KEY_A,
		"move_right": KEY_D,
		"move_up":    KEY_W,
		"move_down":  KEY_S,
	}
	for action in keys:
		var ev := InputEventKey.new()
		ev.keycode = keys[action]
		InputMap.action_add_event(action, ev)


# ── sprite frames ─────────────────────────────────────────────

func _build_frames() -> void:
	var sf := SpriteFrames.new()

	var di  := _load("down_idle.png")
	var dwa := _load("down_walk_a.png")
	var dwb := _load("down_walk_b.png")
	var dwc := _load("down_walk_c.png")
	var ui  := _load("up_idle.png")
	var uwa := _load("up_walk_a.png")
	var uwb := _load("up_walk_b.png")
	var si  := _load("side_idle.png")     # (1,2) 中间态 = idle
	var swr := _load("side_walk_r.png")   # (0,2) 右腿
	var swl := _load("side_walk_l.png")   # (2,2) 左腿

	for v in [di, dwa, dwb, dwc, ui, uwa, uwb, si, swr, swl]:
		if v == null:
			push_error("Missing doctor frame")
			return

	# ── down ─────────────────────────────────────────────
	sf.add_animation("idle_down")
	sf.add_frame("idle_down", di)

	sf.add_animation("walk_down")
	sf.add_frame("walk_down", dwa)
	sf.add_frame("walk_down", dwb)
	sf.add_frame("walk_down", dwc)
	sf.set_animation_speed("walk_down", 8.0)

	# ── up ───────────────────────────────────────────────
	sf.add_animation("idle_up")
	sf.add_frame("idle_up", ui)

	sf.add_animation("walk_up")
	sf.add_frame("walk_up", uwa)
	sf.add_frame("walk_up", uwb)
	sf.set_animation_speed("walk_up", 8.0)

	# ── right ────────────────────────────────────────────
	sf.add_animation("idle_right")
	sf.add_frame("idle_right", si)    # (1,2) 中间态 = idle

	sf.add_animation("walk_right")
	sf.add_frame("walk_right", swr)   # (0,2) 右腿
	sf.add_frame("walk_right", si)    # (1,2) 中间态 = idle
	sf.add_frame("walk_right", swl)   # (2,2) 左腿
	sf.set_animation_speed("walk_right", 8.0)

	_anim.sprite_frames = sf


func _load(filename: String) -> Texture2D:
	return load("res://assets/doctor_frames/" + filename) as Texture2D


# ── physics / manual frame advance ────────────────────────────

func _physics_process(delta: float) -> void:
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_moving = raw.length() > 0.01

	if _moving:
		velocity = raw * speed
		_facing = _pick_dir(raw)
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_update_state()
	_advance_frame(delta)


func _pick_dir(v: Vector2) -> Dir:
	return Dir.UP if v.y < -abs(v.x) else \
		   Dir.DOWN if v.y > abs(v.x) else \
		   Dir.LEFT if v.x < 0 else Dir.RIGHT


func _advance_frame(delta: float) -> void:
	var anim_speed := _anim.sprite_frames.get_animation_speed(_state)
	var count := _anim.sprite_frames.get_frame_count(_state)

	if not _moving or anim_speed <= 0.0 or count <= 1:
		_frame_time = 0.0
		_anim.frame = 0
		return

	_frame_time += delta
	var dur: float = 1.0 / anim_speed
	while _frame_time >= dur:
		_anim.frame = (_anim.frame + 1) % count
		_frame_time -= dur


# ── state machine ──────────────────────────────────────────────

func _update_state() -> void:
	var target: String

	if _moving:
		target = "walk_down" if _facing == Dir.DOWN else \
				 "walk_up"   if _facing == Dir.UP   else \
		         "walk_right"
	else:
		target = "idle_down" if _facing == Dir.DOWN else \
				 "idle_up"   if _facing == Dir.UP   else \
		         "idle_right"

	_change_state(target, _facing == Dir.LEFT)


func _change_state(anim_name: String, flip: bool) -> void:
	if _state == anim_name and _anim.flip_h == flip:
		return
	_state = anim_name
	_anim.animation = anim_name
	_anim.flip_h = flip
	_anim.frame = 0
	_frame_time = 0.0
