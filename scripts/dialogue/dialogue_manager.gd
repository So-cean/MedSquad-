extends Node

## Global dialogue orchestrator.  Add as an autoload in project.godot.
##
## Owns a pooled set of DialogueBubble instances in a high-layer CanvasLayer.
## Each frame it polls all registered BaseNpcs; those with non-empty
## DialogueEntry get a bubble assigned and positioned above their head.

const POOL_SIZE := 6

var _layer: CanvasLayer
var _bubble_pool: Array[DialogueBubble] = []
var _npcs: Array[BaseNpc] = []

# NPC → assigned bubble
var _slots: Dictionary = {}


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	for i in POOL_SIZE:
		var b := DialogueBubble.new()
		b.name = "DialogueBubble_%d" % i
		b.visible = false
		_bubble_pool.append(b)

	# Spawn ConversationManager as child
	var cm_script = load("res://scripts/dialogue/conversation_manager.gd")
	if cm_script:
		var cm_inst = cm_script.new()
		if cm_inst:
			cm_inst.name = "ConversationManager"
			add_child(cm_inst)

	# TimelinePlayer (receives actions from backend LLM)
	var tp_script = load("res://scripts/edmas/managers/timeline_player.gd")
	if tp_script:
		var tp = tp_script.new()
		tp.name = "TimelinePlayer"
		add_child(tp)
		var bb = get_node_or_null("/root/BackendBridge")
		if bb and bb.has_method("get_sim_client"):
			tp.setup(bb.get_sim_client())

	# Chinese font fallback is handled per-bubble in DialogueBubble._ready()


# ═══════════════════════════════════════════════════════════════════════
#  NPC registration
# ═══════════════════════════════════════════════════════════════════════

func register(npc: BaseNpc) -> void:
	if npc not in _npcs:
		_npcs.append(npc)


func unregister(npc: BaseNpc) -> void:
	_npcs.erase(npc)
	_release_bubble(npc)


# ═══════════════════════════════════════════════════════════════════════
#  Frame update
# ═══════════════════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	var camera := _get_camera()
	if not camera:
		# No camera yet — bubbles can't be positioned
		return

	# Assign / release bubbles based on NPC dialogue state
	for npc in _npcs:
		var entry := npc.get_dialogue_entry()
		if entry and not entry.is_empty():
			_ensure_bubble(npc, entry)
		else:
			_release_bubble(npc)

	# Position active bubbles above their NPC
	var viewport_size := get_viewport().get_visible_rect().size
	for npc in _slots:
		var bubble: DialogueBubble = _slots[npc]
		var screen_pos: Vector2 = camera.get_canvas_transform() * npc.global_position

		# Clamp so bubble stays inside the viewport horizontally
		var cx: float = clamp(screen_pos.x, bubble.size.x * 0.5, viewport_size.x - bubble.size.x * 0.5)
		bubble.follow_screen_position(cx, screen_pos.y)


func _get_camera() -> Camera2D:
	var vp := get_viewport()
	return vp.get_camera_2d() if vp else null


func _ensure_bubble(npc: BaseNpc, entry: DialogueEntry) -> void:
	if _slots.has(npc):
		# Already assigned — keep showing current entry
		return

	# Find a free bubble from the pool (skip fading ones)
	for b in _bubble_pool:
		if not b.is_available():
			continue
		b.show_entry(entry)
		_slots[npc] = b
		return


## Returns the ConversationManager child node.
func get_conversation_manager():
	return get_node_or_null("ConversationManager")

func _release_bubble(npc: BaseNpc) -> void:
	if not _slots.has(npc):
		return
	var b: DialogueBubble = _slots[npc]
	_slots.erase(npc)
	b.fade_out()
