extends Node

## Manages 1v1 NPC dialogue pairings with priority-based interruption.
##
## States per NPC:
##   idle            — free to start a conversation
##   in_conversation — locked to a partner; interruption may switch
##   queued          — waiting for a busy NPC
##
## Priority rules:
##   Higher priority → can interrupt and switch the NPC's focus
##   Lower priority  → NPC sends a "please wait" one-liner, requester enters queue
##
## NOTE: parameters use Variant (not BaseNpc) because autoloads compile
## before scene scripts. Methods like get_npc_name() work via dynamic dispatch.

enum NpcState { IDLE, IN_CONVERSATION, QUEUED }

# ── Per-NPC state ──
# { npc_ref: { state, partner, channel, priority, queue: [] } }
var _states: Dictionary = {}


func register(npc) -> void:
	if npc in _states:
		return
	_states[npc] = {
		state = NpcState.IDLE,
		partner = null,
		channel = "",
		priority = 0,
		queue = [],
	}


func unregister(npc) -> void:
	if npc in _states:
		if _states[npc].state == NpcState.IN_CONVERSATION:
			_end_channel(_states[npc].channel)
		_states.erase(npc)


## Returns a result dict:
##   { ok: true }                              → proceed immediately
##   { ok: false, reason: "busy" }             → speaker is busy, ask to wait
func request_speak(speaker, listener, priority: int) -> Dictionary:
	_ensure_registered(speaker)
	_ensure_registered(listener)
	var ss = _states[speaker]
	var ls = _states[listener]

	if ss.state == NpcState.IDLE:
		if ls.state == NpcState.IDLE:
			_start_conversation(speaker, listener, priority)
			return { ok = true }
		return _try_interrupt(speaker, listener, priority)

	if ss.state == NpcState.IN_CONVERSATION:
		if ss.partner == listener:
			return { ok = true }
		if priority > ss.priority:
			_hold_partner(speaker)
			_start_conversation(speaker, listener, priority)
			return { ok = true }
		else:
			_enqueue(speaker, listener, priority)
			return { ok = false, reason = "busy" }

	return { ok = false, reason = "queued" }


func end_turn(npc) -> void:
	if npc not in _states:
		return
	var s = _states[npc]
	if s.state == NpcState.IN_CONVERSATION:
		_end_channel(s.channel)


func end_conversation(npc_a, npc_b) -> void:
	for npc in [npc_a, npc_b]:
		if npc in _states:
			var s = _states[npc]
			if s.state == NpcState.IN_CONVERSATION:
				_end_channel(s.channel)
				break


func get_status(npc) -> String:
	if npc not in _states:
		return "unregistered"
	var s = _states[npc]
	match s.state:
		NpcState.IDLE:
			return "idle"
		NpcState.IN_CONVERSATION:
			var pname = "?"
			if s.partner and is_instance_valid(s.partner):
				pname = s.partner.get_npc_name()
			return "talking to %s (pri=%d)" % [pname, s.priority]
		NpcState.QUEUED:
			return "queued"
	return "unknown"


# ═══════════════════════════════════════════════════════════════════════
#  Internal
# ═══════════════════════════════════════════════════════════════════════

func _ensure_registered(npc) -> void:
	if npc not in _states:
		register(npc)


func _start_conversation(a, b, priority: int) -> void:
	var chan = "%s_%s" % [a.get_instance_id(), b.get_instance_id()]
	_states[a] = { state = NpcState.IN_CONVERSATION, partner = b, channel = chan, priority = priority, queue = [] }
	_states[b] = { state = NpcState.IN_CONVERSATION, partner = a, channel = chan, priority = priority, queue = [] }


func _end_channel(channel: String) -> void:
	for npc in _states.keys():
		if not is_instance_valid(npc):
			_states.erase(npc)
			continue
		var s = _states[npc]
		if s.channel == channel:
			if s.queue.size() > 0:
				s.queue.sort_custom(func(a, b): return a.priority > b.priority)
				var next = s.queue[0]
				s.queue = []
				_start_conversation(npc, next.requester, next.priority)
				_states[next.requester].queue = []
				return
			s.state = NpcState.IDLE
			s.partner = null
			s.channel = ""
			s.priority = 0


func _hold_partner(npc) -> void:
	var s = _states[npc]
	var old_partner = s.partner
	if old_partner and old_partner in _states:
		var ps = _states[old_partner]
		ps.state = NpcState.IDLE
		ps.partner = null
		ps.channel = ""
		ps.priority = 0


func _try_interrupt(speaker, listener, priority: int) -> Dictionary:
	var ls = _states[listener]
	if priority > ls.priority:
		var _old_partner = ls.partner
		_hold_partner(listener)
		_start_conversation(speaker, listener, priority)
		return { ok = true }
	else:
		_enqueue(speaker, listener, priority)
		return { ok = false, reason = "busy", notify_self = true }


func _enqueue(requester, target, priority: int) -> void:
	if target not in _states:
		return
	_states[target].queue.append({
		requester = requester,
		priority = priority,
	})
