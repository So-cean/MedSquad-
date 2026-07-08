extends Node

## NPC Finite State Machine — stateless LLM caller.
## Owns nothing except in-flight HTTP requests.
## One method: request(npc_id, prompt) → signal action_ready.

signal action_ready(npc_id: String, action: Dictionary)

const GITEE_BASE: String = "https://ai.gitee.com/api/v1/chat/completions"
const GITEE_KEYS: Array[String] = [
	"HOHGSAMMVSBLXBHT2DMVMXQOEBP0VZSRJBXFW7S2",
	"WCWPXT8ENFDYTCZ0F8OBZRFBMVMU9CDJVFVU4R1T",
]
const MODEL: String = "DeepSeek-V4-Flash"

var _in_flight: Dictionary = {}  # npc_id → HTTPRequest (in-flight only)
var _key_idx: int = 0
var _last_request_time: float = 0.0
const MIN_REQUEST_INTERVAL: float = 0.5  # throttle between requests


## Fire an LLM request for an NPC. Emits action_ready on completion.
## Throttled to avoid hammering the API.
func request(npc_id: String, prompt: String) -> void:
	# Throttle: wait if too soon after last request
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_request_time < MIN_REQUEST_INTERVAL:
		await get_tree().create_timer(MIN_REQUEST_INTERVAL - (now - _last_request_time)).timeout
	_last_request_time = Time.get_ticks_msec() / 1000.0

	var key: String = GITEE_KEYS[_key_idx % GITEE_KEYS.size()]
	_key_idx = (_key_idx + 1) % GITEE_KEYS.size()

	var body: String = JSON.stringify({
		model = MODEL,
		messages = [{"role": "user", "content": prompt}],
		temperature = 0.3,
		max_tokens = 512,
	})

	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 30
	http.request_completed.connect(_on_done.bind(npc_id))
	add_child(http)
	http.request(GITEE_BASE, ["Content-Type: application/json",
		"Authorization: Bearer " + key], HTTPClient.METHOD_POST, body)

	# Track for cleanup
	var old: HTTPRequest = _in_flight.get(npc_id)
	if old:
		old.queue_free()
	_in_flight[npc_id] = http

	# Timestamp for debug
	http.set_meta("t0", Time.get_ticks_msec() / 1000.0)


func _on_done(_result: int, code: int, _headers: Array, body: PackedByteArray,
		npc_id: String) -> void:
	# Cleanup
	var http: HTTPRequest = _in_flight.get(npc_id)
	if http:
		_in_flight.erase(npc_id)
		http.queue_free()

	var t0: float = http.get_meta("t0", 0.0) if http else 0.0
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - t0 if t0 > 0 else -1.0
	print("[LLM]  [%s] code=%d elapsed=%.1fs" % [npc_id, code, elapsed])

	if code != 200 or body.is_empty():
		action_ready.emit(npc_id, {"type": "speak", "utterances": ["嗯..."], "think": "等待回复"})
		return

	var text: String = body.get_string_from_utf8()
	if text.is_empty():
		action_ready.emit(npc_id, {"type": "speak", "utterances": ["请稍等..."], "think": "获取信息"})
		return

	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		action_ready.emit(npc_id, {"type": "speak", "utterances": ["嗯..."], "think": "请求失败"})
		return

	var choices: Array = parsed.get("choices", [])
	if choices.is_empty():
		action_ready.emit(npc_id, {"type": "speak", "utterances": ["好的"], "think": "处理中"})
		return

	var content: String = ""
	var choice: Variant = choices[0]
	if choice is Dictionary:
		var msg: Variant = choice.get("message", {})
		if msg is Dictionary:
			content = msg.get("content", "")

	action_ready.emit(npc_id, _parse_action(content, npc_id))


# Strip markdown fences, parse JSON, fallback to smart text extraction.
func _parse_action(text: String, npc_id: String) -> Dictionary:
	text = text.strip_edges()
	# Strip markdown code fences
	if "```" in text:
		var parts: PackedStringArray = text.split("```")
		if parts.size() >= 2:
			text = parts[1]
			if text.begins_with("json"):
				text = text.substr(4)
			text = text.strip_edges()

	# Try JSON first
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var result: Dictionary = parsed as Dictionary
		if result.has("dialogue") and not result.has("utterances"):
			result["utterances"] = [result["dialogue"]]
		# Filter empty utterances in both top-level and responses[].utterances
		result["utterances"] = _filter_utterances(result.get("utterances", []))
		var responses: Array = result.get("responses", [])
		var cleaned_responses: Array = []
		for resp in responses:
			if resp is Dictionary:
				var resp_d: Dictionary = resp as Dictionary
				resp_d["utterances"] = _filter_utterances(resp_d.get("utterances", []))
				cleaned_responses.append(resp_d)
		result["responses"] = cleaned_responses
		if not result.has("type"):
			result["type"] = "speak"
		# If all utterances empty, provide fallback so bubble shows "..." not blank
		if result.get("utterances", []).is_empty() and cleaned_responses.is_empty():
			result["utterances"] = ["..."]
		return result

	# JSON failed — try to extract think + utterances from plain text
	return _extract_from_plain_text(text, npc_id)


## Filter out empty / whitespace-only utterance strings. Returns cleaned array.
func _filter_utterances(raw: Array) -> Array:
	var out: Array = []
	for utt in raw:
		var s: String = str(utt).strip_edges()
		if not s.is_empty():
			out.append(s)
	return out


## When LLM returns plain text instead of JSON, try to split into think + utterances.
## Common patterns:
##   "think: xxx\n utterances: yyy"
##   "thinkxxx\n\nyyy"
##   "思考：xxx\nyyy"
func _extract_from_plain_text(text: String, npc_id: String) -> Dictionary:
	var think: String = ""
	var utterances: Array = []

	# Pattern 1: "think:" or "思考：" prefix
	var lower_text: String = text.to_lower()
	if lower_text.begins_with("think") or text.begins_with("思考") or text.begins_with("想"):
		# Find the split point — look for newline after the think part
		var split_idx: int = text.find("\n")
		if split_idx > 0:
			var first_line: String = text.substr(0, split_idx).strip_edges()
			var rest: String = text.substr(split_idx + 1).strip_edges()
			# Remove "think:" / "思考：" prefix from first line
			if first_line.to_lower().begins_with("think:"):
				think = first_line.substr(6).strip_edges()
			elif first_line.to_lower().begins_with("think"):
				think = first_line.substr(5).strip_edges()
			elif first_line.begins_with("思考："):
				think = first_line.substr(3).strip_edges()
			elif first_line.begins_with("思考:"):
				think = first_line.substr(3).strip_edges()
			else:
				think = first_line
			# Rest is the utterance
			if not rest.is_empty():
				# Split by newline into multiple utterances
				var lines: PackedStringArray = rest.split("\n")
				for line in lines:
					var clean: String = line.strip_edges().trim_prefix('"').trim_suffix('"').trim_prefix('"').trim_suffix('"')
					if not clean.is_empty():
						utterances.append(clean)
		else:
			# No newline — entire text is think or utterance
			utterances.append(text)
	else:
		# No think prefix — entire text is utterance
		utterances.append(text)

	if utterances.is_empty():
		utterances.append("...")

	return {
		"type": "speak",
		"think": think,
		"utterances": utterances,
		"npc_id": npc_id,
	}
