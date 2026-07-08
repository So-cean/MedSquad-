extends Node

## Global dialogue orchestrator (autoload).

# Force-load FontRegistry before this script parses (autoload scripts load early).
const __font_registry := preload("res://scripts/dialogue/font_registry.gd")
##
## Owns: bubble pool + NPC hover card.
## Each frame: polls NPCs for dialogue entries, positions bubbles.
## Mouse hover: detects NPC under cursor, shows NpcHoverCard.

const POOL_SIZE: int = 6

var _layer: CanvasLayer
var _bubble_pool: Array[DialogueBubble] = []
var _npcs: Array[BaseNpc] = []
var _slots: Dictionary = {}
var _bubbles_ready: bool = false
var _hover_card: NpcHoverCard = null


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	# Chinese font for all UI
	var fv: FontVariation = FontRegistry.get_cn_font()
	if fv:
		var dt: Theme = ThemeDB.get_default_theme()
		dt.default_font = fv

	# Hover card
	_hover_card = NpcHoverCard.new()
	_hover_card.name = "NpcHoverCard"
	_layer.add_child(_hover_card)

	# ConversationManager
	var cm_script: GDScript = load("res://scripts/dialogue/conversation_manager.gd")
	if cm_script:
		var cm_inst: Node = cm_script.new()
		if cm_inst:
			cm_inst.name = "ConversationManager"
			add_child(cm_inst)


func register(npc: BaseNpc) -> void:
	if npc not in _npcs:
		_npcs.append(npc)


func unregister(npc: BaseNpc) -> void:
	_npcs.erase(npc)
	_release_bubble(npc)


func _process(_delta: float) -> void:
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

	# Bubble management
	for npc in _npcs:
		if not is_instance_valid(npc):
			continue
		var entry: DialogueEntry = npc.get_dialogue_entry()
		if entry and not entry.is_empty():
			_ensure_bubble(npc, entry)
		else:
			_release_bubble(npc)

	# Position bubbles — fixed offset per active bubble, no per-frame recalc
	var active_count: int = 0
	for npc in _slots:
		var bubble: DialogueBubble = _slots[npc]
		if not is_instance_valid(bubble):
			_slots.erase(npc)
			continue
		var screen_pos: Vector2 = camera.get_canvas_transform() * npc.global_position
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		var cx: float = clamp(screen_pos.x, bubble.size.x * 0.5, vp_size.x - bubble.size.x * 0.5)
		bubble.follow_screen_position(cx, screen_pos.y)
		active_count += 1

	# Mouse hover detection
	_handle_hover(camera)


func _handle_hover(camera: Camera2D) -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var world_pos: Vector2 = camera.get_canvas_transform().affine_inverse() * mouse_pos

	var hovered_npc: BaseNpc = null
	for npc in _npcs:
		if not is_instance_valid(npc):
			continue
		# Check if mouse is near NPC (within 40px radius)
		if npc.global_position.distance_to(world_pos) < 40.0:
			hovered_npc = npc
			break

	if hovered_npc:
		_hover_card.show_card(hovered_npc, mouse_pos)
	else:
		_hover_card.hide_card()


func _get_camera() -> Camera2D:
	var vp: Viewport = get_viewport()
	return vp.get_camera_2d() if vp else null


func _ensure_bubble(npc: BaseNpc, entry: DialogueEntry) -> void:
	if _slots.has(npc):
		var b: DialogueBubble = _slots[npc]
		if b._current_entry == entry:
			if b._phase == DialogueBubble.Phase.DONE or b._phase == DialogueBubble.Phase.FADING:
				_release_bubble(npc)
			return
		b.show_entry(entry)
		return

	for b in _bubble_pool:
		if not b.is_available():
			continue
		# Set offset ONCE at assignment — not recalculated every frame
		b.set_offset_y(0.0)  # no stacking offset — bubbles follow their own NPC
		b.show_entry(entry)
		_slots[npc] = b
		return


func get_conversation_manager() -> Node:
	return get_node_or_null("ConversationManager")


func get_bubble_for_npc(npc: BaseNpc) -> DialogueBubble:
	return _slots.get(npc) as DialogueBubble if _slots.has(npc) else null


func _release_bubble(npc: BaseNpc) -> void:
	if not _slots.has(npc):
		return
	var b: DialogueBubble = _slots[npc]
	_slots.erase(npc)
	b.set_offset_y(0.0)
	b.fade_out()
