class_name DialogueBubble
extends Control

## Speech-bubble UI that follows an NPC in screen-space.
##
## Single shared text area:
##   Phase 1:  show think (blue text, 🤔 icon)  — typewriter reveal
##   Phase 2:  clear → show dialogue (dark text, 🗣 icon)
##
## Layout:
##   root Control
##     └─ Panel
##          └─ ScrollContainer (max height)
##               └─ HBoxContainer (icon + shared RichTextLabel)

# ── Visual constants ──
const MAX_WIDTH := 220
const MIN_WIDTH := 120
const MAX_HEIGHT := 180.0
const PAD_H := 16
const PAD_V := 10
const TAIL_W := 14.0
const TAIL_H := 8.0
const FONT_SIZE := 13
const FONT_SIZE_ICON := 16
const COLOR_BG := Color(1, 1, 1, 0.95)
const COLOR_TEXT := Color(0.15, 0.15, 0.15)
const COLOR_THINK := Color(0.25, 0.40, 0.80)   # blue  ← user request
const COLOR_THINK_BG := Color(0.92, 0.95, 0.98, 0.92)

const TYPEWRITER_INTERVAL := 0.04
const THINK_PAUSE := 0.5
const CROSSFADE := 0.25

# ── Child references ──
var _panel: Panel
var _scroll: ScrollContainer
var _content_row: HBoxContainer
var _icon: Label
var _text_label: RichTextLabel
var _think_bg: ColorRect
var _typewriter: Timer

# ── State ──
var _think_text: String = ""
var _think_pos: int = 0
var _random_phase: float = 0.0
var _current_entry: DialogueEntry = null
var _needs_resize := false
var _is_fading := false
var _fade_tween: Tween = null
var _in_think_phase := true


func _init() -> void:
	_random_phase = randf_range(0.0, TAU)
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build_ui()
	_typewriter = Timer.new()
	_typewriter.one_shot = false
	_typewriter.timeout.connect(_on_typewriter_tick)
	add_child(_typewriter)
	hide()


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
	var colors := PackedColorArray([COLOR_BG, COLOR_BG, COLOR_BG])
	draw_primitive(pts, colors, pts)


func _process(_delta: float) -> void:
	if _needs_resize:
		_needs_resize = false
		_reflow()


# ═══════════════════════════════════════════════════════════════════════
#  Public API
# ═══════════════════════════════════════════════════════════════════════

func is_available() -> bool:
	return not visible and not _is_fading


func fade_out() -> void:
	if _is_fading or not visible:
		return
	_is_fading = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.4)
	_fade_tween.tween_callback(_on_fade_complete)


func _on_fade_complete() -> void:
	visible = false
	modulate = Color.WHITE
	_is_fading = false
	_fade_tween = null


func cancel_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_is_fading = false
	_fade_tween = null
	modulate = Color.WHITE


## Display a dialogue entry.  Sequence: think typewriter → fade → dialogue.
func show_entry(entry: DialogueEntry) -> void:
	if _is_fading:
		cancel_fade()
	_current_entry = entry
	if entry.is_empty():
		hide()
		return

	_think_text = entry.think
	var dialogue_text: String = entry.dialogue

	# Reset
	_think_pos = 0
	_text_label.text = ""
	_text_label.modulate = Color.WHITE
	_think_bg.modulate = Color.WHITE
	_content_row.modulate = Color.WHITE
	_in_think_phase = true
	visible = true
	_needs_resize = true

	if _think_text.is_empty():
		# No think → straight to dialogue
		_in_think_phase = false
		_icon.text = "🗣"
		_icon.add_theme_font_size_override("font_size", FONT_SIZE)
		_text_label.add_theme_color_override("default_color", COLOR_TEXT)
		_text_label.text = dialogue_text
		_think_bg.hide()
	else:
		# Phase 1: show think in blue
		_icon.text = "🤔"
		_icon.add_theme_font_size_override("font_size", FONT_SIZE)
		_text_label.add_theme_color_override("default_color", COLOR_THINK)
		_text_label.text = ""
		_think_bg.show()
		_typewriter.start(TYPEWRITER_INTERVAL)


func follow_screen_position(screen_center_x: float, screen_base_y: float) -> void:
	var float_offset: float = sin(Time.get_ticks_msec() * 0.0025 + _random_phase) * 3.0
	position.x = screen_center_x - size.x * 0.5
	position.y = screen_base_y - size.y - 16.0 + float_offset


# ═══════════════════════════════════════════════════════════════════════
#  Internal
# ═══════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# ── Panel ──
	_panel = Panel.new()
	_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_panel.name = "BubblePanel"
	add_child(_panel)

	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_BG
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	s.shadow_size = 6
	s.shadow_color = Color(0, 0, 0, 0.18)
	_panel.add_theme_stylebox_override("panel", s)

	# ── Think background (blue tint behind content during think phase) ──
	_think_bg = ColorRect.new()
	_think_bg.color = COLOR_THINK_BG
	_think_bg.mouse_filter = MOUSE_FILTER_IGNORE
	_think_bg.name = "ThinkBg"
	_panel.add_child(_think_bg)

	# ── ScrollContainer (max height wrapper) ──
	_scroll = ScrollContainer.new()
	_scroll.mouse_filter = MOUSE_FILTER_IGNORE
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel.add_child(_scroll)

	# ── Single shared content row: icon + text ──
	_content_row = HBoxContainer.new()
	_content_row.mouse_filter = MOUSE_FILTER_IGNORE
	_content_row.name = "ContentRow"
	_content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content_row)

	_icon = Label.new()
	_icon.text = "🤔"
	_icon.add_theme_font_size_override("font_size", FONT_SIZE_ICON)
	_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_icon.custom_minimum_size = Vector2(22, 0)
	_content_row.add_child(_icon)

	_text_label = RichTextLabel.new()
	_text_label.name = "TextLabel"
	_text_label.mouse_filter = MOUSE_FILTER_IGNORE
	_text_label.fit_content = true
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.scroll_following = true
	_text_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_text_label.add_theme_color_override("default_color", COLOR_THINK)
	_text_label.custom_minimum_size = Vector2(MAX_WIDTH - 48, 0)
	_content_row.add_child(_text_label)


func _reflow() -> void:
	var content_min := _content_row.get_combined_minimum_size()
	var bw: float = clamp(content_min.x + PAD_H, MIN_WIDTH, MAX_WIDTH)
	var content_h := content_min.y + PAD_V
	var bh: float = minf(content_h, MAX_HEIGHT) + TAIL_H

	size = Vector2(bw, bh)

	var panel_h := bh - TAIL_H
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(bw, panel_h)

	_scroll.position = Vector2(PAD_H * 0.5, PAD_V * 0.5)
	_scroll.size = Vector2(bw - PAD_H, panel_h - PAD_V)

	_content_row.size = Vector2(bw - PAD_H - 4, content_min.y)

	# Think-bg fills panel behind scroll
	_think_bg.position = Vector2.ZERO
	_think_bg.size = Vector2(bw, panel_h) if _in_think_phase else Vector2.ZERO

	# Auto-scroll to bottom
	var sb := _scroll.get_v_scroll_bar()
	if sb:
		_scroll.scroll_vertical = sb.max_value

	queue_redraw()


func _on_typewriter_tick() -> void:
	_think_pos += 1
	if _think_pos > _think_text.length():
		_typewriter.stop()
		_start_think_fadeout()
		return

	_text_label.text = _think_text.left(_think_pos)
	_needs_resize = true


func _start_think_fadeout() -> void:
	await get_tree().create_timer(THINK_PAUSE).timeout
	if not is_instance_valid(self):
		return

	_in_think_phase = false
	var t := create_tween()
	t.tween_property(_think_bg, "modulate", Color(1, 1, 1, 0), CROSSFADE)
	t.parallel().tween_property(_content_row, "modulate", Color(1, 1, 1, 0), CROSSFADE)
	t.tween_callback(_show_dialogue)


func _show_dialogue() -> void:
	if not is_instance_valid(self):
		return
	var dialogue_text: String = ""
	if _current_entry:
		dialogue_text = _current_entry.dialogue

	# Reset text area for dialogue
	_text_label.text = ""
	_text_label.add_theme_color_override("default_color", COLOR_TEXT)
	_icon.text = "🗣"
	_think_bg.hide()

	# Set dialogue text and fade in
	_text_label.text = dialogue_text
	_content_row.modulate = Color.WHITE
	_needs_resize = true
