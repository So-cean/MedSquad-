extends RefCounted
class_name InteractionSession

enum SessionPhase { CREATED, ACTIVE, WAITING_RESPONSE, PLAYER_INTERVENTION, COMPLETED, FAILED }

var session_id: String = ""
var participants: Dictionary = {}
var active_speaker: String = ""
var current_phase: SessionPhase = SessionPhase.CREATED
var local_result: String = ""
var player_can_intervene: bool = false
var player_intervention_role: String = ""
var transcript: Array = []

func start(p_session_id: String, p_participants: Dictionary) -> void:
	session_id = p_session_id
	participants = p_participants.duplicate(true)
	current_phase = SessionPhase.ACTIVE
	active_speaker = "nurse"
	player_can_intervene = false
	player_intervention_role = ""
	local_result = ""
	transcript = []

func set_player_intervention(role: String) -> void:
	player_can_intervene = true
	player_intervention_role = role
	current_phase = SessionPhase.PLAYER_INTERVENTION

func complete(result_text: String) -> void:
	local_result = result_text
	current_phase = SessionPhase.COMPLETED
	active_speaker = ""
	player_can_intervene = false

func fail(reason: String) -> void:
	local_result = reason
	current_phase = SessionPhase.FAILED
	active_speaker = ""
	player_can_intervene = false

func add_line(speaker: String, text: String) -> void:
	transcript.append({
		"speaker": speaker,
		"text": text,
	})

func is_completed() -> bool:
	return current_phase == SessionPhase.COMPLETED

func is_failed() -> bool:
	return current_phase == SessionPhase.FAILED

