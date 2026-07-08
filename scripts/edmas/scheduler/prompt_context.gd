class_name PromptContext
extends RefCounted


static func build_resource_snapshot() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return "医院当前资源：SceneTree 未就绪"
	var reg: Node = tree.root.get_node_or_null("/root/ResourceRegistry")
	if not reg or not reg.has_method("get_all"):
		return "医院当前资源：ResourceRegistry 未就绪"

	var by_role: Dictionary = {}
	for res in reg.get_all():
		var role: String = res.role
		if not by_role.has(role):
			by_role[role] = []
		var occ: String = "空闲"
		if res.is_busy():
			occ = "与%s处理中" % res.occupant_id
		var item: String = "%s@%s(%s, 队列长度=%d)" % [
			res.display_name, res.location, occ, res.queue_size()
		]
		by_role[role].append(item)

	var lines: Array[String] = ["医院当前资源："]
	for role in by_role.keys():
		lines.append("- %s: %s" % [role, _join_strings(by_role[role], " | ")])
	return "\n".join(lines)


static func _join_strings(items: Array, sep: String) -> String:
	var parts: Array[String] = []
	for item in items:
		parts.append(str(item))
	return sep.join(parts)


static func build_agent_prompt(role: String, self_npc: BaseNpc, target_npc: BaseNpc, memory: String = "", extras: Dictionary = {}) -> String:
	match role:
		"triage_nurse":
			return _build_triage_nurse_prompt(self_npc, target_npc, memory, extras)
		"doctor":
			return _build_doctor_prompt(self_npc, target_npc, memory, extras)
		"patient":
			return _build_patient_prompt(self_npc, target_npc, memory, extras)
		_:
			return _build_patient_prompt(self_npc, target_npc, memory, extras)


static func _patient_knowledge(extras: Dictionary) -> String:
	return str(extras.get("patient_knowledge", []))


static func _visible_patient_info(extras: Dictionary) -> String:
	var visible: String = str(extras.get("patient_visible_memory", "")).strip_edges()
	if visible.is_empty():
		return "尚未采集到患者描述。请先让患者描述主诉、症状、持续时间。"
	return visible


static func _build_patient_prompt(self_npc: BaseNpc, target_npc: BaseNpc, memory: String, extras: Dictionary) -> String:
	var target_name: String = target_npc.get_npc_name() if target_npc else "医护人员"
	var instruction: String = "如果对方刚问问题，只回答这个问题；如果对方给了指示，回一句好的并停止追问。"
	if memory.is_empty():
		instruction = "你第一次开口是在主动描述病情：只说最难受的1-2个症状和大概持续时间，不要说“好的”，不要一次说完全部病史。"
	return (
		"你是普通患者%s，正在医院看病。\n" % self_npc.get_npc_name()
		+ "对方是%s。\n" % target_name
		+ "你的病例信息：%s\n" % _patient_knowledge(extras)
		+ "对话历史：\n%s\n" % (memory if not memory.is_empty() else "（暂无）")
		+ build_resource_snapshot() + "\n"
		+ instruction + "\n"
		+ "必须只返回 JSON：\n"
		+ '{"think":"","utterances":["10-20字大白话"]}\n'
		+ 'think可选：不填或填内心感受/回想的信息，不要重复已知事实。'
	)


static func _build_triage_nurse_prompt(self_npc: BaseNpc, target_npc: BaseNpc, memory: String, extras: Dictionary) -> String:
	var patient_id: String = extras.get("patient_id", "")
	return (
		"你是急诊分诊护士%s，正在给%s做分诊。\n" % [self_npc.get_npc_name(), patient_id]
		+ "你不能读取患者隐藏病例，只能根据患者已经说出口的信息判断。\n"
		+ "已采集信息：%s\n" % _visible_patient_info(extras)
		+ "对话历史：\n%s\n" % (memory if not memory.is_empty() else "（暂无）")
		+ build_resource_snapshot() + "\n"
		+ "如果尚未采集到患者描述，第一句必须是问候和开放式询问，例如“您好，您哪里不舒服？症状多久了？”，不要诊断，不要安排去医生或离院。\n"
		+ "目标：3-5轮内完成分诊。症状严重时 next_step.next_role=doctor，目标诊室 target_room=DOCTOR 或 ED_RESUS；轻症可 discharge。\n"
		+ "必须只返回 JSON：\n"
		+ '{"think":"","responses":[{"target":"%s","utterances":["对患者说1句话"],"conversation_done":false}],"next_step":null}\n' % patient_id
		+ 'think可选：不填或填分诊推理/资源判断，不要重复已知事实。'
	)


static func _build_doctor_prompt(self_npc: BaseNpc, target_npc: BaseNpc, memory: String, extras: Dictionary) -> String:
	var patient_id: String = extras.get("patient_id", "")
	return (
		"你是急诊医生%s，正在接诊%s。\n" % [self_npc.get_npc_name(), patient_id]
		+ "你不能读取患者隐藏病例，只能根据患者口述、护士分诊记录、既往对话判断。\n"
		+ "已采集信息/分诊记录：%s\n" % _visible_patient_info(extras)
		+ "对话历史：\n%s\n" % (memory if not memory.is_empty() else "（暂无）")
		+ build_resource_snapshot() + "\n"
		+ "如果尚未采集到患者描述，第一句必须是问候和开放式询问，例如“您好，我是接诊医生，请说一下哪里不舒服？”，不要诊断，不要直接离院。\n"
		+ "问诊要短：先问病史/既往史/过敏，再决定处置。3-5轮内完成。\n"
		+ "orders 白名单：ct_scan / lab_test / ecg。Step 4A 阶段无设备 session，若输出 orders，scheduler 会 warning 后 discharge。\n"
		+ "必须只返回 JSON：\n"
		+ '{"think":"","responses":[{"target":"%s","utterances":["对患者说1句话"],"conversation_done":false}],"next_step":null}\n' % patient_id
		+ 'think可选：不填或填诊断推理，不要重复已知事实。'
	)
