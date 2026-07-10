extends RefCounted
class_name ScenarioConfig

const SCENARIO_ID: String = "role_world_runtime_v1"
const DEFAULT_FLOOR_ID: String = "F1"
const FLOOR_ORDER: Array = ["F1", "F2", "F3"]
const HOVER_RADIUS: float = 120.0
const WORLD_ORIGIN: Vector2 = Vector2.ZERO
const HOVER_CARD_TITLE: String = "角色状态"

static func get_floor_order() -> Array:
	return FLOOR_ORDER.duplicate(true)

static func get_default_floor_id() -> String:
	return DEFAULT_FLOOR_ID

