extends Node

## Autoload — manages the Python backend server lifecycle.

signal backend_ready
signal backend_error(msg: String)

const PORT := 8651
const URL := "http://127.0.0.1:8651"
const POLL_INTERVAL := 0.5
const MAX_POLLS := 12

var _backend_dir := ""
var _http: HTTPRequest = null
var _server_pid: int = -1
var is_ready := false
var sim_client = null


func _ready() -> void:
	_backend_dir = ProjectSettings.globalize_path("res://backend/")
	_kill_existing()
	_start_backend()


func _exit_tree() -> void:
	_kill_server()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_kill_server()


func get_sim_client() -> Node:
	if not sim_client:
		var script = load("res://scripts/edmas/sim_client.gd")
		if script:
			sim_client = script.new()
			sim_client.name = "SimClient"
			add_child(sim_client)
	return sim_client


func _kill_existing() -> void:
	# Try graceful shutdown first
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 2
	var err := http.request(URL + "/api/shutdown", [], HTTPClient.METHOD_POST, "{}")
	if err == OK:
		await http.request_completed
		print("[BackendBridge] Previous server shut down")
	http.queue_free()


func _start_backend() -> void:
	var python := _find_python()
	if python.is_empty():
		backend_error.emit("Python not found in PATH")
		return

	var args := ["-m", "app.services.backend_server"]

	# Use OS.create_process to get PID for clean shutdown
	_server_pid = OS.create_process(python, args, false)
	if _server_pid < 0:
		backend_error.emit("Failed to start backend process")
		return

	print("[BackendBridge] Started backend (PID:", _server_pid, ")")

	# Poll until ready
	for i in MAX_POLLS:
		await get_tree().create_timer(POLL_INTERVAL).timeout
		var ok := await _ping()
		if ok:
			is_ready = true
			print("[BackendBridge] Backend ready on port ", PORT)
			backend_ready.emit()
			return

	backend_error.emit("Backend did not start within " + str(MAX_POLLS * POLL_INTERVAL) + "s")


func _kill_server() -> void:
	if _server_pid <= 0:
		return
	# Try taskkill on Windows, kill on Unix
	if OS.get_name() == "Windows":
		OS.execute("taskkill", ["/F", "/PID", str(_server_pid)], [], false)
	else:
		OS.kill(_server_pid)
	print("[BackendBridge] Stopped backend (PID:", _server_pid, ")")
	_server_pid = -1


func _ping() -> bool:
	if _http:
		_http.queue_free()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.timeout = 2

	var ok := false
	_http.request_completed.connect(func(_r, code, _h, _b): ok = (code == 200))
	_http.request(URL + "/api/sim/status")
	await _http.request_completed
	return ok


func _find_python() -> String:
	for candidate in ["python", "python3", "py"]:
		var exit_code := OS.execute(candidate, ["--version"], [])
		if exit_code == 0:
			return candidate
	return ""
