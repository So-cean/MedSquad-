extends Node

## NPC Finite State Machine — drives LLM-powered dialogue and actions.
## Replaces the Python backend. Godot calls Gitee AI directly via HTTPRequest.
## Multiple NPCs can decide concurrently (each has its own HTTPRequest).

signal action_ready(npc_id: String, action: Dictionary)

enum State { IDLE, DECIDING, MOVING, SPEAKING, WAITING }

const GITEE_BASE := "https://ai.gitee.com/api/v1/chat/completions"
const GITEE_KEYS := [
	"HOHGSAMMVSBLXBHT2DMVMXQOEBP0VZSRJBXFW7S2",
	"WCWPXT8ENFDYTCZ0F8OBZRFBMVMU9CDJVFVU4R1T",
]
const MODEL_FAST := "DeepSeek-V4-Flash"
const MODEL_MEDICAL := "HealthGPT-L14"

var _npcs: Dictionary = {}  # npc_id → NPC data
var _key_idx := 0


# ═══════════════════════════════════════════════════════════════════════
#  Public API
# ═══════════════════════════════════════════════════════════════════════

## Register an NPC with the FSM engine.
func register_npc(npc_id: String, display_name: String, role: String,
		knowledge: Array, priority: int = 1) -> void:
	_npcs[npc_id] = {
		id = npc_id,
		display_name = display_name,
		role = role,
		knowledge = knowledge,
		priority = priority,
		state = State.IDLE,
		position = Vector2(600, 480),
		memory = [],
		_http = null,
		_pending_prompt = "",
	}


## Tick all idle NPCs — each sends a concurrent LLM request.
## Emits action_ready for each response.
func tick_all() -> void:
	for nid in _npcs:
		var n = _npcs[nid]
		if n.state != State.IDLE:
			continue
		n.state = State.DECIDING
		var prompt := _build_routing_prompt(n)
		_send_llm(nid, MODEL_FAST, prompt)


## Player talks to an NPC. Sends LLM request with conversation context.
func player_talk(npc_id: String, player_text: String) -> void:
	var n = _npcs.get(npc_id)
	if not n:
		return
	n.memory.append({"role": "player", "dialogue": player_text})
	var prompt := _build_dialogue_prompt(n, player_text)
	_send_llm(npc_id, MODEL_FAST, prompt)


## Mark NPC action as complete, return to IDLE.
func report_complete(npc_id: String) -> void:
	var n = _npcs.get(npc_id)
	if n:
		n.state = State.IDLE


## Get NPC state summary.
func get_status() -> Dictionary:
	var states := {}
	for nid in _npcs:
		states[nid] = State.keys()[_npcs[nid].state]
	return states


# ═══════════════════════════════════════════════════════════════════════
#  Internal — LLM calls
# ═══════════════════════════════════════════════════════════════════════

func _send_llm(npc_id: String, model: String, prompt: String) -> void:
	var key := GITEE_KEYS[_key_idx % GITEE_KEYS.size()]
	_key_idx = (_key_idx + 1) % GITEE_KEYS.size()

	var body := JSON.stringify({
		model = model,
		messages = [{"role": "user", "content": prompt}],
		temperature = 0.3,
		max_tokens = 512,
	})

	var http := HTTPRequest.new()
	http.name = "LLM_" + npc_id
	add_child(http)
	http.timeout = 30
	http.request_completed.connect(_on_llm_done.bind(npc_id))
	http.request(GITEE_BASE, ["Content-Type: application/json",
		"Authorization: Bearer " + key], HTTPClient.METHOD_POST, body)


func _on_llm_done(_result: int, code: int, _headers: Array, body: PackedByteArray,
		npc_id: String) -> void:
	var n = _npcs.get(npc_id)
	if not n:
		return

	if code != 200:
		n.state = State.IDLE
		return

	var text := body.get_string_from_utf8()
	var parsed := JSON.parse_string(text)
	if not parsed is Dictionary:
		n.state = State.IDLE
		return

	var choices = parsed.get("choices", [])
	if choices.is_empty():
		n.state = State.IDLE
		return

	var content = choices[0].message.get("content", "")
	var action := _parse_action(content, npc_id)
	action["think"] = content

	# Record to memory
	if action.get("type") == "speak":
		n.memory.append({"role": n.display_name, "dialogue": action.get("utterances", [])})

	n.state = State.IDLE
	action_ready.emit(npc_id, action)


# ═══════════════════════════════════════════════════════════════════════
#  Prompt builders
# ═══════════════════════════════════════════════════════════════════════

func _build_routing_prompt(n: Dictionary) -> String:
	return ("你是一名医院" + n.display_name + "。当前场景：\n"
		+ "- 你的位置：" + str(n.position) + "\n"
		+ "- 你的专业技能：" + str(n.knowledge) + "\n\n"
		+ "请输出你的下一步行动，仅JSON格式：\n"
		+ '{"type": "speak|move_to|wait", "utterances": ["短句1","短句2"],'
		+ ' "target": "目标NPC ID", "duration": 数字}\n'
		+ "注意：每条不超过15个字，一条只问一个问题。")


func _build_dialogue_prompt(n: Dictionary, player_input: String) -> String:
	var history := n.memory.slice(-6)
	return ("你是一名医院" + n.display_name + "，正在与患者对话。\n\n"
		+ "对话历史：" + JSON.stringify(history, "", false) + "\n\n"
		+ "患者刚才说：" + player_input + "\n\n"
		+ "请输出JSON：\n"
		+ '{"think": "推理过程", "utterances": ["一句话回复不超过15字"]}\n'
		+ "注意：每条不超过15字，一条只说一件事。")


func _parse_action(text: String, npc_id: String) -> Dictionary:
	text = text.strip_edges()
	# Strip markdown code fences
	if "```" in text:
		text = text.split("```")[1]
		if text.begins_with("json"):
			text = text.substr(4)
		text = text.strip_edges()
	var parsed := JSON.parse_string(text)
	if parsed is Dictionary:
		var result := parsed as Dictionary
		# Convert single dialogue to utterances
		if result.has("dialogue") and not result.has("utterances"):
			result["utterances"] = [result["dialogue"]]
		return result
	return {"type": "speak", "utterances": [text], "npc_id": npc_id}
