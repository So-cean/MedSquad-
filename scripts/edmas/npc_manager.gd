extends Node
class_name NpcManager

const HOVER_RADIUS := ScenarioConfig.HOVER_RADIUS
const ROLE_INIT_PREFIX := "[ROLE INIT]"

@export var hover_card_path: NodePath

var _room_root: Node = null
var _hover_card: NpcHoverCard = null
var _managed_npcs: Array[Node2D] = []
var _node_to_profile: Dictionary = {}
var _player_node: Node2D = null

func _ready() -> void:
	_room_root = get_parent()
	_hover_card = get_node_or_null(hover_card_path) as NpcHoverCard
	_initialize_floor("F1")

func _process(_delta: float) -> void:
	_update_hover_card()

func _initialize_floor(floor_id: String) -> void:
	var spawn_plan: Array = ResourceRegistry.get_spawn_plan(floor_id)
	for entry_value: Variant in spawn_plan:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value as Dictionary
		var npc_id: String = str(entry.get("npc_id", ""))
		if npc_id.is_empty():
			continue
		var profile: Dictionary = ResourceRegistry.get_role_profile(npc_id)
		if profile.is_empty():
			push_warning("NpcManager: missing profile for %s" % npc_id)
			continue
		var node: Node2D = _resolve_or_spawn_node(entry, profile)
		if node == null:
			continue
		_apply_profile(node, profile)
		_log_role_init(profile)
		if str(profile.get("role", "")) == "player":
			_player_node = node
			continue
		if node not in _managed_npcs:
			_managed_npcs.append(node)
			_node_to_profile[node] = profile

func _resolve_or_spawn_node(entry: Dictionary, profile: Dictionary) -> Node2D:
	var node_name: String = str(entry.get("scene_node_name", ""))
	var spawn_position_value: Variant = entry.get("spawn_position", profile.get("spawn_position", Vector2.ZERO))
	var spawn_position: Vector2 = Vector2.ZERO
	if typeof(spawn_position_value) == TYPE_VECTOR2:
		spawn_position = spawn_position_value as Vector2
	var node: Node2D = null
	if not node_name.is_empty() and _room_root != null:
		node = _room_root.get_node_or_null(node_name) as Node2D
	if node == null and str(entry.get("spawn_mode", "")) != "existing_only":
		var scene_path: String = str(entry.get("scene_path", ""))
		if not scene_path.is_empty():
			var packed_scene: PackedScene = load(scene_path) as PackedScene
			if packed_scene != null:
				var instance: Node = packed_scene.instantiate()
				node = instance as Node2D
				if node != null:
					node.name = node_name if not node_name.is_empty() else str(profile.get("npc_id", "MapNpc"))
					if _room_root != null:
						_room_root.add_child(node)
					node.global_position = spawn_position
	if node != null:
		node.global_position = spawn_position
	return node

func _apply_profile(node: Node2D, profile: Dictionary) -> void:
	node.set_meta("npc_id", str(profile.get("npc_id", "")))
	node.set_meta("display_name", str(profile.get("display_name", "")))
	node.set_meta("role", str(profile.get("role", "")))
	node.set_meta("floor", str(profile.get("floor", "")))
	node.set_meta("current_location", str(profile.get("home_location", "")))
	node.set_meta("current_state", str(profile.get("idle_mode", "idle")))
	node.set_meta("current_goal", str(profile.get("current_goal", "observe")))
	node.set_meta("llm_enabled", bool(profile.get("llm_enabled", false)))
	node.set_meta("resource_role", profile.get("resource_role", null))
	node.set_meta("scheduler_eligible", bool(profile.get("scheduler_eligible", false)))
	node.set_meta("background", str(profile.get("background", "")))
	node.set_meta("patrol_area", profile.get("patrol_area", []))
	if node.has_method("apply_role_profile"):
		node.call("apply_role_profile", profile)
	if node.has_method("set_wander_enabled") and str(profile.get("idle_mode", "")) != "controlled":
		node.call("set_wander_enabled", false)

func _log_role_init(profile: Dictionary) -> void:
	print("%s id=%s role=%s floor=%s location=%s llm=%s resource=%s" % [
		ROLE_INIT_PREFIX,
		str(profile.get("npc_id", "")),
		str(profile.get("role", "")),
		str(profile.get("floor", "")),
		str(profile.get("home_location", "")),
		str(bool(profile.get("llm_enabled", false))),
		str(profile.get("resource_role", null)),
	])

func _update_hover_card() -> void:
	if _hover_card == null:
		return
	var hovered: Node2D = _pick_hovered_npc()
	if hovered == null:
		_hover_card.clear_card()
		return
	var payload: Dictionary = _build_hover_payload(hovered)
	_hover_card.show_profile(payload)

func _pick_hovered_npc() -> Node2D:
	if _room_root == null:
		return null
	var camera: Camera2D = _get_camera()
	if camera == null:
		return null
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var world_mouse: Vector2 = camera.get_canvas_transform().affine_inverse() * mouse_pos
	var nearest: Node2D = null
	var nearest_distance: float = HOVER_RADIUS
	for npc in _managed_npcs:
		if npc == null or not is_instance_valid(npc):
			continue
		var distance: float = npc.global_position.distance_to(world_mouse)
		if distance <= nearest_distance:
			nearest = npc
			nearest_distance = distance
	if nearest == null and _player_node != null and is_instance_valid(_player_node):
		var player_distance: float = _player_node.global_position.distance_to(world_mouse)
		if player_distance <= nearest_distance:
			nearest = _player_node
	return nearest

func _get_camera() -> Camera2D:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_2d()

func _build_hover_payload(node: Node2D) -> Dictionary:
	var payload: Dictionary = {}
	var profile_value: Variant = node.get_meta("role_profile", {})
	if typeof(profile_value) == TYPE_DICTIONARY:
		payload = profile_value as Dictionary
	payload["npc_id"] = str(node.get_meta("npc_id", node.name))
	payload["display_name"] = str(node.get_meta("display_name", node.name))
	payload["role"] = str(node.get_meta("role", "npc"))
	payload["floor"] = str(node.get_meta("floor", ""))
	payload["current_state"] = str(node.get_meta("current_state", "idle"))
	payload["current_location"] = str(node.get_meta("current_location", ""))
	payload["current_goal"] = str(node.get_meta("current_goal", ""))
	payload["llm_enabled"] = bool(node.get_meta("llm_enabled", false))
	payload["resource_role"] = node.get_meta("resource_role", null)
	payload["scheduler_eligible"] = bool(node.get_meta("scheduler_eligible", false))
	return payload

func get_registered_npcs() -> Array:
	return _managed_npcs.duplicate(true)
