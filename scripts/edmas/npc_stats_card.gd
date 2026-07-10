extends PanelContainer
class_name NpcStatsCard

var _content: VBoxContainer = VBoxContainer.new()
var _title_label: Label = Label.new()
var _visible_label: Label = Label.new()
var _role_label: Label = Label.new()
var _scheduler_label: Label = Label.new()
var _floor_label: Label = Label.new()
var _configured_label: Label = Label.new()

var _room_root: Node = null
var _runtime_manager: Node = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(320.0, 160.0)
	position = Vector2(18.0, 18.0)
	_build_ui()
	_resolve_runtime_nodes()
	visible = true
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _build_ui() -> void:
	if _content.get_parent() == null:
		add_child(_content)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 2)

	_title_label.text = "NPC 状态统计"
	_content.add_child(_title_label)

	_visible_label.text = "visible_npcs: 0"
	_content.add_child(_visible_label)

	_role_label.text = "roles: -"
	_content.add_child(_role_label)

	_scheduler_label.text = "scheduler_eligible: 0"
	_content.add_child(_scheduler_label)

	_floor_label.text = "floors: -"
	_content.add_child(_floor_label)

	_configured_label.text = "configured floors: -"
	_content.add_child(_configured_label)

func _resolve_runtime_nodes() -> void:
	if _room_root == null and get_tree() != null:
		_room_root = get_tree().current_scene
	if _room_root != null:
		_runtime_manager = _room_root.get_node_or_null("RoleRuntime")

func _refresh() -> void:
	if _runtime_manager == null or not is_instance_valid(_runtime_manager):
		_resolve_runtime_nodes()
	if _runtime_manager == null:
		_title_label.text = "NPC 状态统计: unavailable"
		return

	var visible_npcs: Array = []
	if _runtime_manager.has_method("get_registered_npcs"):
		visible_npcs = _runtime_manager.get_registered_npcs()

	var role_counts: Dictionary = {}
	var floor_counts: Dictionary = {}
	var scheduler_count: int = 0

	for npc_value: Variant in visible_npcs:
		if typeof(npc_value) != TYPE_OBJECT:
			continue
		var npc: Node = npc_value as Node
		if npc == null or not is_instance_valid(npc):
			continue
		var role: String = str(npc.get_meta("role", "unknown"))
		var floor: String = str(npc.get_meta("floor", "unknown"))
		role_counts[role] = int(role_counts.get(role, 0)) + 1
		floor_counts[floor] = int(floor_counts.get(floor, 0)) + 1
		if bool(npc.get_meta("scheduler_eligible", false)):
			scheduler_count += 1

	var player_count: int = int(role_counts.get("player", 0))
	var doctor_count: int = int(role_counts.get("doctor", 0))
	var nurse_count: int = int(role_counts.get("nurse", 0))
	var other_count: int = visible_npcs.size() - player_count - doctor_count - nurse_count

	_visible_label.text = "visible_npcs: %d" % visible_npcs.size()
	_role_label.text = "roles: player=%d doctor=%d nurse=%d other=%d" % [
		player_count,
		doctor_count,
		nurse_count,
		max(other_count, 0),
	]
	_scheduler_label.text = "scheduler_eligible: %d" % scheduler_count
	_floor_label.text = "floors: F1=%d F2=%d F3=%d" % [
		int(floor_counts.get("F1", 0)),
		int(floor_counts.get("F2", 0)),
		int(floor_counts.get("F3", 0)),
	]
	_configured_label.text = "configured floors: F1=%d F2=%d F3=%d" % [
		RoleProfiles.get_profiles_for_floor("F1").size(),
		RoleProfiles.get_profiles_for_floor("F2").size(),
		RoleProfiles.get_profiles_for_floor("F3").size(),
	]
