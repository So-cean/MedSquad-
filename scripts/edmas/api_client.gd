extends Node

const Config = preload("res://scripts/edmas/config.gd")

signal demo_list_received(data)
signal demo_loaded(data)
signal demo_reset(data)
signal snapshot_received(data)
signal step_completed(data)
signal events_received(data)
signal model_calls_received(data)
signal user_turn_received(data)
signal api_error(endpoint, message)

@onready var http: HTTPRequest = HTTPRequest.new()
var _request_queue: Array = []
var _active_request: Dictionary = {}
var _request_serial: int = 0

func _ready() -> void:
	add_child(http)
	http.request_completed.connect(_on_request_completed)

func _make_url(endpoint: String) -> String:
	return "%s%s" % [Config.API_BASE_URL, endpoint]

func _request(method: int, endpoint: String, body: String = "") -> void:
	_request_serial += 1
	var request: Dictionary = {
		"id": _request_serial,
		"method": method,
		"endpoint": endpoint,
		"body": body,
	}
	if not _active_request.is_empty():
		_request_queue.append(request)
		print("[EDMAS][HTTP] queued #%d %s" % [int(request["id"]), endpoint])
		return
	_start_request(request)

func _start_request(request: Dictionary) -> void:
	_active_request = request.duplicate(true)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var endpoint: String = str(request.get("endpoint", ""))
	var method: int = int(request.get("method", HTTPClient.METHOD_GET))
	var body: String = str(request.get("body", ""))
	print("[EDMAS][HTTP] start #%d %s" % [int(request.get("id", -1)), endpoint])
	var err: int = http.request(_make_url(endpoint), headers, method, body)
	if err != OK:
		emit_signal("api_error", endpoint, "request_failed:%s" % err)
		_active_request = {}
		_process_next_request()

func _process_next_request() -> void:
	if not _active_request.is_empty():
		return
	if _request_queue.is_empty():
		return
	var next_request: Dictionary = _request_queue.pop_front()
	_start_request(next_request)

func _parse_payload(endpoint: String, result: int, response_code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("api_error", endpoint, "transport_error:%s" % result)
		return {}
	if response_code < 200 or response_code >= 300:
		emit_signal("api_error", endpoint, "http_%s" % response_code)
		return {}
	var text: String = body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		emit_signal("api_error", endpoint, "json_parse_failed")
		return {}
	return parsed as Dictionary

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var endpoint: String = str(_active_request.get("endpoint", ""))
	var request_id: int = int(_active_request.get("id", -1))
	print("[EDMAS][HTTP] completed #%d %s code=%d result=%d" % [request_id, endpoint, response_code, result])
	_active_request = {}
	var payload: Dictionary = _parse_payload(endpoint, result, response_code, body)
	if payload.is_empty():
		_process_next_request()
		return
	match endpoint:
		"/api/godot/demo/list":
			emit_signal("demo_list_received", payload)
		"/api/godot/demo/load":
			emit_signal("demo_loaded", payload)
		"/api/godot/demo/reset":
			emit_signal("demo_reset", payload)
		"/api/godot/snapshot":
			emit_signal("snapshot_received", payload)
		"/api/godot/step":
			emit_signal("step_completed", payload)
		"/api/godot/events/recent":
			emit_signal("events_received", payload)
		"/api/godot/model_calls/recent":
			emit_signal("model_calls_received", payload)
		"/api/godot/user_turn":
			emit_signal("user_turn_received", payload)
		_:
			emit_signal("api_error", endpoint, "unknown_endpoint")
	_process_next_request()

func get_demo_list() -> void:
	_request(HTTPClient.METHOD_GET, "/api/godot/demo/list")

func load_demo(demo_id: String) -> void:
	_request(HTTPClient.METHOD_POST, "/api/godot/demo/load", JSON.stringify({"demo_id": demo_id}))

func reset_demo(demo_id: String = "") -> void:
	var payload: Dictionary = {}
	if demo_id != "":
		payload["demo_id"] = demo_id
	_request(HTTPClient.METHOD_POST, "/api/godot/demo/reset", JSON.stringify(payload))

func get_snapshot() -> void:
	_request(HTTPClient.METHOD_GET, "/api/godot/snapshot")

func post_step(steps: int = 1) -> void:
	_request(HTTPClient.METHOD_POST, "/api/godot/step", JSON.stringify({"steps": steps}))

func get_events() -> void:
	_request(HTTPClient.METHOD_GET, "/api/godot/events/recent")

func get_model_calls() -> void:
	_request(HTTPClient.METHOD_GET, "/api/godot/model_calls/recent")

func post_user_turn(patient_id: String, text: String) -> void:
	_request(HTTPClient.METHOD_POST, "/api/godot/user_turn", JSON.stringify({"patient_id": patient_id, "text": text, "mode": "user"}))
