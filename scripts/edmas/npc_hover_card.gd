class_name NpcHoverCard
extends Control

## Floating card that appears when mouse hovers over an NPC.
## Shows: name, role, state, location, brief status.
##
## Managed by NpcHoverSystem (autoload). Not instantiated directly.

const CARD_WIDTH: int = 200
const CARD_PAD: int = 10
const CARD_FONT_SIZE: int = 11
const CARD_BG: Color = Color(0.08, 0.08, 0.12, 0.92)
const CARD_BORDER: Color = Color(0.3, 0.5, 0.8, 0.8)
const COLOR_TITLE: Color = Color(0.9, 0.9, 1.0)
const COLOR_LABEL: Color = Color(0.5, 0.6, 0.7)
const COLOR_VALUE: Color = Color(0.85, 0.85, 0.9)

var _panel: Panel
var _vbox: VBoxContainer
var _title_label: Label
var _info_labels: Dictionary = {}  # key → Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_ui()
	hide()


func _build_ui() -> void:
	# Load Chinese font
	var tex: FontFile = load("res://assets/fonts/NotoSansSC-VF.ttf") as FontFile
	var cn_font: FontVariation = null
	if tex:
		cn_font = FontVariation.new()
		cn_font.base_font = tex

	_panel = Panel.new()
	_panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = CARD_BORDER
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = CARD_PAD
	style.content_margin_right = CARD_PAD
	style.content_margin_top = CARD_PAD
	style.content_margin_bottom = CARD_PAD
	_panel.add_theme_stylebox_override("panel", style)

	_vbox = VBoxContainer.new()
	_vbox.mouse_filter = MOUSE_FILTER_IGNORE
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(_vbox)

	# Title (NPC name)
	_title_label = Label.new()
	_title_label.mouse_filter = MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_size_override("font_size", CARD_FONT_SIZE + 1)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE)
	if cn_font:
		_title_label.add_theme_font_override("font", cn_font)
	_vbox.add_child(_title_label)

	# Info rows
	for key in ["role", "state", "location", "status"]:
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = MOUSE_FILTER_IGNORE

		var lbl: Label = Label.new()
		lbl.mouse_filter = MOUSE_FILTER_IGNORE
		lbl.text = key + ": "
		lbl.add_theme_font_size_override("font_size", CARD_FONT_SIZE)
		lbl.add_theme_color_override("font_color", COLOR_LABEL)
		if cn_font:
			lbl.add_theme_font_override("font", cn_font)
		row.add_child(lbl)

		var val: Label = Label.new()
		val.mouse_filter = MOUSE_FILTER_IGNORE
		val.add_theme_font_size_override("font_size", CARD_FONT_SIZE)
		val.add_theme_color_override("font_color", COLOR_VALUE)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if cn_font:
			val.add_theme_font_override("font", cn_font)
		row.add_child(val)

		_vbox.add_child(row)
		_info_labels[key] = val

	_panel.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_panel.size = Vector2(CARD_WIDTH, 100)


func show_card(npc: BaseNpc, mouse_pos: Vector2) -> void:
	if not npc:
		hide()
		return

	_title_label.text = npc.get_npc_name()

	# Role
	var role: String = "未知"
	var npc_data: Dictionary = {}
	if NpcManager and NpcManager.has_method("_npc_data"):
		npc_data = NpcManager._npc_data.get(NpcManager.get_npc_id(npc), {})
		role = npc_data.get("role", "未知")
	# Map role to Chinese
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

	# Status — what they're doing
	var status: String = "待机"
	if npc.is_walking():
		status = "移动中"
	elif npc.get_dialogue_entry() and not npc.get_dialogue_entry().is_empty():
		status = "对话中"
	_info_labels["status"].text = status

	# Position card near mouse
	size = _panel.get_combined_minimum_size() + Vector2(CARD_PAD * 2, CARD_PAD * 2)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	position.x = clamp(mouse_pos.x + 15, 0, vp_size.x - size.x)
	position.y = clamp(mouse_pos.y + 15, 0, vp_size.y - size.y)

	_panel.size = size
	visible = true


func hide_card() -> void:
	hide()
