class_name DeviceRegistry
extends RefCounted

var _locations: Dictionary = {}
var _devices: Dictionary = {}


func configure_from_timeline(timeline: Dictionary) -> void:
	_locations.clear()
	_devices.clear()
	for action in timeline.get("actions", []):
		if not (action is Dictionary):
			continue
		var location_id: String = action.get("location_id", "")
		if not location_id.is_empty() and action.has("position"):
			var position: Dictionary = action.get("position", {})
			_locations[location_id] = Vector2(float(position.get("x", 0.0)), float(position.get("y", 0.0)))
		var device_id: String = action.get("device_id", "")
		if not device_id.is_empty():
			_devices[device_id] = action


func get_location_position(location_id: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return _locations.get(location_id, fallback)


func has_device(device_id: String) -> bool:
	return _devices.has(device_id)
