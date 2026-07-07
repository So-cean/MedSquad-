extends Node

## Autoload — manages Python backend lifecycle.
## In Web export: skips process spawning, only tries remote connection.

signal backend_ready
signal backend_error(msg: String)

const PORT := 8651
const LOCAL_URL := "http://127.0.0.1:8651"
const POLL_INTERVAL := 0.5
const MAX_POLLS := 12

var _http: HTTPRequest = null
var _server_pid: int = -1
var is_ready := false
var sim_client = null
var _is_web := false


func _ready() -> void:
	_is_web = OS.has_feature("web") or DisplayServer.get_name() == "headless"
	if _is_web:
		# Web/headless: can't spawn processes, just try remote
		print("[BackendBridge] Web/headless mode — skipping local server launch")
		_try_remote()
	else:
		# Desktop: kill old, start new
		_kill_existing()
		_start_backend()


func _exit_tree() -> void:
	_kill_server()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_kill_server()


func get_sim_client() -> Node:
	if not sim_client:
		var s = load("res://scripts/edmas/sim_client.gd")
		if s:
			sim_client = s.new()
			sim_client.name = "SimClient"
			add_child(sim_client)
	return sim_client


func get_url() -> String:
	return LOCAL_URL


# ── Web mode: just ping remote ──

func _try_remote() -> void:
	for i in MAX_POLLS:
		await get_tree().create_timer(POLL_INTERVAL).timeout
		if await _ping():
			is_ready = true
			print("[BackendBridge] Remote backend reachable")
			backend_ready.emit()
			return
	print("[BackendBridge] No backend reachable — offline mode")
	backend_error.emit("offline")


# ── Desktop mode: process management ──

func _kill_existing() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 2
	var err := http.request(LOCAL_URL + "/api/shutdown", [], HTTPClient.METHOD_POST, "{}")
	if err == OK:
		await http.request_completed
		print("[BackendBridge] Previous server shut down")
	http.queue_free()


func _start_backend() -> void:
	var python := _find_python()
	if python.is_empty():
		backend_error.emit("Python not found")
		return

	var args := ["-m", "app.services.backend_server"]
	_server_pid = OS.create_process(python, args, false)
	if _server_pid < 0:
		backend_error.emit("Failed to start backend process")
		return

	print("[BackendBridge] Started backend (PID:", _server_pid, ")")

	for i in MAX_POLLS:
		await get_tree().create_timer(POLL_INTERVAL).timeout
		if await _ping():
			is_ready = true
			print("[BackendBridge] Backend ready")
			backend_ready.emit()
			return

	backend_error.emit("Backend did not start")
	_kill_server()


func _kill_server() -> void:
	if _server_pid <= 0:
		return
	if OS.get_name() == "Windows":
		OS.execute("taskkill", ["/F", "/PID", str(_server_pid)], [], false)
	else:
		OS.kill(_server_pid)
	print("[BackendBridge] Stopped backend (PID:", _server_pid, ")")
	_server_pid = -1


# ── Shared ──

func _ping() -> bool:
	if _http:
		_http.queue_free()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.timeout = 2
	var ok := false
	_http.request_completed.connect(func(_r, code, _h, _b): ok = (code == 200))
	_http.request(LOCAL_URL + "/api/sim/status")
	await _http.request_completed
	return ok


func _find_python() -> String:
	for c in ["python", "python3", "py"]:
		if OS.execute(c, ["--version"], []) == 0:
			return c
	return ""
