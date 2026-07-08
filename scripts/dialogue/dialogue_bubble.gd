class_name DialogueBubble
extends Control

## Speech-bubble UI — think and utterance in one shared window.
##
## Think text (blue) appears first via typewriter, then transitions to
## utterance text (black). Max 3 lines visible, scroll for overflow.
## Auto fade_out after all utterances finish.

signal done()

enum Phase { IDLE, THINK, UTTERANCE, FADING, DONE }

const MAX_WIDTH: int = 240
const MIN_WIDTH: int = 120
const VISIBLE_LINES: int = 3
const LINE_HEIGHT: float = 18.0
const MAX_HEIGHT: float = LINE_HEIGHT * VISIBLE_LINES + 20.0
const PAD_H: int = 12
const PAD_V: int = 8
const TAIL_W: float = 12.0
const TAIL_H: float = 7.0
const FONT_SIZE: int = 12
const COLOR_BG: Color = Color(1, 1, 1, 0.96)
const COLOR_TEXT: Color = Color(0.12, 0.12, 0.12)
const COLOR_THINK: Color = Color(0.25, 0.40, 0.80)
const TYPEWRITER_INTERVAL: float = 0.035
const THINK_PAUSE: float = 0.4
const FADE_DURATION: float = 0.3
const CHARS_PER_SEC: float = 10.0
const MIN_UTT_TIME: float = 1.2

# ── Node refs ──
var _panel: Panel
var _scroll: ScrollContainer
var _label: RichTextLabel
var _typewriter: Timer

# ── State ──
var _phase: int = Phase.IDLE
var _think_text: String = ""
var _think_pos: int = 0
var _utterances: Array = []
var _utter_idx: int = 0
var _current_entry: DialogueEntry = null
var _needs_resize: bool = false
var _is_fading: bool = false
var _fade_tween: Tween = null
var _seq: int = 0
var _bubble_offset_y: float = 0.0  # for stacking multiple bubbles


func get_seq() -> int:
	return _seq


func _init() -> void:
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
	_seq += 1
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	_fade_tween.tween_callback(func():
		visible = false
		modulate.a = 1.0
		_is_fading = false
		_phase = Phase.IDLE
	)
	_phase = Phase.FADING


func show_entry(entry: DialogueEntry) -> void:
	_seq += 1
	var my_seq: int = _seq

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

	if not _label or not _scroll:
		push_error("DialogueBubble: UI not fully built")
		return

	# Start with think text (blue)
	_label.text = ""
	_label.add_theme_color_override("default_color", COLOR_THINK)
	visible = true
	_needs_resize = true

	if _think_text.is_empty():
		_show_dialogue(my_seq)
	else:
		_typewriter.start(TYPEWRITER_INTERVAL)


func follow_screen_position(cx: float, by: float) -> void:
	var offset: float = sin(Time.get_ticks_msec() * 0.0025) * 2.0
	position.x = cx - size.x * 0.5
	position.y = by - size.y - 20.0 + _bubble_offset_y + offset


func set_offset_y(y: float) -> void:
	_bubble_offset_y = y


# ═══════════════════════════════════════════════════════════════════════
#  UI Build — single window, max 3 lines, scroll
# ═══════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	_panel.add_theme_stylebox_override("panel", style)

	# Scroll container — limits visible height to 3 lines
	_scroll = ScrollContainer.new()
	_scroll.mouse_filter = MOUSE_FILTER_IGNORE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel.add_child(_scroll)

	# Single label — think and utterance share this
	_label = RichTextLabel.new()
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.fit_content = true
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.scroll_following = true
	_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_label.add_theme_color_override("default_color", COLOR_THINK)
	_label.custom_minimum_size = Vector2(MAX_WIDTH - PAD_H, 0)
	_label.bbcode_enabled = true
	_scroll.add_child(_label)


func _reflow() -> void:
	if not _label:
		return
	# Calculate needed size
	var label_min: Vector2 = _label.get_combined_minimum_size()
	var bw: float = clamp(label_min.x + PAD_H, MIN_WIDTH, MAX_WIDTH)
	# Limit visible height to 3 lines, but content can be taller (scroll)
	var content_h: float = minf(label_min.y, MAX_HEIGHT)
	var bh: float = content_h + PAD_V + TAIL_H

	size = Vector2(bw, bh)
	var panel_h: float = bh - TAIL_H
	if _panel:
		_panel.size = Vector2(bw, panel_h)
	if _scroll:
		_scroll.position = Vector2(PAD_H * 0.5, PAD_V * 0.5)
		_scroll.size = Vector2(bw - PAD_H, panel_h - PAD_V)
	_label.size = Vector2(bw - PAD_H, label_min.y)

	# Auto-scroll to bottom
	var sb: VScrollBar = _scroll.get_v_scroll_bar()
	if sb:
		_scroll.scroll_vertical = int(sb.max_value)

	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var cx: float = size.x * 0.5
	var by: float = size.y - TAIL_H
	var pts: PackedVector2Array = PackedVector2Array([
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
#  Phase sequencing — think typewriter → utterance → done → fade
# ═══════════════════════════════════════════════════════════════════════

func _on_tick() -> void:
	_think_pos += 1
	if _think_pos > _think_text.length():
		_typewriter.stop()
		_start_think_transition()
		return
	if _label:
		_label.text = _think_text.left(_think_pos)
		_needs_resize = true


func _start_think_transition() -> void:
	var my_seq: int = _seq
	await get_tree().create_timer(THINK_PAUSE).timeout
	if my_seq != _seq or not is_instance_valid(self):
		return
	# Transition: change color from think (blue) to text (black)
	_phase = Phase.UTTERANCE
	_show_dialogue(my_seq)


func _show_dialogue(my_seq: int = -1) -> void:
	if my_seq >= 0 and my_seq != _seq:
		return
	if not is_instance_valid(self):
		return
	_phase = Phase.UTTERANCE
	if _label:
		_label.add_theme_color_override("default_color", COLOR_TEXT)
	_utter_idx = 0
	_advance_utterance(my_seq)


func _advance_utterance(my_seq: int) -> void:
	if my_seq != _seq or not is_instance_valid(self):
		return
	if _utter_idx >= _utterances.size():
		# All utterances done — auto fade out
		_phase = Phase.DONE
		done.emit()
		_auto_fade_out()
		return

	var current_text: String = str(_utterances[_utter_idx])
	# Append to label (keep think text above, utterance below)
	if _label:
		if _utter_idx == 0:
			# First utterance: clear think text, show utterance
			_label.text = current_text
		else:
			# Append utterance on new line
			_label.text += "\n" + current_text
	_utter_idx += 1
	_needs_resize = true

	var display_time: float = maxf(current_text.length() / CHARS_PER_SEC, MIN_UTT_TIME)

	if _utter_idx < _utterances.size():
		await get_tree().create_timer(display_time).timeout
		if my_seq == _seq and is_instance_valid(self):
			_advance_utterance(my_seq)
	else:
		await get_tree().create_timer(display_time).timeout
		if my_seq == _seq and is_instance_valid(self):
			_phase = Phase.DONE
			done.emit()
			_auto_fade_out()


func _auto_fade_out() -> void:
	var my_seq: int = _seq
	await get_tree().create_timer(0.5).timeout
	if my_seq != _seq or not is_instance_valid(self):
		return
	fade_out()


func _kill_tweens() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
