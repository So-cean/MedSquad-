extends Node

## Hospital map data — named locations → Vector2 positions.
## Add as autoload "HospitalMapData" in project.godot.
##
## Used by:
##   - NPC navigation (walk_to("TRIAGE"))
##   - LLM prompts (current location context: "你在分诊台")
##   - Map system (elevator zone triggers)

# Map 1: ED Core / 急诊核心接入区
const LOCATIONS_ED_CORE: Dictionary = {
	"ED_ENTRANCE": Vector2(830, 800),
	"TRIAGE": Vector2(830, 470),
	"WAITING_AREA": Vector2(340, 590),
	"DOCTOR": Vector2(1330, 500),
	"ED_RESUS": Vector2(340, 200),
	"ELEVATOR_ED": Vector2(840, 120),
}

# Map 2: Diagnostics / 检查诊断区
const LOCATIONS_DIAGNOSTICS: Dictionary = {
	"LAB": Vector2(350, 270),
	"IMAGING": Vector2(1280, 250),
	"DIAGNOSTIC_WAITING": Vector2(290, 680),
	"RESULT_REVIEW": Vector2(1290, 680),
	"ELEVATOR_DIAGNOSTICS": Vector2(840, 120),
}

# Map 3: Downstream / 转归与下游资源区
const LOCATIONS_DOWNSTREAM: Dictionary = {
	"ICU": Vector2(340, 230),
	"WARD": Vector2(1290, 260),
	"DISPOSITION": Vector2(830, 550),
	"ED_BOARDING": Vector2(340, 700),
	"DISCHARGE": Vector2(830, 825),
	"DISCHARGE_ADMIN": Vector2(1270, 770),
	"ELEVATOR_DOWNSTREAM": Vector2(840, 120),
}

# Current map's locations (updated when floor changes)
var locations: Dictionary = LOCATIONS_ED_CORE

# Floor tracking
enum Floor { ED_CORE, DIAGNOSTICS, DOWNSTREAM }
var current_floor: int = Floor.ED_CORE


func set_floor(floor_id: int) -> void:
	current_floor = floor_id
	match floor_id:
		Floor.ED_CORE: locations = LOCATIONS_ED_CORE
		Floor.DIAGNOSTICS: locations = LOCATIONS_DIAGNOSTICS
		Floor.DOWNSTREAM: locations = LOCATIONS_DOWNSTREAM


func get_location(name: String) -> Vector2:
	if locations.has(name):
		return locations[name]
	push_error("HospitalMapData: unknown location '%s'" % name)
	return Vector2.ZERO


func get_location_name(pos: Vector2) -> String:
	# Find which named location is closest to pos
	var best_name: String = "未知"
	var best_dist: float = 99999.0
	for loc_name in locations:
		var dist: float = pos.distance_to(locations[loc_name])
		if dist < best_dist:
			best_dist = dist
			best_name = loc_name
	return best_name


func get_floor_name() -> String:
	match current_floor:
		Floor.ED_CORE: return "急诊核心区"
		Floor.DIAGNOSTICS: return "检查诊断区"
		Floor.DOWNSTREAM: return "转归下游区"
	return "未知"
