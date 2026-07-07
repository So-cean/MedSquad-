extends Node2D

## Quick test: drives NPC dialogue with utterances to verify bubble display.

func _ready() -> void:
	# Let NPCs register first, then trigger dialogue
	await get_tree().create_timer(1.5).timeout
	_start_test()


func _start_test() -> void:
	var nurse = _find_npc("分诊护士")
	var patient = _find_npc("患者")
	if not nurse or not patient:
		print("[DialogueTest] NPCs not found")
		return

	print("[DialogueTest] Starting test...")

	# Nurse speaks with multiple utterances
	var entry1 := DialogueEntry.new(
		"分诊护士",
		"患者主诉头痛2天，需要逐步收集信息。首先询问部位，再问持续时间，最后问伴随症状。",
		"", "",  # dialogue is empty when using utterances
		["您好，我是分诊护士。", "您说头痛2天了？", "具体是哪个部位痛？", "有没有发烧？"]
	)
	nurse.speak(entry1)
	print("[DialogueTest] Nurse utterances: ", entry1.utterances)

	await get_tree().create_timer(holdup(entry1)).timeout

	# Patient responds
	var entry2 := DialogueEntry.new(
		"患者",
		"护士在问我头痛的情况，我需要回答清楚。",
		"",
		"",
		["前额痛，发烧38度。"]
	)
	patient.speak(entry2)
	print("[DialogueTest] Patient responded")

	await get_tree().create_timer(holdup(entry2)).timeout

	# Nurse continues
	var entry3 := DialogueEntry.new(
		"分诊护士",
		"患者有发烧，需要优先处理。建议去发热门诊。",
		"",
		"",
		["建议您先去发热门诊。", "查一下血常规和 CRP。", "请跟我来。"]
	)
	nurse.speak(entry3)
	print("[DialogueTest] Nurse more utterances")

	print("[DialogueTest] Test running - watch the bubbles!")


func holdup(entry: DialogueEntry) -> float:
	# Estimate display time: 1.5s per utterance + buffer
	return maxf(entry.utterance_count() * 2.0, 3.0)


func _find_npc(name: String):
	for node in get_tree().get_nodes_in_group("npcs"):
		if node is BaseNpc and node.get_npc_name() == name:
			return node
	return null
