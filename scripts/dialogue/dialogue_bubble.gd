class_name DialogueBubble
extends Control

## Speech-bubble UI.
##
## THINK: 🤔 blue typewriter → pause → CLEAR
## UTTERANCE: 🗡 black typewriter → done → fade
## Max 3 lines, no scrollbar, auto-scroll bottom.

signal done()

enum Phase { IDLE, THINK, THINK_PAUSE, UTTERANCE, FADING, DONE }

const MAX_WIDTH: int = 240
const MIN_WIDTH: int = 120
const VISIBLE_LINES: int = 3
const LINE_HEIGHT: float = 18.0
const FIXED_CONTENT_HEIGHT: float = LINE_HEIGHT * VISIBLE_LINES  # 54px, never grows
const PAD_H: int = 12
const PAD_V: int = 8
const TAIL_W: float = 12.0
const TAIL_H: float = 7.0
const FONT_SIZE: int = 12
const COLOR_BG: Color = Color(1, 1, 1, 0.96)
const COLOR_TEXT: Color = Color(0.12, 0.12, 0.12)
const COLOR_THINK: Color = Color(0.25, 0.40, 0.80)
const COLOR_THINK_BG: Color = Color(0.92, 0.95, 0.98, 0.92)
const TYPEWRITER_INTERVAL: float = 0.06
const THINK_PAUSE: float = 0.5
const FADE_DURATION: float = 0.3
const MIN_UTT_TIME: float = 2.0
const AUTO_FADE_DELAY: float = 0.8

var _panel: Panel
var _scroll: ScrollContainer
var _label: RichTextLabel
var _icon: Label
var _think_bg: ColorRect
var _typewriter: Timer
var _cn_font: FontVariation = null

var _phase: int = Phase.IDLE
var _think_text: String = ""
var _think_pos: int = 0
var _utterances: Array = []
var _utter_idx: int = 0
var _utter_text: String = ""
var _utter_pos: int = 0
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

	if not _label:
		push_error("DialogueBubble: UI not built")
		return

	# Full clear
	_label.clear()
	_label.text = ""
	visible = true
	modulate = Color.WHITE

	# Setup fixed size IMMEDIATELY — before any text
	_setup_fixed_size()
	_needs_resize = true

	if _think_text.is_empty():
		print("[Bubble] skip think, start utterance")
		_start_utterance(my_seq)
	else:
		print("[Bubble] think phase start: %d chars" % _think_text.length())
		_phase = Phase.THINK
		_icon.text = "🤔"
		_icon.modulate = Color.WHITE
		_label.add_theme_color_override("default_color", COLOR_THINK)
		_think_bg.visible = true
		_think_bg.modulate = Color.WHITE
		_typewriter.start(TYPEWRITER_INTERVAL)


func follow_screen_position(cx: float, by: float) -> void:
	position.x = cx - size.x * 0.5
	position.y = by - size.y - 20.0 + _bubble_offset_y


func set_offset_y(y: float) -> void:
	_bubble_offset_y = y


# ═══════════════════════════════════════════════════════════════════════
#  UI Build — fixed 3-line window
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
	_panel.add_theme_stylebox_override("panel", style)

	_think_bg = ColorRect.new()
	_think_bg.color = COLOR_THINK_BG
	_think_bg.mouse_filter = MOUSE_FILTER_IGNORE
	_think_bg.visible = false
	_panel.add_child(_think_bg)

	# ScrollContainer — size is FIXED to FIXED_CONTENT_HEIGHT, never grows
	_scroll = ScrollContainer.new()
	_scroll.mouse_filter = MOUSE_FILTER_IGNORE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED  # no scroll bar at all
	_panel.add_child(_scroll)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(row)

	_icon = Label.new()
	_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_icon.custom_minimum_size = Vector2(20, 0)
	if _cn_font:
		_icon.add_theme_font_override("font", _cn_font)
	row.add_child(_icon)

	_label = RichTextLabel.new()
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.fit_content = false  # CRITICAL: don't auto-grow
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_label.add_theme_color_override("default_color", COLOR_THINK)
	# Fixed size: width = MAX_WIDTH - icon - padding, height = FIXED_CONTENT_HEIGHT
	_label.custom_minimum_size = Vector2(MAX_WIDTH - PAD_H - 24, FIXED_CONTENT_HEIGHT)
	_label.size = Vector2(MAX_WIDTH - PAD_H - 24, FIXED_CONTENT_HEIGHT)
	_label.bbcode_enabled = true
	if _cn_font:
		_label.add_theme_font_override("normal_font", _cn_font)
	row.add_child(_label)


## Setup fixed panel/scroll/label sizes. These NEVER change regardless of content.
func _setup_fixed_size() -> void:
	var bw: float = MAX_WIDTH
	var bh: float = FIXED_CONTENT_HEIGHT + PAD_V + TAIL_H  # 54 + 8 + 7 = 69px

	size = Vector2(bw, bh)
	var panel_h: float = bh - TAIL_H  # 62px
	if _panel:
		_panel.size = Vector2(bw, panel_h)
	if _think_bg:
		_think_bg.position = Vector2.ZERO
		_think_bg.size = Vector2(bw, panel_h)
	if _scroll:
		_scroll.position = Vector2(PAD_H * 0.5, PAD_V * 0.5)
		_scroll.size = Vector2(bw - PAD_H, FIXED_CONTENT_HEIGHT)  # FIXED 54px
	# Label is fixed height too — overflow is clipped by ScrollContainer
	_label.size = Vector2(MAX_WIDTH - PAD_H - 24, FIXED_CONTENT_HEIGHT)

	queue_redraw()


func _reflow() -> void:
	# Size is FIXED — just update scrollbar position
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
	# Auto-scroll to bottom every frame (shows last 3 lines)
	var sb: VScrollBar = _scroll.get_v_scroll_bar() if _scroll else null
	if sb and sb.max_value > 0:
		_scroll.scroll_vertical = int(sb.max_value)


# ═══════════════════════════════════════════════════════════════════════
#  Typewriter phases
# ═══════════════════════════════════════════════════════════════════════

func _on_tick() -> void:
	var my_seq: int = _seq
	if _phase == Phase.THINK:
		_think_pos += 1
		if _think_pos > _think_text.length():
			_typewriter.stop()
			_end_think_phase(my_seq)
			return
		_label.text = _think_text.left(_think_pos)
		_needs_resize = true

	elif _phase == Phase.UTTERANCE:
		_utter_pos += 1
		if _utter_pos > _utter_text.length():
			_typewriter.stop()
			_utterance_display_done(my_seq)
			return
		_label.text = _utter_text.left(_utter_pos)
		_needs_resize = true


func _end_think_phase(my_seq: int) -> void:
	print("[Bubble] think done, transitioning to utterance")
	_phase = Phase.THINK_PAUSE
	await get_tree().create_timer(THINK_PAUSE).timeout
	if my_seq != _seq or not is_instance_valid(self):
		return
	# CLEAR think text completely
	_label.text = ""
	_think_bg.visible = false
	_icon.text = "🗣"
	_label.add_theme_color_override("default_color", COLOR_TEXT)
	_needs_resize = true
	_start_utterance(my_seq)


func _start_utterance(my_seq: int) -> void:
	if my_seq >= 0 and my_seq != _seq:
		return
	if not is_instance_valid(self):
		return
	if _utter_idx >= _utterances.size():
		print("[Bubble] all utterances done, fading")
		_phase = Phase.DONE
		done.emit()
		_auto_fade_out()
		return

	_utter_text = str(_utterances[_utter_idx])
	_utter_pos = 0
	_phase = Phase.UTTERANCE
	_label.text = ""
	print("[Bubble] utterance %d/%d: %d chars" % [_utter_idx + 1, _utterances.size(), _utter_text.length()])
	_typewriter.start(TYPEWRITER_INTERVAL)


func _utterance_display_done(my_seq: int) -> void:
	if my_seq != _seq or not is_instance_valid(self):
		return
	_utter_idx += 1
	_needs_resize = true

	var display_time: float = maxf(float(_utter_text.length()) / 7.0, MIN_UTT_TIME)
	await get_tree().create_timer(display_time).timeout
	if my_seq != _seq or not is_instance_valid(self):
		return
	if _utter_idx >= _utterances.size():
		print("[Bubble] all utterances done, fading")
		_phase = Phase.DONE
		done.emit()
		_auto_fade_out()
	else:
		_start_utterance(my_seq)


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
