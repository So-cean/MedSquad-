class_name NpcHoverCard
extends Control

## Floating card on mouse hover over NPC.
## Dark background, blue border, wraps all info.

const CARD_WIDTH: int = 260
const CARD_PAD: int = 10
const CARD_FONT_SIZE: int = 11
const CARD_BG: Color = Color(0.06, 0.06, 0.12, 0.95)
const CARD_BORDER: Color = Color(0.4, 0.6, 1.0, 0.9)
const COLOR_TITLE: Color = Color(1.0, 1.0, 1.0)
const COLOR_LABEL: Color = Color(0.55, 0.65, 0.8)
const COLOR_VALUE: Color = Color(0.95, 0.95, 1.0)

var _panel: Panel
var _vbox: VBoxContainer
var _title_label: Label
var _info_labels: Dictionary = {}
var _cn_font: FontVariation = null


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_load_font()
	_build_ui()
	hide()


func _load_font() -> void:
	_cn_font = FontRegistry.get_cn_font()


func _build_ui() -> void:
	# Panel — the visible background box
	_panel = Panel.new()
	_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_panel.anchors_preset = Control.PRESET_FULL_RECT
	add_child(_panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = CARD_BORDER
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.content_margin_left = CARD_PAD
	style.content_margin_right = CARD_PAD
	style.content_margin_top = CARD_PAD
	style.content_margin_bottom = CARD_PAD
	_panel.add_theme_stylebox_override("panel", style)

	# VBox holds all content
	_vbox = VBoxContainer.new()
	_vbox.mouse_filter = MOUSE_FILTER_IGNORE
	_vbox.anchors_preset = Control.PRESET_FULL_RECT
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 2)
	_panel.add_child(_vbox)

	# Title
	_title_label = _make_label(COLOR_TITLE, CARD_FONT_SIZE + 2)
	_vbox.add_child(_title_label)

	# Info rows
	for key in ["role", "state", "location", "status"]:
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)

		var lbl: Label = _make_label(COLOR_LABEL, CARD_FONT_SIZE)
		lbl.text = key + ":"
		row.add_child(lbl)

		var val: Label = _make_label(COLOR_VALUE, CARD_FONT_SIZE)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.language = "zh"
		val.autowrap_mode = TextServer.AUTOWRAP_OFF  # 短文本不换行
		row.add_child(val)

		_vbox.add_child(row)
		_info_labels[key] = val

	# Set fixed width
	custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_panel.custom_minimum_size = Vector2(CARD_WIDTH, 0)


func _make_label(color: Color, font_size: int) -> Label:
	var l: Label = Label.new()
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if _cn_font:
		l.add_theme_font_override("font", _cn_font)
	return l


func show_card(npc: BaseNpc, mouse_pos: Vector2) -> void:
	if not npc:
		hide()
		return

	_title_label.text = npc.get_npc_name()

	# Role
	var role: String = "未知"
	if NpcManager:
		role = NpcManager.get_role(NpcManager.get_npc_id(npc))
	match role:
		"nurse": role = "护士"
		"doctor": role = "医生"
		"patient": role = "患者"
	_info_labels["role"].text = role

	# State
	_info_labels["state"].text = npc.get_state_name()

	# Location
	var loc: String = ""
	if HospitalMapData:
		loc = HospitalMapData.get_location_name(npc.global_position)
	_info_labels["location"].text = loc if not loc.is_empty() else "未知"

	# Status
	var status: String = "待机"
	if npc.is_walking():
		status = "移动中"
	elif npc.get_dialogue_entry() and not npc.get_dialogue_entry().is_empty():
		status = "对话中"
	_info_labels["status"].text = status

	# Resize panel to fit content
	await get_tree().process_frame  # wait one frame for layout
	var content_size: Vector2 = _vbox.get_combined_minimum_size()
	var card_w: float = CARD_WIDTH
	var card_h: float = content_size.y + CARD_PAD * 2
	size = Vector2(card_w, card_h)
	_panel.size = Vector2(card_w, card_h)

	# Position near mouse, clamped to viewport
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	position.x = clamp(mouse_pos.x + 15, 0, vp_size.x - card_w)
	position.y = clamp(mouse_pos.y + 15, 0, vp_size.y - card_h)

	visible = true


func hide_card() -> void:
	hide()
