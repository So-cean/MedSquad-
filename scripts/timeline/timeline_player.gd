extends Node

const ActorRegistryScript = preload("res://scripts/timeline/actor_registry.gd")
const DeviceRegistryScript = preload("res://scripts/timeline/device_registry.gd")
const TimelineLoaderScript = preload("res://scripts/timeline/timeline_loader.gd")

@export var timeline_path := "res://data/timelines/headache_triage.timeline.json"
@export var auto_play := true
@export var report_events_to_http := false
@export var backend_base_url := "http://127.0.0.1:8000"

var _timeline: Dictionary = {}
var _actions: Array = []
var _index := 0
var _actor_registry := ActorRegistryScript.new()
var _device_registry := DeviceRegistryScript.new()
var _playing := false
var _simulation_id := ""


func _ready() -> void:
	if not auto_play:
		return
	await get_tree().process_frame
	load_and_play(timeline_path)


func load_and_play(path: String) -> void:
	_timeline = TimelineLoaderScript.new().load_timeline(path)
	if _timeline.is_empty():
		return
	_actions = _timeline.get("actions", [])
	_simulation_id = _timeline.get("simulation_id", "")
	_index = 0
	_actor_registry.scan(self)
	_device_registry.configure_from_timeline(_timeline)
	_playing = true
	print("TimelinePlayer: loaded %d actions from %s" % [_actions.size(), path])
	_execute_next()


func _execute_next() -> void:
	if not _playing:
		return
	if _index >= _actions.size():
		_finish()
		return

	var action: Dictionary = _actions[_index]
	_index += 1
	_emit_event("timeline_action_started", action)

	match action.get("type", ""):
		"move_to":
			await _do_move_to(action)
		"face_actor":
			_do_face_actor(action)
		"speak":
			await _do_speak(action)
		"wait":
			await _wait(float(action.get("duration", 1.0)))
		"use_device":
			await _do_use_device(action)
		"set_state":
			pass
		"end_simulation":
			_emit_event("simulation_completed", action)
			_finish()
			return
		_:
			push_warning("TimelinePlayer: unsupported action type: %s" % action.get("type", ""))

	_emit_event("timeline_action_completed", action)
	_execute_next()


func _do_move_to(action: Dictionary) -> void:
	var actor := _actor_registry.get_actor(action.get("actor_id", ""))
	if not actor:
		_emit_event("timeline_action_failed", action, {"error": "actor not found"})
		return

	var target := _target_position(action, actor.global_position)
	var duration: float = max(float(action.get("duration", 1.0)), 0.1)
	var start := actor.global_position
	var elapsed := 0.0
	actor.set_timeline_controlled(true)

	while elapsed < duration:
		var delta := get_process_delta_time()
		elapsed += delta
		var t: float = clamp(elapsed / duration, 0.0, 1.0)
		var next_pos := start.lerp(target, t)
		var velocity := (next_pos - actor.global_position) / max(delta, 0.001)
		actor.set_timeline_velocity(velocity)
		await get_tree().process_frame

	actor.global_position = target
	actor.set_timeline_velocity(Vector2.ZERO)
	actor.set_timeline_controlled(false)


func _do_face_actor(action: Dictionary) -> void:
	var actor := _actor_registry.get_actor(action.get("actor_id", ""))
	var target := _actor_registry.get_actor(action.get("target_actor_id", ""))
	if actor and target:
		actor.face_position(target.global_position)


func _do_speak(action: Dictionary) -> void:
	var actor := _actor_registry.get_actor(action.get("actor_id", ""))
	if not actor:
		_emit_event("timeline_action_failed", action, {"error": "actor not found"})
		return

	var target_id: String = action.get("target_actor_id", "")
	var target_name := target_id
	var target := _actor_registry.get_actor(target_id)
	if target:
		target_name = target.get_npc_name()

	var entry := DialogueEntry.new(actor.get_npc_name(), action.get("think", ""), action.get("dialogue", ""), target_name)
	actor.speak(entry)
	await _wait(float(action.get("duration", 3.0)))
	actor.stop_speaking()


func _do_use_device(action: Dictionary) -> void:
	var actor := _actor_registry.get_actor(action.get("actor_id", ""))
	var duration: float = max(float(action.get("duration", 1.0)), 0.1)
	if actor:
		var device_name: String = action.get("payload", {}).get("device_name", action.get("device_id", "设备"))
		var result: String = action.get("payload", {}).get("result", "检查完成")
		var entry := DialogueEntry.new(actor.get_npc_name(), "正在使用%s，等待结果。" % device_name, "%s完成：%s" % [device_name, result], "")
		actor.speak(entry)
	await _wait(duration)
	if actor:
		actor.stop_speaking()


func _target_position(action: Dictionary, fallback: Vector2) -> Vector2:
	if action.has("position") and action["position"] is Dictionary:
		var position: Dictionary = action["position"]
		return Vector2(float(position.get("x", fallback.x)), float(position.get("y", fallback.y)))
	var location_id: String = action.get("location_id", "")
	return _device_registry.get_location_position(location_id, fallback)


func _wait(duration: float) -> void:
	if duration <= 0.0:
		return
	await get_tree().create_timer(duration).timeout


func _finish() -> void:
	_playing = false
	for action in _actions:
		var actor := _actor_registry.get_actor(action.get("actor_id", ""))
		if actor:
			actor.set_timeline_controlled(false)
			actor.stop_speaking()
	print("TimelinePlayer: simulation completed: %s" % _simulation_id)


func _emit_event(event_type: String, action: Dictionary, payload: Dictionary = {}) -> void:
	var event := {
		"event_type": event_type,
		"action_id": action.get("id", ""),
		"timestamp": float(action.get("time", 0.0)),
		"payload": payload,
	}
	print("TimelinePlayer event: ", JSON.stringify(event))
	# HTTP reporting is intentionally optional for P0 local playback.
