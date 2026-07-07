extends RefCounted
class_name MockAgentProfiles

const PROFILES: Dictionary = {
	"mock_patient_A": {
		"patient_id": "mock_patient_A",
		"display_name": "Patient A",
		"triage_level": "L3",
		"chief_complaint": "mild abdominal pain",
		"dialogue_lines": [
			"I have been feeling uncomfortable since this morning.",
			"The pain is not severe, but I would like to be checked.",
		],
	},
	"mock_patient_B": {
		"patient_id": "mock_patient_B",
		"display_name": "Patient B",
		"triage_level": "L2",
		"chief_complaint": "chest discomfort",
		"dialogue_lines": [
			"My chest feels tight when I breathe deeply.",
			"It started after I walked up the stairs.",
		],
	},
	"mock_patient_C": {
		"patient_id": "mock_patient_C",
		"display_name": "Patient C",
		"triage_level": "L4",
		"chief_complaint": "headache",
		"dialogue_lines": [
			"I have had a headache for most of the day.",
			"It is annoying, but I can still talk normally.",
		],
	},
}

func get_profile(patient_id: String) -> Dictionary:
	var profile_value: Variant = PROFILES.get(patient_id, {})
	if typeof(profile_value) == TYPE_DICTIONARY:
		return profile_value as Dictionary
	return {}

func has_profile(patient_id: String) -> bool:
	return PROFILES.has(patient_id)

func list_profiles() -> Array:
	return [
		PROFILES["mock_patient_A"],
		PROFILES["mock_patient_B"],
		PROFILES["mock_patient_C"],
	]
