class_name DialogueEntry
extends RefCounted

## Data interface for NPC dialogue.
##
## Each NPC's "utterance" consists of:
##   think    — internal reasoning / RAG results (shown first, typewriter)
##   dialogue — actual spoken text (shown after think completes)
##
## Future AI agents produce both fields through the same interface.
## When dialogue is empty the bubble hides. When think is empty
## but dialogue is not, the dialogue appears directly.

var speaker: String = ""
var think: String = ""
var dialogue: String = ""
var utterances: Array[String] = []
var target: String = ""
var mood: String = "neutral"


func _init(
	p_speaker: String = "",
	p_think: String = "",
	p_dialogue: String = "",
	p_target: String = "",
	p_utterances: Array[String] = []
) -> void:
	speaker = p_speaker
	think = p_think
	dialogue = p_dialogue
	target = p_target
	utterances = p_utterances
	if p_utterances.is_empty() and not p_dialogue.is_empty():
		utterances = [p_dialogue]


## Returns true when there is nothing to show in the bubble.
func is_empty() -> bool:
	return dialogue.is_empty() and utterances.is_empty()

## Returns the number of display items.
func utterance_count() -> int:
	return utterances.size() if utterances.size() > 0 else (1 if not dialogue.is_empty() else 0)

## Get the i-th utterance.
func get_utterance(idx: int) -> String:
	if idx >= 0 and idx < utterances.size():
		return utterances[idx]
	return dialogue
