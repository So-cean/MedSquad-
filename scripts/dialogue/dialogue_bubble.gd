class_name DialogueBubble
extends Control

signal done()

enum Phase { IDLE, THINK, UTTERANCE, FADING, DONE }

const MAX_WIDTH: int = 240
const EXPANDED_MAX_WIDTH: int = 360
const MIN_WIDTH: int = 120
const VISIBLE_LINES: int = 3
const EXPANDED_VISIBLE_LINES: int = 8
const LINE_HEIGHT: float = 18.0
const MAX_HEIGHT: float = LINE_HEIGHT * VISIBLE_LINES + 20.0
const EXPANDED_MAX_HEIGHT: float = LINE_HEIGHT * EXPANDED_VISIBLE_LINES + 20.0
const PAD_H: int = 12
const PAD_V: int = 8
const TAIL_W: float = 12.0
const TAIL_H: float = 7.0
const FONT_SIZE: int = 12
const COLOR_BG: Color = Color(1, 1, 1, 0.96)
const COLOR_TEXT: Color = Color(0.12, 0.12, 0.12)
const COLOR_HINT: Color = Color(0.36, 0.36, 0.36)
const FADE_DURATION: float = 0.3
const CHARS_PER_SEC: float = 10.0
const COMPACT_MAX_CHARS: int = 26
const COMPACT_HOLD_TIME: float = 2.8

var _panel: Panel
var _scroll: ScrollContainer
var _label: RichTextLabel
var _fade_tween: Tween = null

var _phase: int = Phase.IDLE
var _utterances: Array = []
var _current_entry: DialogueEntry = null
var _full_text: String = ""
var _compact_text: String = ""
var _expanded: bool = false
var _done_sent: bool = false
var _needs_resize: bool = false
var _is_fading: bool = false
var _seq: int = 0
var _bubble_offset_y: float = 0.0


func get_seq() -> int:
	return _seq


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP


func _ready() -> void:
	_build_ui()
	hide()


func is_available() -> bool:
	return not visible and not _is_fading


func fade_out() -> void:
	if _is_fading or not visible:
		return
	_is_fading = true
	_kill_tweens()
	_seq += 1
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	_fade_tween.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
		_is_fading = false
		_phase = Phase.DONE
	)
	_phase = Phase.FADING


func show_entry(entry: DialogueEntry) -> void:
	_seq += 1
	var my_seq: int = _seq

	if _is_fading:
		_kill_tweens()
		_is_fading = false
		modulate.a = 1.0

	_current_entry = entry
	if entry.is_empty():
		hide()
		return

	_utterances = entry.utterances.duplicate()
	if _utterances.is_empty() and not entry.dialogue.is_empty():
		_utterances = [entry.dialogue]
	_full_text = _build_full_text()
	_compact_text = _build_compact_text()
	_expanded = false
	_done_sent = false
	_phase = Phase.UTTERANCE

	if not _label or not _scroll:
		push_error("DialogueBubble: UI not fully built")
		return

	visible = true
	_show_current_text()
	_finish_compact_display(my_seq)


func follow_screen_position(cx: float, by: float) -> void:
	position.x = cx - size.x * 0.5
	position.y = by - size.y - 20.0 + _bubble_offset_y


func set_offset_y(y: float) -> void:
	_bubble_offset_y = y


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

	_scroll = ScrollContainer.new()
	_scroll.mouse_filter = MOUSE_FILTER_IGNORE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel.add_child(_scroll)

	_label = RichTextLabel.new()
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.fit_content = true
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.scroll_following = true
	_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_label.add_theme_color_override("default_color", COLOR_TEXT)
	_label.custom_minimum_size = Vector2(MAX_WIDTH - PAD_H, 0)
	_label.bbcode_enabled = false
	_scroll.add_child(_label)


func _process(_delta: float) -> void:
	if _needs_resize:
		_needs_resize = false
		_reflow()


func _reflow() -> void:
	if not _label:
		return
	var width_limit: int = EXPANDED_MAX_WIDTH if _expanded else MAX_WIDTH
	var height_limit: float = EXPANDED_MAX_HEIGHT if _expanded else MAX_HEIGHT
	_label.custom_minimum_size = Vector2(width_limit - PAD_H, 0)
	var label_min: Vector2 = _label.get_combined_minimum_size()
	var bw: float = clamp(label_min.x + PAD_H, MIN_WIDTH, width_limit)
	var content_h: float = minf(label_min.y, height_limit)
	var bh: float = content_h + PAD_V + TAIL_H

	size = Vector2(bw, bh)
	var panel_h: float = bh - TAIL_H
	_panel.size = Vector2(bw, panel_h)
	_scroll.position = Vector2(PAD_H * 0.5, PAD_V * 0.5)
	_scroll.size = Vector2(bw - PAD_H, panel_h - PAD_V)
	_label.size = Vector2(bw - PAD_H, label_min.y)

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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_expanded = not _expanded
			_show_current_text()
			accept_event()


func _build_full_text() -> String:
	var lines: Array[String] = []
	for utt in _utterances:
		var text: String = str(utt).strip_edges()
		if not text.is_empty():
			lines.append(text)
	if lines.is_empty():
		lines.append("...")
	return "\n".join(lines)


func _build_compact_text() -> String:
	var text: String = _full_text.replace("\n", " ").strip_edges()
	if text.is_empty():
		text = "..."
	var needs_more: bool = text.length() > COMPACT_MAX_CHARS or _full_text.contains("\n")
	if text.length() > COMPACT_MAX_CHARS:
		text = text.left(COMPACT_MAX_CHARS).strip_edges()
	if needs_more:
		text += " ..."
	return text


func _show_current_text() -> void:
	if not _label:
		return
	_label.add_theme_color_override("default_color", COLOR_TEXT if _expanded else COLOR_HINT)
	_label.text = _full_text if _expanded else _compact_text
	_needs_resize = true


func _finish_compact_display(my_seq: int) -> void:
	var display_time: float = maxf(float(_compact_text.length()) / CHARS_PER_SEC, COMPACT_HOLD_TIME)
	await get_tree().create_timer(display_time).timeout
	if my_seq != _seq or not is_instance_valid(self):
		return
	if not _done_sent:
		_done_sent = true
		done.emit()
	_auto_fade_out()


func _auto_fade_out() -> void:
	var my_seq: int = _seq
	await get_tree().create_timer(0.4).timeout
	if my_seq != _seq or not is_instance_valid(self):
		return
	while _expanded and my_seq == _seq and is_instance_valid(self):
		await get_tree().create_timer(0.5).timeout
	fade_out()


func _kill_tweens() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
