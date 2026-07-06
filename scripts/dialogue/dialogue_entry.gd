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
var target: String = ""
var mood: String = "neutral"


func _init(
	p_speaker: String = "",
	p_think: String = "",
	p_dialogue: String = "",
	p_target: String = ""
) -> void:
	speaker = p_speaker
	think = p_think
	dialogue = p_dialogue
	target = p_target


## Returns true when there is nothing to show in the bubble.
func is_empty() -> bool:
	return dialogue.is_empty()
