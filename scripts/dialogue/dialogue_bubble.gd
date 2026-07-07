class_name DialogueBubble
extends Control

## Speech-bubble UI with robust async lifecycle.
##
## Thread-safe for re-entry: if show_entry() is called while utterances are
## still playing, pending timers are discarded via a sequence counter.

enum Phase { IDLE, THINK, UTTERANCE, DONE }

const MAX_WIDTH := 220
const MIN_WIDTH := 120
const MAX_HEIGHT := 180.0
const PAD_H := 16
const PAD_V := 10
const TAIL_W := 14.0
const TAIL_H := 8.0
const FONT_SIZE := 13
const COLOR_BG := Color(1, 1, 1, 0.95)
const COLOR_TEXT := Color(0.15, 0.15, 0.15)
const COLOR_THINK := Color(0.25, 0.40, 0.80)
const COLOR_THINK_BG := Color(0.92, 0.95, 0.98, 0.92)
const TYPEWRITER_INTERVAL := 0.04
const THINK_PAUSE := 0.5
const FADE_DURATION := 0.25
const UTTERANCE_TIME := 2.5

# ── Node refs ──
var _panel: Panel
var _scroll: ScrollContainer
var _row: HBoxContainer
var _icon: Label
var _label: RichTextLabel
var _think_bg: ColorRect
var _typewriter: Timer

# ── State ──
var _phase: int = Phase.IDLE
var _think_text: String = ""
var _think_pos: int = 0
var _utterances: Array[String] = []
var _utter_idx: int = 0
var _random_phase: float = 0.0
var _current_entry: DialogueEntry = null
var _needs_resize := false
var _is_fading := false
var _fade_tween: Tween = null
var _seq: int = 0  # incremented on each show_entry(); async callbacks check this


func _init() -> void:
	_random_phase = randf_range(0.0, TAU)
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build_ui()
	_typewriter = Timer.new()
	_typewriter.one_shot = false
	_typewriter.timeout.connect(_on_tick)
	add_child(_typewriter)
	hide()


# ═══════════════════════════════════════════════════════════════════════
#  Public API
# ═══════════════════════════════════════════════════════════════════════

func is_available() -> bool:
	return not visible and not _is_fading


func fade_out() -> void:
	if _is_fading or not visible:
		return
	_is_fading = true
	_typewriter.stop()
	_kill_tweens()
	_seq += 1  # Discard any pending async callbacks
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_fade_tween.tween_callback(func():
		visible = false
		modulate.a = 1.0
		_is_fading = false
	)
	_phase = Phase.IDLE


func show_entry(entry: DialogueEntry) -> void:
	_seq += 1  # Invalidate old async callbacks
	var my_seq := _seq

	if _is_fading:
		_kill_tweens()
		_is_fading = false
		modulate.a = 1.0
	_typewriter.stop()

	_current_entry = entry
	if entry.is_empty():
		hide()
		return

	# Reset state
	_think_text = entry.think
	_utterances = entry.utterances.duplicate()
	_utter_idx = 0
	_think_pos = 0
	_phase = Phase.THINK

	if not _label or not _row or not _think_bg or not _icon:
		push_error("DialogueBubble: UI not fully built")
		return

	_label.text = ""
	_label.modulate = Color.WHITE
	_label.add_theme_color_override("default_color", COLOR_THINK)
	_row.modulate = Color.WHITE
	_think_bg.modulate = Color.WHITE
	_icon.text = "🤔"
	visible = true
	_needs_resize = true

	if _think_text.is_empty():
		_show_dialogue(my_seq)
	else:
		_think_bg.show()
		_typewriter.start(TYPEWRITER_INTERVAL)


func follow_screen_position(cx: float, by: float) -> void:
	var offset: float = sin(Time.get_ticks_msec() * 0.0025 + _random_phase) * 3.0
	position.x = cx - size.x * 0.5
	position.y = by - size.y - 16.0 + offset


# ═══════════════════════════════════════════════════════════════════════
#  Internal
# ═══════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_size = 6
	style.shadow_color = Color(0, 0, 0, 0.18)
	_panel.add_theme_stylebox_override("panel", style)

	_think_bg = ColorRect.new()
	_think_bg.color = COLOR_THINK_BG
	_think_bg.mouse_filter = MOUSE_FILTER_IGNORE
	_panel.add_child(_think_bg)

	_scroll = ScrollContainer.new()
	_scroll.mouse_filter = MOUSE_FILTER_IGNORE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel.add_child(_scroll)

	_row = HBoxContainer.new()
	_row.mouse_filter = MOUSE_FILTER_IGNORE
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_row)

	_icon = Label.new()
	_icon.text = "🤔"
	_icon.add_theme_font_size_override("font_size", FONT_SIZE)
	_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_icon.custom_minimum_size = Vector2(22, 0)
	_row.add_child(_icon)

	_label = RichTextLabel.new()
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.fit_content = true
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.scroll_following = true
	_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_label.add_theme_color_override("default_color", COLOR_THINK)
	_label.custom_minimum_size = Vector2(MAX_WIDTH - 48, 0)
	_row.add_child(_label)


func _reflow() -> void:
	if not _row:
		return
	var min_size := _row.get_combined_minimum_size()
	var bw: float = clamp(min_size.x + PAD_H, MIN_WIDTH, MAX_WIDTH)
	var content_h := min_size.y + PAD_V
	var bh: float = minf(content_h, MAX_HEIGHT) + TAIL_H

	size = Vector2(bw, bh)
	var panel_h := bh - TAIL_H
	if _panel: _panel.size = Vector2(bw, panel_h)
	if _scroll:
		_scroll.position = Vector2(PAD_H * 0.5, PAD_V * 0.5)
		_scroll.size = Vector2(bw - PAD_H, panel_h - PAD_V)
	if _row: _row.size = Vector2(bw - PAD_H - 4, min_size.y)
	if _think_bg:
		_think_bg.position = Vector2.ZERO
		_think_bg.size = Vector2(bw, panel_h) if _phase == Phase.THINK else Vector2.ZERO

	var sb := _scroll.get_v_scroll_bar() if _scroll else null
	if sb:
		_scroll.scroll_vertical = int(sb.max_value)

	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var cx := size.x * 0.5
	var by := size.y - TAIL_H
	var pts := PackedVector2Array([
		Vector2(cx, by + TAIL_H),
		Vector2(cx - TAIL_W * 0.5, by),
		Vector2(cx + TAIL_W * 0.5, by),
	])
	draw_primitive(pts, [], pts)


func _process(_delta: float) -> void:
	if _needs_resize:
		_needs_resize = false
		_reflow()


# ═══════════════════════════════════════════════════════════════════════
#  Phase sequencing
# ═══════════════════════════════════════════════════════════════════════

func _on_tick() -> void:
	_think_pos += 1
	if _think_pos > _think_text.length():
		_typewriter.stop()
		_start_think_fadeout()
		return
	if _label:
		_label.text = _think_text.left(_think_pos)
		_needs_resize = true


func _start_think_fadeout() -> void:
	var my_seq := _seq
	await get_tree().create_timer(THINK_PAUSE).timeout
	if my_seq != _seq or not is_instance_valid(self):
		return
	_phase = Phase.UTTERANCE
	var t := create_tween()
	t.tween_property(_row, "modulate:a", 0.0, FADE_DURATION)
	t.parallel().tween_property(_think_bg, "modulate:a", 0.0, FADE_DURATION)
	t.tween_callback(_show_dialogue.bind(my_seq))


func _show_dialogue(my_seq: int = -1) -> void:
	if my_seq >= 0 and my_seq != _seq:
		return  # superseded by a newer show_entry() call
	if not is_instance_valid(self):
		return
	_phase = Phase.UTTERANCE
	if _label:
		_label.add_theme_color_override("default_color", COLOR_TEXT)
	if _icon:
		_icon.text = "🗣"
	if _row:
		_row.modulate = Color.WHITE
	if _think_bg:
		_think_bg.hide()

	_utter_idx = 0
	_advance_utterance(my_seq)


func _advance_utterance(my_seq: int) -> void:
	if my_seq != _seq or not is_instance_valid(self):
		return
	if _utter_idx >= _utterances.size():
		_phase = Phase.DONE
		return

	if _label:
		_label.text = _utterances[_utter_idx]
	_utter_idx += 1
	_needs_resize = true

	if _utter_idx < _utterances.size():
		await get_tree().create_timer(UTTERANCE_TIME).timeout
		if my_seq == _seq and is_instance_valid(self):
			_advance_utterance(my_seq)


func _kill_tweens() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
