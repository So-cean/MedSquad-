class_name DialogueBubble
extends Control

## Speech-bubble UI — think (blue typewriter) + utterance (black typewriter).
## Max 3 lines visible, auto-scroll to bottom, scrollbar hidden.
## Auto fade_out after display complete.

signal done()

enum Phase { IDLE, THINK, UTTERANCE, FADING, DONE }

const MAX_WIDTH: int = 240
const MIN_WIDTH: int = 120
const VISIBLE_LINES: int = 3
const LINE_HEIGHT: float = 18.0
const MAX_CONTENT_HEIGHT: float = LINE_HEIGHT * VISIBLE_LINES  # 54px
const PAD_H: int = 12
const PAD_V: int = 8
const TAIL_W: float = 12.0
const TAIL_H: float = 7.0
const FONT_SIZE: int = 12
const COLOR_BG: Color = Color(1, 1, 1, 0.96)
const COLOR_TEXT: Color = Color(0.12, 0.12, 0.12)
const COLOR_THINK: Color = Color(0.25, 0.40, 0.80)
const TYPEWRITER_INTERVAL: float = 0.08
const THINK_PAUSE: float = 0.6
const FADE_DURATION: float = 0.3
const MIN_UTT_TIME: float = 2.0
const AUTO_FADE_DELAY: float = 0.8

# ── Node refs ──
var _panel: Panel
var _scroll: ScrollContainer
var _label: RichTextLabel
var _typewriter: Timer
var _cn_font: FontVariation = null

# ── State ──
var _phase: int = Phase.IDLE
var _think_text: String = ""
var _think_pos: int = 0
var _utterances: Array = []
var _utter_idx: int = 0
var _utter_text: String = ""
var _utter_pos: int = 0
var _full_text: String = ""
var _current_entry: DialogueEntry = null
var _needs_resize: bool = false
var _is_fading: bool = false
var _fade_tween: Tween = null
var _seq: int = 0
var _bubble_offset_y: float = 0.0


func get_seq() -> int:
	return _seq


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	_load_cn_font()
	_build_ui()
	_typewriter = Timer.new()
	_typewriter.one_shot = false
	_typewriter.timeout.connect(_on_tick)
	add_child(_typewriter)
	hide()


func _load_cn_font() -> void:
	if _cn_font:
		return
	var tex: FontFile = load("res://assets/fonts/NotoSansSC-VF.ttf") as FontFile
	if tex:
		_cn_font = FontVariation.new()
		_cn_font.base_font = tex


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

	# Full reset
	_think_text = entry.think
	_utterances = entry.utterances.duplicate()
	if _utterances.is_empty() and not entry.dialogue.is_empty():
		_utterances = [entry.dialogue]
	if _utterances.is_empty():
		_utterances = ["..."]
	_utter_idx = 0
	_think_pos = 0
	_utter_pos = 0
	_utter_text = ""
	_full_text = ""
	_phase = Phase.THINK

	if not _label or not _scroll:
		push_error("DialogueBubble: UI not fully built")
		return

	_label.clear()
	_label.text = ""
	_label.add_theme_color_override("default_color", COLOR_THINK)
	visible = true
	modulate = Color.WHITE
	_needs_resize = true

	if _think_text.is_empty():
		_start_utterance_typewriter(my_seq)
	else:
		_typewriter.start(TYPEWRITER_INTERVAL)


func follow_screen_position(cx: float, by: float) -> void:
	position.x = cx - size.x * 0.5
	position.y = by - size.y - 20.0 + _bubble_offset_y


func set_offset_y(y: float) -> void:
	_bubble_offset_y = y


# ═══════════════════════════════════════════════════════════════════════
#  UI Build — 3 line window, no scrollbar visible, auto-scroll
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

	# ScrollContainer — fixed height = MAX_CONTENT_HEIGHT (3 lines)
	_scroll = ScrollContainer.new()
	_scroll.mouse_filter = MOUSE_FILTER_IGNORE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel.add_child(_scroll)

	# Label — fit_content=true so it grows with content
	# ScrollContainer clips to MAX_CONTENT_HEIGHT, auto-scrolls to bottom
	_label = RichTextLabel.new()
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.fit_content = true
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.scroll_following = true
	_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_label.add_theme_color_override("default_color", COLOR_THINK)
	_label.custom_minimum_size = Vector2(MAX_WIDTH - PAD_H, LINE_HEIGHT)
	_label.bbcode_enabled = true
	if _cn_font:
		_label.add_theme_font_override("normal_font", _cn_font)
	_scroll.add_child(_label)


func _reflow() -> void:
	if not _label:
		return
	var content_size: Vector2 = _label.get_combined_minimum_size()
	var bw: float = clamp(content_size.x + PAD_H, MIN_WIDTH, MAX_WIDTH)
	# Bubble height = min(content, 3 lines) + padding + tail
	var visible_h: float = minf(content_size.y, MAX_CONTENT_HEIGHT)
	var bh: float = visible_h + PAD_V + TAIL_H

	size = Vector2(bw, bh)
	var panel_h: float = bh - TAIL_H
	if _panel:
		_panel.size = Vector2(bw, panel_h)
	if _scroll:
		_scroll.position = Vector2(PAD_H * 0.5, PAD_V * 0.5)
		# ScrollContainer clips to MAX_CONTENT_HEIGHT
		_scroll.size = Vector2(bw - PAD_H, minf(content_size.y, MAX_CONTENT_HEIGHT))
	_label.size = Vector2(bw - PAD_H, content_size.y)

	# Hide scrollbar, auto-scroll to bottom (shows last 3 lines)
	var sb: VScrollBar = _scroll.get_v_scroll_bar()
	if sb:
		sb.modulate = Color(0, 0, 0, 0)  # invisible
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
#  Unified typewriter — think (blue) then utterance (black)
# ═══════════════════════════════════════════════════════════════════════

func _on_tick() -> void:
	var my_seq: int = _seq
	if _phase == Phase.THINK:
		_think_pos += 1
		if _think_pos > _think_text.length():
			_typewriter.stop()
			_start_think_transition()
			return
		_full_text = _think_text.left(_think_pos)
		_label.text = _full_text
		_needs_resize = true

	elif _phase == Phase.UTTERANCE:
		_utter_pos += 1
		if _utter_pos > _utter_text.length():
			_typewriter.stop()
			_utterance_display_done(my_seq)
			return
		_label.text = _full_text + _utter_text.left(_utter_pos)
		_needs_resize = true


func _start_think_transition() -> void:
	var my_seq: int = _seq
	await get_tree().create_timer(THINK_PAUSE).timeout
	if my_seq != _seq or not is_instance_valid(self):
		return
	# Save think text, switch to utterance color (black)
	_full_text = _think_text + "\n"
	_phase = Phase.UTTERANCE
	_label.add_theme_color_override("default_color", COLOR_TEXT)
	_start_utterance_typewriter(my_seq)


func _start_utterance_typewriter(my_seq: int) -> void:
	if my_seq >= 0 and my_seq != _seq:
		return
	if not is_instance_valid(self):
		return
	if _utter_idx >= _utterances.size():
		_phase = Phase.DONE
		done.emit()
		_auto_fade_out()
		return

	_utter_text = str(_utterances[_utter_idx])
	_utter_pos = 0
	_phase = Phase.UTTERANCE
	if _utter_idx > 0:
		_full_text += "\n"
	_typewriter.start(TYPEWRITER_INTERVAL)


func _utterance_display_done(my_seq: int) -> void:
	if my_seq != _seq or not is_instance_valid(self):
		return
	_full_text += _utter_text
	_utter_idx += 1
	_needs_resize = true

	var display_time: float = maxf(float(_utter_text.length()) / 7.0, MIN_UTT_TIME)
	await get_tree().create_timer(display_time).timeout
	if my_seq != _seq or not is_instance_valid(self):
		return
	if _utter_idx >= _utterances.size():
		_phase = Phase.DONE
		done.emit()
		_auto_fade_out()
	else:
		_start_utterance_typewriter(my_seq)


func _auto_fade_out() -> void:
	var my_seq: int = _seq
	await get_tree().create_timer(AUTO_FADE_DELAY).timeout
	if my_seq != _seq or not is_instance_valid(self):
		return
	fade_out()


func _kill_tweens() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
