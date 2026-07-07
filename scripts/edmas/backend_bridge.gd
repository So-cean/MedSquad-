extends Node

## Autoload — manages the Python backend server lifecycle.
## Spawns the backend when Godot starts, kills it on exit.

signal backend_ready
signal backend_error(msg: String)

const PORT := 8651
const URL := "http://127.0.0.1:8651"
const TIMEOUT := 8.0

var _backend_dir := ""
var _http: HTTPRequest = null
var _proc_ref: Dictionary = {}  # {pid: int, process: int}
var is_ready := false
var sim_client: Node = null


func _ready() -> void:
	_backend_dir = ProjectSettings.globalize_path("res://backend/")
	_start_backend()


func _exit_tree() -> void:
	_stop_backend()


func get_sim_client() -> Node:
	if not sim_client:
		var script = load("res://scripts/edmas/sim_client.gd")
		if script:
			sim_client = script.new()
			sim_client.name = "SimClient"
			add_child(sim_client)
	return sim_client


func _start_backend() -> void:
	# Find Python
	var python := _find_python()
	if python.is_empty():
		backend_error.emit("Python not found")
		return

	# Launch backend in background (Windows: use cmd /c start)
	var args := [python, "-m", "app.services.backend_server"]
	var cmd := ""
	if OS.get_name() == "Windows":
		# Use PowerShell Start-Process for detached process
		cmd = "powershell"
		args = ["-Command", "Start-Process", "python", "-ArgumentList",
				"'-m', 'app.services.backend_server'",
				"-WorkingDirectory", _backend_dir,
				"-WindowStyle", "Hidden"]
	else:
		cmd = python
		args = ["-m", "app.services.backend_server"]

	var output := []
	var exit_code := OS.execute(cmd, args, output, false)
	print("[BackendBridge] Starting backend...")
	print("[BackendBridge] Waiting for server on port ", PORT, "...")

	# Poll until server is ready
	await get_tree().create_timer(1.5).timeout
	_poll_ready()


func _poll_ready() -> void:
	if _http:
		_http.queue_free()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.timeout = 3
	_http.request_completed.connect(_on_poll_response)
	_http.request(URL + "/api/sim/status")


func _on_poll_response(_result: int, code: int, _headers: Array, _body: PackedByteArray) -> void:
	if code == 200:
		is_ready = true
		print("[BackendBridge] Backend ready on port ", PORT)
		backend_ready.emit()
	else:
		# Retry
		await get_tree().create_timer(0.5).timeout
		_poll_ready()


func _stop_backend() -> void:
	# Stop the Python server by requesting shutdown
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 2
	http.request(URL + "/api/sim/status", [], HTTPClient.METHOD_GET)
	await get_tree().create_timer(0.3).timeout
	http.queue_free()


func _find_python() -> String:
	for candidate in ["python", "python3", "py"]:
		var exit_code := OS.execute(candidate, ["--version"], [])
		if exit_code == 0:
			return candidate
	return ""
