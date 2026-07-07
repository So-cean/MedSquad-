extends Node

## HTTP client for the realtime NPC backend server.
## Sends/receives JSON to the Python FSM engine.

signal actions_received(actions: Array)
signal connection_error(msg: String)

const BASE_URL := "http://127.0.0.1:8651"

var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_completed)
	_http.timeout = 10


## Initialize simulation with NPCs and patient data.
func init_simulation(npc_list: Array, patient: Dictionary) -> void:
	var body := {
		npcs = npc_list,
		current_patient = patient,
	}
	_post("/api/sim/init", body)


## Request next actions from all NPCs.
func request_tick() -> void:
	_post("/api/sim/tick", {})


## Report that an action is complete.
func report_complete(npc_id: String) -> void:
	_post("/api/sim/complete", {npc_id = npc_id})


func _post(endpoint: String, body: Dictionary) -> void:
	var json_str := JSON.stringify(body)
	var headers := ["Content-Type: application/json"]
	var err := _http.request(BASE_URL + endpoint, headers, HTTPClient.METHOD_POST, json_str)
	if err != OK:
		connection_error.emit("HTTP request failed: " + str(err))


func _on_completed(_result: int, code: int, _headers: Array, body: PackedByteArray) -> void:
	if code != 200:
		connection_error.emit("HTTP " + str(code))
		return

	var text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		if parsed.has("actions"):
			actions_received.emit(parsed["actions"] as Array)
		# Store for polling
		_last_response = parsed as Dictionary

var _last_response: Dictionary = {}

func get_last_response() -> Dictionary:
	return _last_response
