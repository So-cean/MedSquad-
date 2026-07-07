extends Node

## Global dialogue orchestrator.  Add as an autoload in project.godot.
##
## Owns a pooled set of DialogueBubble instances in a high-layer CanvasLayer.
## Each frame it polls all registered BaseNpcs; those with non-empty
## DialogueEntry get a bubble assigned and positioned above their head.

const POOL_SIZE: int = 6

var _layer: CanvasLayer
var _bubble_pool: Array[DialogueBubble] = []
var _npcs: Array[BaseNpc] = []

# NPC → assigned bubble
var _slots: Dictionary = {}

var _bubbles_ready: bool = false

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	# Spawn ConversationManager as child
	var cm_script: GDScript = load("res://scripts/dialogue/conversation_manager.gd")
	if cm_script:
		var cm_inst: Node = cm_script.new()
		if cm_inst:
			cm_inst.name = "ConversationManager"
			add_child(cm_inst)


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
	# Initialize bubble pool on first frame (after all _ready() calls have run)
	if not _bubbles_ready:
		_bubbles_ready = true
		for i in POOL_SIZE:
			var b: DialogueBubble = DialogueBubble.new()
			b.name = "DialogueBubble_%d" % i
			b.visible = false
			_layer.add_child(b)
			_bubble_pool.append(b)
		return

	var camera: Camera2D = _get_camera()
	if not camera:
		return

	# Assign / release bubbles based on NPC dialogue state
	for npc in _npcs:
		var entry: DialogueEntry = npc.get_dialogue_entry()
		if entry and not entry.is_empty():
			_ensure_bubble(npc, entry)
		else:
			_release_bubble(npc)

	# Position active bubbles above their NPC
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	for npc in _slots:
		var bubble: DialogueBubble = _slots[npc]
		var screen_pos: Vector2 = camera.get_canvas_transform() * npc.global_position

		# Clamp so bubble stays inside the viewport horizontally
		var cx: float = clamp(screen_pos.x, bubble.size.x * 0.5, viewport_size.x - bubble.size.x * 0.5)
		bubble.follow_screen_position(cx, screen_pos.y)


func _get_camera() -> Camera2D:
	var vp: Viewport = get_viewport()
	return vp.get_camera_2d() if vp else null


func _ensure_bubble(npc: BaseNpc, entry: DialogueEntry) -> void:
	if _slots.has(npc):
		var b: DialogueBubble = _slots[npc]
		if b._current_entry == entry:
			return  # Same entry still playing — no update needed
		b.show_entry(entry)  # New entry — refresh bubble
		return

	# Find a free bubble from the pool (skip fading ones)
	for b in _bubble_pool:
		if not b.is_available():
			continue
		b.show_entry(entry)
		_slots[npc] = b
		return


## Returns the ConversationManager child node.
func get_conversation_manager() -> Node:
	return get_node_or_null("ConversationManager")


## Returns the bubble assigned to an NPC, or null.
func get_bubble_for_npc(npc: BaseNpc) -> DialogueBubble:
	return _slots.get(npc) as DialogueBubble if _slots.has(npc) else null


func _release_bubble(npc: BaseNpc) -> void:
	if not _slots.has(npc):
		return
	var b: DialogueBubble = _slots[npc]
	_slots.erase(npc)
	b.fade_out()
