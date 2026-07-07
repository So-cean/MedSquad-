"""
Per-round agent that drives the simulation one step at a time.

Instead of generating the entire ActionPlan upfront, this agent calls
the LLM on every turn to decide the single next action.  The caller
(interactive_demo.py) runs the main loop:

    while not finished:
        step = agent.next_step(spec, world_state, history)
        print(step)
        apply_step(world_state, step)
"""

import json
from typing import Any, Dict, List

from app.config import settings
from app.schemas.compat import model_to_dict, model_validate
from app.schemas.plan import PlanStep
from app.schemas.simulation import SimulationSpec, WorldState
from app.services.agent_context_service import AgentContextService
from app.services.map_context_service import describe_map_context
from app.services.openai_client import chat_completion


class StepAgent:
    """LLM-driven agent that picks the single next action each turn."""

    def next_step(
        self,
        spec: SimulationSpec,
        world_state: WorldState,
        history: List[Dict[str, Any]],
        step_index: int,
    ) -> PlanStep:
        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY/api_key is not configured")

        result = chat_completion(
            messages=[
                {"role": "system", "content": _system_prompt(spec)},
                {"role": "user", "content": _user_prompt(spec, world_state, history, step_index)},
            ],
            temperature=0.45,
            top_p=0.7,
            max_tokens=2048,
            frequency_penalty=1.0,
            response_format={"type": "json_object"},
            extra_body={"top_k": 50},
        )
        raw = json.loads(result["choices"][0]["message"]["content"])
        step = _parse_step(raw, step_index, spec)
        _validate_step(step, spec)
        return step

    def next_step_mock(
        self,
        spec: SimulationSpec,
        world_state: WorldState,
        history: List[Dict[str, Any]],
        step_index: int,
    ) -> PlanStep:
        """Deterministic fallback when no API key is configured."""
        return MockStepAgent().next_step(spec, world_state, history, step_index)


class MockStepAgent:
    """Deterministic step agent for offline development and testing."""

    def next_step(
        self,
        spec: SimulationSpec,
        world_state: WorldState,
        history: List[Dict[str, Any]],
        step_index: int,
    ) -> PlanStep:
        # Build a simple script from the spec
        script = self._build_script(spec)
        if step_index < len(script):
            return script[step_index]
        return PlanStep(
            id=f"step_{step_index:03d}",
            type="end_simulation",
            duration=0.0,
            payload={"status": "completed"},
        )

    def _build_script(self, spec: SimulationSpec) -> List[PlanStep]:
        is_trauma = self._is_trauma(spec)
        triage_nurse = self._find_by_profession(spec, "triage_nurse") or self._find_by_type(spec, "nurse")
        doctor = self._find_by_type(spec, "doctor")
        patient = spec.patients[0] if spec.patients else None
        patient_actor = self._find_by_id(spec, patient.actor_id) if patient else self._find_by_type(spec, "patient")
        disease = self._first_disease(spec, patient)

        if is_trauma:
            return self._trauma_script(spec, triage_nurse, doctor, patient, patient_actor, disease)
        return self._generic_script(spec, triage_nurse, doctor, patient, patient_actor, disease)

    def _trauma_script(self, spec, nurse, doctor, patient, patient_actor, disease):
        monitor = self._find_device_by_type(spec, "ecg_monitor")
        ct = self._find_device_by_type(spec, "ct_scanner")
        surgeon = self._find_by_profession(spec, "surgeon") or doctor
        or_table = self._find_device_by_type(spec, "operation_table")
        ct_result = self._result_for(disease, "CT")

        steps: List[PlanStep] = []
        idx = 0

        if nurse:
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="speak",
                actor_id=nurse.id, target_actor_id=doctor.id if doctor else None,
                think="车祸患者生命体征不稳，立即通知急诊医生启动抢救。",
                dialogue="急诊医生请到抢救区，车祸患者血压偏低、心率快，需要立即评估。",
                priority=4, duration=3.0,
            ))

        if patient_actor:
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="move_to",
                actor_id=patient_actor.id, location_id="ED_RESUS",
                duration=2.0, payload={"reason": "进入抢救区进行ABCDE评估"},
            ))

        if monitor and nurse:
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="use_device",
                actor_id=nurse.id, device_id=monitor.id, location_id=monitor.location_id,
                duration=monitor.operation_duration,
                payload={"device_name": monitor.name, "result": "心率118，血压90/58，SpO2 94%"},
            ))

        if doctor:
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="speak",
                actor_id=doctor.id, target_actor_id=nurse.id if nurse else None,
                think="按ABCDE流程先稳定生命体征，再安排影像检查。",
                dialogue="先建立静脉通路、持续监护，患者稳定后立即做创伤CT，同时通知创伤外科待命。",
                priority=4, duration=4.0,
            ))

        if ct and patient_actor:
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="move_to",
                actor_id=patient_actor.id, location_id=ct.location_id,
                duration=3.0, payload={"reason": "转运至CT检查"},
            ))
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="use_device",
                actor_id=(nurse.id if nurse else patient_actor.id),
                device_id=ct.id, location_id=ct.location_id,
                duration=ct.operation_duration,
                payload={"device_name": ct.name, "result": ct_result},
            ))

        if doctor and surgeon:
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="speak",
                actor_id=doctor.id, target_actor_id=surgeon.id,
                think=f"CT结果：{ct_result}，需要创伤外科会诊。",
                dialogue=f"创伤外科会诊：CT结果为{ct_result}，请评估手术探查和ICU收治资源。",
                priority=4, duration=4.0,
            ))

        if patient_actor:
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="move_to",
                actor_id=patient_actor.id, location_id="DISPOSITION",
                duration=2.0, payload={"reason": "进入去向讨论区"},
            ))

        if surgeon:
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="speak",
                actor_id=surgeon.id, target_actor_id=doctor.id if doctor else None,
                think="结合血流动力学和CT结果，准备手术/ICU资源。",
                dialogue="建议按创伤高风险处理，先准备手术资源，同时联系ICU床位，若血压继续下降立即进手术室。",
                priority=4, duration=4.0,
            ))

        if or_table and surgeon:
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="use_device",
                actor_id=surgeon.id, device_id=or_table.id, location_id=or_table.location_id,
                duration=or_table.operation_duration,
                payload={"device_name": or_table.name, "result": "手术资源预占，创伤团队待命"},
            ))

        return steps

    def _generic_script(self, spec, nurse, doctor, patient, patient_actor, disease):
        device = self._first_device(spec, disease)
        check_name = disease.recommended_checks[0] if disease and disease.recommended_checks else "检查"
        result = self._result_for(disease, check_name)

        steps: List[PlanStep] = []
        idx = 0

        if nurse and patient_actor:
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="speak",
                actor_id=nurse.id, target_actor_id=patient_actor.id,
                think=f"病人主诉{patient.chief_complaint if patient else '不适'}，先确认症状。",
                dialogue=f"您好，我先了解一下情况。您是{patient.chief_complaint if patient else '不舒服'}，还有其他症状吗？",
                priority=nurse.priority_default, duration=4.0,
            ))

        if patient_actor and nurse:
            idx += 1
            symptoms = "、".join(patient.symptoms) if patient and patient.symptoms else "没有其他明显症状"
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="speak",
                actor_id=patient_actor.id, target_actor_id=nurse.id,
                think="把症状告诉护士，等待下一步安排。",
                dialogue=f"我主要是{patient.chief_complaint if patient else '不舒服'}，伴有{symptoms}。",
                priority=0, duration=3.0,
            ))

        if nurse and patient_actor:
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="speak",
                actor_id=nurse.id, target_actor_id=patient_actor.id,
                think=f"建议先做{check_name}检查。",
                dialogue=f"根据您的情况，建议先到{check_name}室做进一步检查，我会通知医生查看结果。",
                priority=nurse.priority_default, duration=4.0,
            ))

        if device and patient_actor:
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="move_to",
                actor_id=patient_actor.id, location_id=device.location_id,
                duration=2.5, payload={"reason": f"前往{device.name}"},
            ))
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="use_device",
                actor_id=patient_actor.id, device_id=device.id, location_id=device.location_id,
                duration=device.operation_duration,
                payload={"device_name": device.name, "result": result},
            ))

        if doctor:
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="speak",
                actor_id=doctor.id, target_actor_id=nurse.id if nurse else None,
                think=f"检查结果：{result}，结合症状给出建议。",
                dialogue=f"检查结果已查看：{result}。目前先按流程观察和对症处理，如症状加重立即升级处理。",
                priority=doctor.priority_default, duration=4.0,
            ))

        if nurse and patient_actor:
            idx += 1
            steps.append(PlanStep(
                id=f"step_{idx:03d}", type="speak",
                actor_id=nurse.id, target_actor_id=patient_actor.id,
                think="医生已复核，向病人说明后续安排。",
                dialogue="医生已经看过检查结果。请您先按医嘱观察，如果症状明显加重，请立刻告诉我们。",
                priority=nurse.priority_default, duration=4.0,
            ))

        return steps

    def _is_trauma(self, spec: SimulationSpec) -> bool:
        text = " ".join([
            spec.title,
            " ".join(obj.description for obj in spec.objectives),
            " ".join(d.name for d in spec.diseases),
            " ".join(p.chief_complaint for p in spec.patients),
        ])
        return any(t in text for t in ["车祸", "创伤", "外伤", "抢救"])

    def _find_by_type(self, spec, actor_type):
        return next((a for a in spec.actors if a.type == actor_type), None)

    def _find_by_profession(self, spec, profession):
        return next((a for a in spec.actors if a.profession == profession), None)

    def _find_by_id(self, spec, actor_id):
        if not actor_id:
            return None
        return next((a for a in spec.actors if a.id == actor_id), None)

    def _find_device_by_type(self, spec, device_type):
        return next((d for d in spec.devices if d.type == device_type), None)

    def _first_disease(self, spec, patient):
        if not patient or not patient.disease_ids:
            return spec.diseases[0] if spec.diseases else None
        ids = set(patient.disease_ids)
        return next((d for d in spec.diseases if d.id in ids), None)

    def _first_device(self, spec, disease):
        checks = [c.lower() for c in disease.recommended_checks] if disease else []
        for d in spec.devices:
            if "ct" in checks and d.type == "ct_scanner":
                return d
            if any(c in d.capabilities for c in [x.lower() for x in d.capabilities]):
                return d
        return spec.devices[0] if spec.devices else None

    def _result_for(self, disease, check_name):
        if disease:
            for f in disease.expected_findings:
                if str(f.get("test", "")).lower() == check_name.lower():
                    return str(f.get("result", "结果待复核"))
        return "未见明显急危重异常"


# ---------------------------------------------------------------------------
# Prompt builders
# ---------------------------------------------------------------------------

def _system_prompt(spec: SimulationSpec) -> str:
    prompts = AgentContextService().build_system_prompts(spec)
    schema = json.dumps(_step_schema(), ensure_ascii=False)

    # Build an explicit ID table so the LLM uses exact IDs
    actor_table = "\n".join(
        f"  - id=\"{a.id}\", display_name=\"{a.display_name}\", type={a.type}, profession={a.profession}"
        for a in spec.actors
    )
    location_table = "\n".join(f"  - \"{l.id}\" ({l.name})" for l in spec.scene.locations)
    device_table = "\n".join(
        f"  - id=\"{d.id}\", name=\"{d.name}\", type={d.type}, location=\"{d.location_id}\""
        for d in spec.devices
    )

    return (
        "你是 EDMAS 医院急诊仿真系统的逐轮行动导演。\n"
        "你每次只输出**一个**下一步动作（PlanStep），不要输出多步。\n"
        "你必须输出严格 JSON，不要 Markdown。\n\n"
        "可用动作类型：speak, move_to, use_device, wait, end_simulation。\n"
        "speak 必须有 actor_id、target_actor_id、think 和 dialogue。\n"
        "move_to 必须有 actor_id 和 location_id（来自地图房间 ID）。\n"
        "use_device 必须有 actor_id、device_id 和 location_id。\n"
        "end_simulation 表示流程结束，只需 type 和 payload: {status: 'completed'}。\n\n"
        "【重要】actor_id 必须使用下面列表中精确的 id 值（如 \"nurse1\"），不能使用 display_name！\n"
        "【重要】location_id 必须使用下面列表中精确的 id 值（如 \"ED_ENTRANCE\"）！\n"
        "【重要】device_id 必须使用下面列表中精确的 id 值（如 \"ct_001\"）！\n\n"
        "有效的 actor_id 列表：\n"
        f"{actor_table}\n\n"
        "有效的 location_id 列表：\n"
        f"{location_table}\n\n"
        "有效的 device_id 列表：\n"
        f"{device_table}\n\n"
        "规则：\n"
        "- 每轮只推进一个角色的一步动作。\n"
        "- 角色要按医疗流程顺序行动：先分诊护士、再医生、再检查、再会诊。\n"
        "- dialogue 必须用中文，符合角色身份和性格。\n"
        "- think 是该角色的内心推理，用中文。\n"
        "- 涉及资源调度时，角色要明确说出调度理由。\n"
        "- 当所有必要步骤完成后，输出 end_simulation。\n"
        "- 不要重复已经发生过的对话。\n\n"
        "每个角色的 system prompt 如下：\n"
        + "\n\n".join(f"--- {actor_id} ---\n{p}" for actor_id, p in prompts.items())
        + "\n\n地图上下文：\n"
        + describe_map_context()
        + "\n\nJSON schema：\n"
        + schema
    )


def _user_prompt(
    spec: SimulationSpec,
    world_state: WorldState,
    history: List[Dict[str, Any]],
    step_index: int,
) -> str:
    # Build a compact representation of what's happened so far
    history_lines = []
    for h in history:
        actor_name = _actor_name(spec, h.get("actor_id", ""))
        target_name = _actor_name(spec, h.get("target_actor_id", ""))
        t = h.get("type", "")
        if t == "speak":
            history_lines.append(
                f"[{h.get('think','')}] {actor_name} -> {target_name}: {h.get('dialogue','')}"
            )
        elif t == "move_to":
            history_lines.append(
                f"{actor_name} 移动到 {h.get('location_id','')}（{h.get('payload',{}).get('reason','')}）"
            )
        elif t == "use_device":
            history_lines.append(
                f"{actor_name} 使用 {h.get('payload',{}).get('device_name','设备')}，结果：{h.get('payload',{}).get('result','')}"
            )

    # Current actor locations
    location_lines = []
    for aid, a in world_state.actors.items():
        location_lines.append(f"  {a.get('display_name', aid)} 当前在 {a.get('location_id', '?')}")

    return json.dumps(
        {
            "step_index": step_index,
            "simulation_title": spec.title,
            "objectives": [o.description for o in spec.objectives],
            "patients": [
                {
                    "name": p.name,
                    "chief_complaint": p.chief_complaint,
                    "symptoms": p.symptoms,
                    "risk_level": p.risk_level,
                    "disease_ids": p.disease_ids,
                }
                for p in spec.patients
            ],
            "diseases": [
                {"name": d.name, "severity": d.severity, "care_pathway": d.care_pathway}
                for d in spec.diseases
            ],
            "current_actor_locations": location_lines,
            "conversation_history": history_lines,
            "instruction": (
                "请根据对话历史、当前角色位置和医疗流程，决定下一步谁做什么。"
                "输出一个 PlanStep JSON。如果流程已完成，输出 end_simulation。"
            ),
        },
        ensure_ascii=False,
    )


def _actor_name(spec: SimulationSpec, actor_id: str) -> str:
    for a in spec.actors:
        if a.id == actor_id:
            return a.display_name
    return actor_id


def _step_schema() -> dict:
    return {
        "type": "object",
        "properties": {
            "id": {"type": "string"},
            "type": {"type": "string", "enum": ["speak", "move_to", "use_device", "wait", "end_simulation"]},
            "actor_id": {"type": "string"},
            "target_actor_id": {"type": "string"},
            "location_id": {"type": "string"},
            "device_id": {"type": "string"},
            "think": {"type": "string"},
            "dialogue": {"type": "string"},
            "priority": {"type": "integer"},
            "duration": {"type": "number"},
            "payload": {"type": "object"},
        },
        "required": ["id", "type"],
    }


def _parse_step(raw: Dict[str, Any], step_index: int, spec: SimulationSpec = None) -> PlanStep:
    raw.setdefault("id", f"step_{step_index:03d}")
    if raw.get("duration") is None:
        raw["duration"] = 3.0
    raw.setdefault("duration", 3.0)
    if raw.get("priority") is None:
        raw["priority"] = 1
    raw.setdefault("priority", 1)
    if raw.get("payload") is None:
        raw["payload"] = {}
    raw.setdefault("payload", {})
    # Remove null fields that LLM sometimes emits
    for key in list(raw.keys()):
        if raw[key] is None:
            if key in ("think", "dialogue", "actor_id", "target_actor_id", "location_id", "device_id"):
                raw[key] = ""
            elif key in ("payload",):
                raw[key] = {}
            elif key in ("duration",):
                raw[key] = 3.0
            elif key in ("priority",):
                raw[key] = 1

    # Auto-correct: if the LLM used a display_name instead of an id, fix it
    if spec and raw.get("actor_id"):
        raw["actor_id"] = _resolve_actor_id(spec, raw["actor_id"])
    if spec and raw.get("target_actor_id"):
        raw["target_actor_id"] = _resolve_actor_id(spec, raw["target_actor_id"])

    return model_validate(PlanStep, raw)


def _resolve_actor_id(spec: SimulationSpec, value: str) -> str:
    """If value matches a display_name, return the real id instead."""
    if not value:
        return value
    for a in spec.actors:
        if a.id == value:
            return value
    for a in spec.actors:
        if a.display_name == value:
            return a.id
    return value


def _validate_step(step: PlanStep, spec: SimulationSpec) -> None:
    actor_ids = {a.id for a in spec.actors}
    location_ids = {l.id for l in spec.scene.locations}
    device_ids = {d.id for d in spec.devices}

    if step.actor_id and step.actor_id not in actor_ids:
        raise ValueError(f"step {step.id} references unknown actor_id: {step.actor_id}")
    if step.target_actor_id and step.target_actor_id not in actor_ids:
        raise ValueError(f"step {step.id} references unknown target_actor_id: {step.target_actor_id}")
    if step.location_id and step.location_id not in location_ids:
        raise ValueError(f"step {step.id} references unknown location_id: {step.location_id}")
    if step.device_id and step.device_id not in device_ids:
        raise ValueError(f"step {step.id} references unknown device_id: {step.device_id}")