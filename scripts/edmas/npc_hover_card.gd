extends PanelContainer
class_name NpcHoverCard

var _content: VBoxContainer = VBoxContainer.new()
var _title_label: Label = Label.new()
var _display_label: Label = Label.new()
var _role_label: Label = Label.new()
var _floor_label: Label = Label.new()
var _state_label: Label = Label.new()
var _location_label: Label = Label.new()
var _goal_label: Label = Label.new()
var _llm_label: Label = Label.new()
var _resource_label: Label = Label.new()
var _scheduler_label: Label = Label.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(280.0, 180.0)
	_build_ui()
	visible = false

func _build_ui() -> void:
	if _content.get_parent() == null:
		add_child(_content)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 2)

	_title_label.text = "角色状态"
	_content.add_child(_title_label)

	_display_label.text = "display_name: -"
	_content.add_child(_display_label)

	_role_label.text = "role: -"
	_content.add_child(_role_label)

	_floor_label.text = "floor: -"
	_content.add_child(_floor_label)

	_state_label.text = "current_state: -"
	_content.add_child(_state_label)

	_location_label.text = "current_location: -"
	_content.add_child(_location_label)

	_goal_label.text = "current_goal: -"
	_content.add_child(_goal_label)

	_llm_label.text = "llm_enabled: false"
	_content.add_child(_llm_label)

	_resource_label.text = "resource_role: -"
	_content.add_child(_resource_label)

	_scheduler_label.text = "scheduler_eligible: false"
	_content.add_child(_scheduler_label)

func show_profile(profile: Dictionary) -> void:
	visible = true
	_title_label.text = str(profile.get("display_name", "角色状态"))
	_display_label.text = "display_name: %s" % str(profile.get("display_name", "-"))
	_role_label.text = "role: %s" % str(profile.get("role", "-"))
	_floor_label.text = "floor: %s" % str(profile.get("floor", "-"))
	_state_label.text = "current_state: %s" % str(profile.get("current_state", "-"))
	_location_label.text = "current_location: %s" % str(profile.get("current_location", "-"))
	_goal_label.text = "current_goal: %s" % str(profile.get("current_goal", "-"))
	_llm_label.text = "llm_enabled: %s" % str(bool(profile.get("llm_enabled", false)))
	_resource_label.text = "resource_role: %s" % str(profile.get("resource_role", "-"))
	_scheduler_label.text = "scheduler_eligible: %s" % str(bool(profile.get("scheduler_eligible", false)))

func clear_card() -> void:
	visible = false
	_title_label.text = "角色状态"
	_display_label.text = "display_name: -"
	_role_label.text = "role: -"
	_floor_label.text = "floor: -"
	_state_label.text = "current_state: -"
	_location_label.text = "current_location: -"
	_goal_label.text = "current_goal: -"
	_llm_label.text = "llm_enabled: false"
	_resource_label.text = "resource_role: -"
	_scheduler_label.text = "scheduler_eligible: false"
