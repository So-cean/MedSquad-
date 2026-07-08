class_name ScenarioConfig
extends RefCounted

const DEFAULT: Dictionary = {
	"triage_nurses": 2,
	"doctors": 2,
	"patients": 5,
	"bedside_nurses": 0,
	"technicians": 0,
	"devices": {},
	"nurse_names": ["李分诊", "王分诊"],
	"doctor_names": ["张医生", "赵医生"],
	"nurse_positions": [Vector2(830, 470), Vector2(930, 470)],
	"doctor_positions": [Vector2(1330, 500), Vector2(340, 200)],
	"patient_pool": [
		{"主诉": "头痛", "症状": "前额胀痛,恶心畏光", "持续时间": "三天"},
		{"主诉": "腹痛", "症状": "右下腹按压痛,低热", "持续时间": "半天"},
		{"主诉": "胸痛", "症状": "胸口闷痛,出汗", "持续时间": "一小时"},
		{"主诉": "外伤", "症状": "手臂割伤,出血", "持续时间": "刚发生"},
		{"主诉": "发热", "症状": "38.5度,全身酸痛", "持续时间": "两天"},
	],
}

const NURSE_FRAMES: String = "res://assets/nurse_frames/"
const DOCTOR_FRAMES: String = "res://assets/doctor_frames/"
const BEDSIDE_NURSE_FRAMES: String = "res://assets/nurse_green_frames/"
