extends Node

## Map System — decoupled navigation + positioning + area triggers.
##
## Owns:
##   - NavigationRegion2D (baked from collision polygon)
##   - Path queries (get_path / walk_to for any CharacterBody2D)
##   - Area triggers (enter/leave named locations)
##   - Floor switching (elevator)
##
## Does NOT know about:
##   - NpcManager, ConversationContext, DialogueSystem
##   - LLM, MemoryStore
##   - Player input
##
## Other systems call MapSystem for navigation only.



# Navigation
var _nav_region: NavigationRegion2D = null
var _nav_ready: bool = false

# Area triggers: Area2D nodes keyed by location name
var _areas: Dictionary = {}  # location_name → Area2D
var _npc_locations: Dictionary = {}  # npc instance_id → current location name


func _ready() -> void:
	# Wait for scene to load, then setup navigation
	await get_tree().process_frame
	_setup_navigation()
	_setup_area_triggers()


# ══════════════════════════════════════════════════════════════════════
#  Navigation setup
# ══════════════════════════════════════════════════════════════════════

func _setup_navigation() -> void:
	# Look for existing NavigationRegion2D in scene
	_nav_region = get_tree().current_scene.get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	if not _nav_region:
		# Create one from collision data
		_nav_region = _build_nav_region_from_collision()
		if _nav_region:
			get_tree().current_scene.add_child(_nav_region)

	if _nav_region:
		# Wait for nav map to sync
		await get_tree().physics_frame
		await get_tree().physics_frame
		_nav_ready = true
		print("[MapSystem] Navigation ready")
	else:
		push_warning("[MapSystem] No NavigationRegion2D found, navigation disabled")


func _build_nav_region_from_collision() -> NavigationRegion2D:
	# Try to find collision polygon in scene and derive navmesh from it
	var scene: Node = get_tree().current_scene
	if not scene:
		return null

	# Look for the collision polygon (wall outline)
	var collision_body: Node = scene.get_node_or_null("Collision")
	if not collision_body:
		return null

	var wall_poly: CollisionPolygon2D = collision_body.get_child(0) as CollisionPolygon2D
	if not wall_poly:
		return null

	# Bake navmesh using the non-deprecated API
	var region: NavigationRegion2D = NavigationRegion2D.new()
	region.name = "NavigationRegion2D"

	var nav_poly: NavigationPolygon = NavigationPolygon.new()
	var source: NavigationMeshSourceGeometryData2D = NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(wall_poly.polygon)
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source)

	region.navigation_polygon = nav_poly
	return region


# ══════════════════════════════════════════════════════════════════════
#  Area triggers setup
# ══════════════════════════════════════════════════════════════════════

func _setup_area_triggers() -> void:
	# Find all Marker2D nodes in scene and create Area2D triggers around them
	var scene: Node = get_tree().current_scene
	if not scene:
		return

	for child in scene.get_children():
		if child is Marker2D:
			var marker: Marker2D = child as Marker2D
			var loc_name: String = marker.name.replace("Marker_", "")
			_create_area_trigger(marker, loc_name, 60.0)


func _create_area_trigger(marker: Marker2D, location_name: String, radius: float) -> void:
	var area: Area2D = Area2D.new()
	area.name = "Area_" + location_name
	area.position = marker.position

	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius

	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	area.add_child(col)

	# Monitor body entry/exit
	area.monitoring = true
	area.monitorable = false
	area.collision_layer = 0
	area.collision_mask = 2  # NPC layer

	area.body_entered.connect(func(body): _on_body_entered(body, location_name))
	area.body_exited.connect(func(body): _on_body_exited(body, location_name))

	marker.get_parent().add_child(area)
	_areas[location_name] = area


func _on_body_entered(body: Node, location_name: String) -> void:
	if body is CharacterBody2D:
		var id: int = body.get_instance_id()
		_npc_locations[id] = location_name


func _on_body_exited(body: Node, location_name: String) -> void:
	if body is CharacterBody2D:
		var id: int = body.get_instance_id()
		_npc_locations.erase(id)

# ══════════════════════════════════════════════════════════════════════
#  Public API — Navigation
# ══════════════════════════════════════════════════════════════════════

func is_ready() -> bool:
	return _nav_ready


## Get a path from current position to a named location.
func query_path(from: Vector2, to_location: String) -> PackedVector2Array:
	if not _nav_ready:
		return PackedVector2Array()
	var target: Vector2 = HospitalMapData.get_location(to_location)
	var map_rid: RID = get_tree().current_scene.get_world_2d().get_navigation_map()
	return NavigationServer2D.map_get_path(map_rid, from, target, true)


## Get a path from current position to a raw position.
func query_path_to_pos(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not _nav_ready:
		return PackedVector2Array()
	var map_rid: RID = get_tree().current_scene.get_world_2d().get_navigation_map()
	return NavigationServer2D.map_get_path(map_rid, from, to, true)


## Ensure a CharacterBody2D has a NavigationAgent2D child.
## Returns the agent (existing or newly created).
func ensure_nav_agent(body: CharacterBody2D) -> NavigationAgent2D:
	var existing: Node = body.get_node_or_null("NavigationAgent2D")
	if existing is NavigationAgent2D:
		return existing as NavigationAgent2D

	var agent: NavigationAgent2D = NavigationAgent2D.new()
	agent.name = "NavigationAgent2D"
	agent.path_desired_distance = 8.0
	agent.target_desired_distance = 8.0
	body.add_child(agent)
	return agent


# ══════════════════════════════════════════════════════════════════════
#  Public API — Positioning
# ══════════════════════════════════════════════════════════════════════

## Get the location name an NPC is currently in.
func get_npc_location(npc: CharacterBody2D) -> String:
	var id: int = npc.get_instance_id()
	return _npc_locations.get(id, "")


## Get all NPCs currently in a named location.
func get_npcs_in(location_name: String) -> Array:
	var result: Array = []
	for id in _npc_locations:
		if _npc_locations[id] == location_name:
			var body: Node = instance_from_id(id)
			if body is CharacterBody2D:
				result.append(body)
	return result


# ══════════════════════════════════════════════════════════════════════
#  Public API — Floor switching
# ══════════════════════════════════════════════════════════════════════

const FLOOR_SCENES: Dictionary = {
	0: "res://scens/edmas/Floor_ED_Core.tscn",
	1: "res://scens/edmas/Floor_Diagnostics.tscn",
	2: "res://scens/edmas/Floor_Downstream.tscn",
}

func change_floor(floor_id: int) -> void:
	HospitalMapData.set_floor(floor_id)
	var path: String = FLOOR_SCENES.get(floor_id, "")
	if not path.is_empty():
		get_tree().change_scene_to_file(path)


func get_current_floor() -> int:
	return HospitalMapData.current_floor
