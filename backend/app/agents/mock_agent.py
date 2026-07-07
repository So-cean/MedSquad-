from typing import Optional

from app.agents.base import BaseAgent
from app.schemas.plan import ActionPlan, AgentStepRequest, AgentStepResult, PlanStep
from app.schemas.simulation import ActorSpec, DeviceSpec, DiseaseSpec, PatientSpec, SimulationSpec, WorldState


class MockAgent(BaseAgent):
    def generate_plan(self, spec: SimulationSpec, world_state: WorldState) -> ActionPlan:
        if self._is_trauma_case(spec):
            return self._generate_trauma_plan(spec, world_state)

        nurse = self._find_actor(spec, "nurse") or spec.actors[0]
        doctor = self._find_actor(spec, "doctor") or nurse
        patient = spec.patients[0]
        patient_actor = self._actor_by_id(spec, patient.actor_id) or self._find_actor(spec, "patient") or nurse
        disease = self._first_patient_disease(spec, patient)
        device = self._first_device_for_disease(spec, disease)
        check_name = disease.recommended_checks[0] if disease and disease.recommended_checks else "检查"
        result = self._result_for_check(disease, check_name)

        steps = [
            PlanStep(
                id="step_001",
                type="speak",
                actor_id=nurse.id,
                target_actor_id=patient_actor.id,
                think=f"病人主诉{patient.chief_complaint}，需要先确认症状和风险等级。",
                dialogue=f"您好，我先了解一下情况。您是{patient.chief_complaint}，还有其他不舒服吗？",
                priority=nurse.priority_default,
                duration=4.0,
            ),
            PlanStep(
                id="step_002",
                type="speak",
                actor_id=patient_actor.id,
                target_actor_id=nurse.id,
                think="需要把主要症状告诉分诊护士，等待下一步安排。",
                dialogue=f"我主要是{patient.chief_complaint}，伴有{self._symptoms_text(patient)}。",
                priority=0,
                duration=3.0,
            ),
            PlanStep(
                id="step_003",
                type="speak",
                actor_id=nurse.id,
                target_actor_id=patient_actor.id,
                think=f"根据症状和风险等级，建议先完成{check_name}以排除高风险问题。",
                dialogue=f"根据您的情况，建议先到{check_name}室做进一步检查，我会通知医生查看结果。",
                priority=nurse.priority_default,
                duration=4.0,
            ),
        ]

        if device:
            steps.append(PlanStep(
                id="step_004",
                type="move_to",
                actor_id=patient_actor.id,
                location_id=device.location_id,
                duration=2.5,
                payload={"reason": f"前往{device.name}"},
            ))
            steps.append(PlanStep(
                id="step_005",
                type="use_device",
                actor_id=patient_actor.id,
                device_id=device.id,
                location_id=device.location_id,
                duration=device.operation_duration,
                payload={"result": result, "device_name": device.name},
            ))
        else:
            steps.append(PlanStep(id="step_004", type="wait", actor_id=patient_actor.id, duration=2.0))

        steps.extend([
            PlanStep(
                id="step_006",
                type="speak",
                actor_id=doctor.id,
                target_actor_id=nurse.id,
                think=f"检查结果为：{result}。需要结合症状给出模拟处置建议。",
                dialogue=f"检查结果已查看：{result}。目前先按流程观察和对症处理，如症状加重立即升级处理。",
                priority=doctor.priority_default,
                duration=4.0,
            ),
            PlanStep(
                id="step_007",
                type="speak",
                actor_id=nurse.id,
                target_actor_id=patient_actor.id,
                think="医生已经复核结果，需要向病人说明后续安排。",
                dialogue=f"医生已经看过检查结果。{self._patient_instruction(patient, disease)}",
                priority=nurse.priority_default,
                duration=4.0,
            ),
            PlanStep(id="step_008", type="end_simulation", duration=0.0, payload={"status": "completed"}),
        ])

        return ActionPlan(simulation_id=world_state.simulation_id, plan_id="plan_001", steps=steps)

    def _generate_trauma_plan(self, spec: SimulationSpec, world_state: WorldState) -> ActionPlan:
        emergency_nurse = self._find_actor_by_profession(spec, "emergency_nurse") or self._find_actor(spec, "nurse") or spec.actors[0]
        doctor = self._find_actor_by_profession(spec, "emergency_doctor") or self._find_actor(spec, "doctor") or emergency_nurse
        surgeon = self._find_actor_by_profession(spec, "surgeon") or doctor
        imaging_nurse = self._find_actor_by_profession(spec, "imaging_nurse") or emergency_nurse
        patient = spec.patients[0]
        patient_actor = self._actor_by_id(spec, patient.actor_id) or self._find_actor(spec, "patient") or emergency_nurse
        monitor = self._find_device_by_type(spec, "ecg_monitor")
        ct = self._find_device_by_type(spec, "ct_scanner")
        operation_table = self._find_device_by_type(spec, "operation_table")
        disease = self._first_patient_disease(spec, patient)
        ct_result = self._result_for_check(disease, "CT")

        steps = [
            PlanStep(
                id="step_001",
                type="speak",
                actor_id=emergency_nurse.id,
                target_actor_id=doctor.id,
                think="车祸患者生命体征不稳，优先启动抢救流程并通知急诊医生。",
                dialogue="急诊医生请到抢救区，车祸患者血压偏低、心率快，需要立即评估。",
                priority=4,
                duration=3.0,
            ),
            PlanStep(
                id="step_002",
                type="move_to",
                actor_id=patient_actor.id,
                location_id="ED_RESUS",
                duration=2.0,
                payload={"reason": "进入抢救区进行ABCDE评估"},
            ),
        ]
        if monitor:
            steps.append(PlanStep(
                id="step_003",
                type="use_device",
                actor_id=emergency_nurse.id,
                device_id=monitor.id,
                location_id=monitor.location_id,
                duration=monitor.operation_duration,
                payload={"device_name": monitor.name, "result": "心率118，血压90/58，SpO2 94%，需持续监护"},
            ))
        steps.extend([
            PlanStep(
                id="step_004",
                type="speak",
                actor_id=doctor.id,
                target_actor_id=emergency_nurse.id,
                think="按创伤ABCDE流程先稳定生命体征，再安排影像检查排除内出血。",
                dialogue="先建立静脉通路、持续监护，患者稳定后立即做创伤CT，同时通知创伤外科待命。",
                priority=4,
                duration=4.0,
            ),
        ])
        if ct:
            steps.extend([
                PlanStep(
                    id="step_005",
                    type="move_to",
                    actor_id=patient_actor.id,
                    location_id=ct.location_id,
                    duration=3.0,
                    payload={"reason": "抢救评估后转运至CT检查"},
                ),
                PlanStep(
                    id="step_006",
                    type="use_device",
                    actor_id=imaging_nurse.id,
                    device_id=ct.id,
                    location_id=ct.location_id,
                    duration=ct.operation_duration,
                    payload={"device_name": ct.name, "result": ct_result},
                ),
            ])
        steps.extend([
            PlanStep(
                id="step_007",
                type="speak",
                actor_id=doctor.id,
                target_actor_id=surgeon.id,
                think=f"影像结果提示：{ct_result}。需要创伤外科决定是否手术或ICU。",
                dialogue=f"创伤外科会诊：CT结果为{ct_result}，请评估手术探查和ICU收治资源。",
                priority=4,
                duration=4.0,
            ),
            PlanStep(
                id="step_008",
                type="move_to",
                actor_id=patient_actor.id,
                location_id="DISPOSITION",
                duration=2.0,
                payload={"reason": "进入去向讨论区完成资源调度"},
            ),
            PlanStep(
                id="step_009",
                type="speak",
                actor_id=surgeon.id,
                target_actor_id=doctor.id,
                think="结合血流动力学和CT结果，需准备手术/ICU资源。",
                dialogue="建议按创伤高风险处理，先准备手术资源，同时联系ICU床位，若血压继续下降立即进手术室。",
                priority=4,
                duration=4.0,
            ),
        ])
        if operation_table:
            steps.append(PlanStep(
                id="step_010",
                type="use_device",
                actor_id=surgeon.id,
                device_id=operation_table.id,
                location_id=operation_table.location_id,
                duration=operation_table.operation_duration,
                payload={"device_name": operation_table.name, "result": "手术资源预占，创伤团队待命"},
            ))
        steps.append(PlanStep(id="step_011", type="end_simulation", duration=0.0, payload={"status": "completed"}))
        return ActionPlan(simulation_id=world_state.simulation_id, plan_id="plan_trauma_001", steps=steps)

    def step(self, request: AgentStepRequest, spec: SimulationSpec, world_state: WorldState) -> AgentStepResult:
        actor = self._actor_by_id(spec, request.actor_id)
        target = self._actor_by_id(spec, request.target_actor_id) if request.target_actor_id else None
        actor_name = actor.display_name if actor else request.actor_id
        target_name = target.display_name if target else "对方"
        think = f"{actor_name}正在根据意图 {request.intent} 组织下一步沟通。"
        dialogue = f"{target_name}，我会根据当前流程继续处理，请稍等。"
        action = PlanStep(
            id="agent_step_001",
            type="speak",
            actor_id=request.actor_id,
            target_actor_id=request.target_actor_id,
            think=think,
            dialogue=dialogue,
            duration=3.0,
        )
        return AgentStepResult(actions=[action], think=think, dialogue=dialogue, state_patch={})

    def _find_actor(self, spec: SimulationSpec, actor_type: str) -> Optional[ActorSpec]:
        return next((actor for actor in spec.actors if actor.type == actor_type), None)

    def _find_actor_by_profession(self, spec: SimulationSpec, profession: str) -> Optional[ActorSpec]:
        return next((actor for actor in spec.actors if actor.profession == profession), None)

    def _actor_by_id(self, spec: SimulationSpec, actor_id: Optional[str]) -> Optional[ActorSpec]:
        if not actor_id:
            return None
        return next((actor for actor in spec.actors if actor.id == actor_id), None)

    def _first_patient_disease(self, spec: SimulationSpec, patient: PatientSpec) -> Optional[DiseaseSpec]:
        disease_ids = set(patient.disease_ids)
        return next((disease for disease in spec.diseases if disease.id in disease_ids), None)

    def _first_device_for_disease(self, spec: SimulationSpec, disease: Optional[DiseaseSpec]) -> Optional[DeviceSpec]:
        checks = [check.lower() for check in disease.recommended_checks] if disease else []
        for device in spec.devices:
            if "ct" in checks and device.type == "ct_scanner":
                return device
            if any(capability.lower() in checks for capability in device.capabilities):
                return device
        return spec.devices[0] if spec.devices else None

    def _find_device_by_type(self, spec: SimulationSpec, device_type: str) -> Optional[DeviceSpec]:
        return next((device for device in spec.devices if device.type == device_type), None)

    def _result_for_check(self, disease: Optional[DiseaseSpec], check_name: str) -> str:
        if disease:
            for finding in disease.expected_findings:
                if str(finding.get("test", "")).lower() == check_name.lower():
                    return str(finding.get("result", "结果待复核"))
        return "未见明显急危重异常"

    def _symptoms_text(self, patient: PatientSpec) -> str:
        return "、".join(patient.symptoms) if patient.symptoms else "没有明显伴随症状"

    def _patient_instruction(self, patient: PatientSpec, disease: Optional[DiseaseSpec]) -> str:
        disease_name = disease.name if disease else ""
        complaint = patient.chief_complaint
        if "胃" in disease_name or "腹" in complaint or "胃" in complaint:
            return "请您先按医嘱饮食清淡、避免刺激性食物；如果腹痛明显加重、黑便、呕血或持续呕吐，请立刻回来就诊。"
        if "头" in complaint:
            return "请您先休息观察；如果头痛加重、反复呕吐或意识不清，请立刻告诉我们。"
        return "请您先按医嘱观察；如果症状明显加重或出现新的不适，请立刻告诉我们。"

    def _is_trauma_case(self, spec: SimulationSpec) -> bool:
        text = " ".join([
            spec.title,
            " ".join(objective.description for objective in spec.objectives),
            " ".join(disease.name for disease in spec.diseases),
            " ".join(patient.chief_complaint for patient in spec.patients),
        ])
        return any(token in text for token in ["车祸", "创伤", "外伤", "抢救"])
