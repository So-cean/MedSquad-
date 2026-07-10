extends RefCounted
class_name PatientCasePool

const CASES: Dictionary = {
	"case_chest_pain": {
		"case_id": "case_chest_pain",
		"chief_complaint": "胸口闷痛半天，走快一点就更明显。",
		"acuity_hint": "send_to_doctor",
		"patient_reply": "我胸口闷了半天，有点喘不上气，刚才走路时更明显。",
		"patient_detail": "疼痛不是特别尖锐，但一直压着不舒服，左肩也有点酸。",
		"triage_question": "胸口闷痛从什么时候开始？有没有出汗、恶心或放射到手臂？",
		"vitals_line": "血压 148/92，心率 104，我会优先安排医生评估并考虑心电图。",
		"nurse_decision": "send_to_doctor",
		"doctor_handoff": "我来接手。先做心电图和重点查体，排除急性胸痛风险。",
		"local_result": "已转交医生进一步评估胸痛风险。",
	},
	"case_fever": {
		"case_id": "case_fever",
		"chief_complaint": "发热三天，伴随咳嗽和咽痛。",
		"acuity_hint": "send_to_doctor",
		"patient_reply": "我发热三天了，晚上更明显，咳嗽后喉咙也疼。",
		"patient_detail": "最高体温 38.5 度，没有胸痛，就是全身酸痛、没什么力气。",
		"triage_question": "有没有胸闷、呼吸困难、皮疹，或者近期接触发热病人？",
		"vitals_line": "体温 38.5，血氧 98%，先按普通发热流程转医生判断。",
		"nurse_decision": "send_to_doctor",
		"doctor_handoff": "我来评估感染风险，必要时安排血常规和呼吸道检查。",
		"local_result": "已完成分诊，等待医生接手发热病例。",
	},
	"case_leg_numbness": {
		"case_id": "case_leg_numbness",
		"chief_complaint": "下肢突然麻木，走路不稳。",
		"acuity_hint": "send_to_resus",
		"patient_reply": "麻木是突然开始的，越来越明显，刚才差点站不稳。",
		"patient_detail": "我感觉一侧腿没有力气，说话倒还清楚，但很担心。",
		"triage_question": "有没有口角歪斜、说话含糊、头晕，或者一侧肢体无力？",
		"vitals_line": "出现突发神经系统症状，我会直接升级优先级并通知抢救区。",
		"nurse_decision": "send_to_resus",
		"doctor_handoff": "先进入抢救区，马上做神经系统评估和进一步检查。",
		"local_result": "已优先送入急救链路。",
	},
	"case_abdominal_pain": {
		"case_id": "case_abdominal_pain",
		"chief_complaint": "右下腹痛六小时，活动时加重。",
		"acuity_hint": "send_to_doctor",
		"patient_reply": "我右下腹痛了六个小时，走路和咳嗽时更疼。",
		"patient_detail": "有点恶心，但还没有呕吐，今天也不太想吃东西。",
		"triage_question": "疼痛有没有转移？有没有发热、呕吐或腹泻？",
		"vitals_line": "体温 37.8，腹痛位置固定，我会安排医生尽快查看。",
		"nurse_decision": "send_to_doctor",
		"doctor_handoff": "我来接手，先做腹部查体，必要时安排血常规和影像检查。",
		"local_result": "已转交医生评估急腹症风险。",
	},
	"case_shortness_breath": {
		"case_id": "case_shortness_breath",
		"chief_complaint": "突然气短，平躺时更不舒服。",
		"acuity_hint": "send_to_resus",
		"patient_reply": "我突然觉得喘不上气，坐起来会稍微好一点。",
		"patient_detail": "胸口有点压迫感，说话多了就更喘。",
		"triage_question": "有没有胸痛、咯血、下肢肿胀，或者既往心肺疾病？",
		"vitals_line": "呼吸频率偏快，我会先给您提高优先级并联系医生。",
		"nurse_decision": "send_to_resus",
		"doctor_handoff": "先进入抢救区，监测血氧和生命体征，马上评估呼吸困难原因。",
		"local_result": "已进入呼吸困难急救评估流程。",
	},
	"case_minor_cut": {
		"case_id": "case_minor_cut",
		"chief_complaint": "手指划伤，出血已经基本止住。",
		"acuity_hint": "send_to_doctor",
		"patient_reply": "我切菜时划到手指，刚开始流血，现在基本止住了。",
		"patient_detail": "伤口不深，但我不确定要不要打破伤风。",
		"triage_question": "伤口是什么东西划伤的？有没有麻木、活动受限或污染？",
		"vitals_line": "生命体征平稳，属于低优先级外伤处理，请稍等医生处理伤口。",
		"nurse_decision": "send_to_doctor",
		"doctor_handoff": "我来检查伤口深度，判断是否需要清创、缝合或破伤风预防。",
		"local_result": "已完成低优先级外伤分诊。",
	},
}

static func get_case(case_id: String) -> Dictionary:
	var case_value: Variant = CASES.get(case_id, {})
	if typeof(case_value) == TYPE_DICTIONARY:
		return case_value as Dictionary
	return {}

static func get_case_ids() -> Array:
	var ids: Array = []
	for case_id_value: Variant in CASES.keys():
		ids.append(str(case_id_value))
	return ids

static func get_default_case_id() -> String:
	return "case_chest_pain"
