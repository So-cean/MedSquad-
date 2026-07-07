import json
from typing import Any, Dict, List, Optional

from app.config import settings
from app.schemas.common import Position
from app.schemas.compat import model_validate
from app.schemas.intent import ScenarioIntentResponse
from app.schemas.simulation import (
    ActorSpec,
    DeviceSpec,
    DiseaseSpec,
    LocationSpec,
    ObjectiveSpec,
    PatientSpec,
    SceneSpec,
    SimulationSpec,
)
from app.services.map_context_service import describe_map_context
from app.services.openai_client import chat_completion
from app.services.validation_service import ValidationService


class ScenarioIntentAgent:
    """Turns a natural-language request into a validated SimulationSpec.

    Default behavior uses an OpenAI-compatible chat completions API. Tests and
    offline demos can pass provider="template" to use deterministic templates.
    """

    def __init__(
        self,
        provider: Optional[str] = None,
        fallback_provider: Optional[str] = None,
    ):
        self.provider = (provider or settings.intent_provider).lower()
        self.fallback_provider = (fallback_provider or settings.intent_fallback_provider).lower()
        self.template_agent = TemplateScenarioIntentAgent()

    def build_spec(self, text: str, constraints: Dict[str, Any] = None) -> ScenarioIntentResponse:
        constraints = constraints or {}
        if self.provider == "template":
            return self.template_agent.build_spec(text, constraints)
        if self.provider in {"openai", "api"}:
            try:
                return OpenAIScenarioIntentAgent().build_spec(text, constraints)
            except Exception as exc:
                if self.fallback_provider == "template":
                    response = self.template_agent.build_spec(text, constraints)
                    response.assumptions.append(f"真实API调用失败，已回退到本地模板：{exc}")
                    response.simulation_spec.constraints["intent_provider"] = "template_fallback"
                    response.simulation_spec.constraints["api_error"] = str(exc)
                    return response
                raise
        raise ValueError(f"Unsupported EDMAS_INTENT_PROVIDER: {self.provider}")


class OpenAIScenarioIntentAgent:
    def build_spec(self, text: str, constraints: Dict[str, Any] = None) -> ScenarioIntentResponse:
        constraints = constraints or {}
        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY/api_key is not configured")

        result = chat_completion(
            messages=[
                {"role": "system", "content": _system_prompt()},
                {"role": "user", "content": _user_prompt(text, constraints)},
            ],
            temperature=0.2,
            top_p=0.7,
            max_tokens=4096,
            frequency_penalty=1.0,
            response_format={"type": "json_object"},
            extra_body={"top_k": 50},
        )
        content = result["choices"][0]["message"]["content"]
        raw = json.loads(content)
        response = _parse_intent_response(raw)
        response.simulation_spec.constraints["source_intent"] = text
        response.simulation_spec.constraints["intent_provider"] = "openai"
        response.simulation_spec.constraints["intent_model"] = settings.openai_model
        response.simulation_spec.constraints.update(constraints)
        try:
            ValidationService().validate(response.simulation_spec)
        except Exception as exc:
            raise RuntimeError(
                f"LLM 生成的 SimulationSpec 校验失败，请检查 API 返回内容。"
                f" 原始响应 content: {content[:2000]}"
            ) from exc
        return response


class TemplateScenarioIntentAgent:
    def build_spec(self, text: str, constraints: Dict[str, Any] = None) -> ScenarioIntentResponse:
        constraints = constraints or {}
        normalized = text.lower()
        if self._is_trauma(normalized):
            return self._trauma_spec(text, constraints)
        if self._is_stomach(normalized):
            return self._stomach_spec(text, constraints)
        return self._headache_spec(text, constraints)

    def _is_trauma(self, text: str) -> bool:
        return any(token in text for token in ["车祸", "创伤", "外伤", "trauma", "accident", "抢救", "急救"])

    def _is_stomach(self, text: str) -> bool:
        return any(token in text for token in ["胃", "腹痛", "肚子", "反酸", "gastric", "stomach"])

    def _base_locations(self) -> List[LocationSpec]:
        return [
            LocationSpec(id="ED_ENTRANCE", name="急诊入口", position=Position(x=180, y=210)),
            LocationSpec(id="TRIAGE", name="分诊台", position=Position(x=310, y=210)),
            LocationSpec(id="WAITING_AREA", name="候诊区", position=Position(x=430, y=210)),
            LocationSpec(id="DOCTOR", name="医生诊室", position=Position(x=560, y=210)),
            LocationSpec(id="ED_RESUS", name="抢救区", position=Position(x=690, y=210)),
            LocationSpec(id="LAB", name="检验科", position=Position(x=220, y=240)),
            LocationSpec(id="IMAGING", name="影像检查室", position=Position(x=380, y=240)),
            LocationSpec(id="RESULT_REVIEW", name="结果复核区", position=Position(x=700, y=240)),
            LocationSpec(id="DISPOSITION", name="处置/去向讨论区", position=Position(x=220, y=260)),
            LocationSpec(id="ICU", name="ICU", position=Position(x=380, y=260)),
            LocationSpec(id="WARD", name="病房", position=Position(x=540, y=260)),
            LocationSpec(id="DISCHARGE", name="离院/出院", position=Position(x=860, y=260)),
        ]

    def _common_patient_actor(self, name: str = "模拟患者") -> ActorSpec:
        return ActorSpec(
            id="patient_actor_001",
            display_name=name,
            type="patient",
            profession="patient",
            sprite="patient_blue",
            location_id="TRIAGE",
            priority_default=0,
            personality="焦虑但配合",
        )

    def _triage_nurse(self) -> ActorSpec:
        return ActorSpec(
            id="nurse_001",
            display_name="分诊护士",
            type="nurse",
            profession="triage_nurse",
            sprite="nurse_white",
            location_id="TRIAGE",
            priority_default=1,
            personality="严谨、高效、有耐心",
            knowledge=[{"condition": "急诊分诊", "action": "评估风险并安排下一站", "dept": "急诊"}],
            tools=["triage_patient", "request_transfer"],
        )

    def _stomach_spec(self, original_text: str, constraints: Dict[str, Any]) -> ScenarioIntentResponse:
        actors = [
            self._triage_nurse(),
            ActorSpec(
                id="doctor_001",
                display_name="消化科医生",
                type="doctor",
                profession="gastroenterologist",
                sprite="scrubs_green",
                location_id="DOCTOR",
                priority_default=3,
                personality="细致、耐心、重视病史",
                knowledge=[{"condition": "胃炎", "action": "评估饮食、疼痛、反酸并建议检查", "dept": "消化科"}],
                tools=["review_symptoms", "order_exam"],
            ),
            ActorSpec(
                id="lab_nurse_001",
                display_name="检验护士",
                type="nurse",
                profession="lab_nurse",
                sprite="scrubs_blue",
                location_id="LAB",
                priority_default=2,
                personality="准确、流程化",
                knowledge=[{"condition": "血常规", "action": "采样并回传检验报告", "dept": "检验科"}],
                tools=["use_device"],
            ),
            self._common_patient_actor("张三"),
        ]
        spec = SimulationSpec(
            title="胃痛就诊流程演示",
            locale="zh-CN",
            scene=SceneSpec(map_id="edmas", start_time="09:00", locations=self._base_locations()),
            actors=actors,
            patients=[
                PatientSpec(
                    id="patient_001",
                    actor_id="patient_actor_001",
                    name="张三",
                    age=int(constraints.get("age", 36)),
                    sex=str(constraints.get("sex", "male")),
                    chief_complaint="上腹痛3天，饭后加重",
                    symptoms=["反酸", "嗳气", "食欲下降"],
                    vitals={"temperature": 36.8, "heart_rate": 78, "blood_pressure": "122/78", "spo2": 99},
                    medical_history=["长期饮食不规律"],
                    disease_ids=["gastritis_case_001"],
                    risk_level=1,
                )
            ],
            diseases=[
                DiseaseSpec(
                    id="gastritis_case_001",
                    name="疑似胃炎",
                    severity="low",
                    possible_diagnoses=["慢性胃炎", "胃溃疡待排", "功能性消化不良"],
                    recommended_checks=["血常规"],
                    expected_findings=[{"test": "血常规", "result": "未见明显感染征象"}],
                    care_pathway=["分诊", "医生问诊", "检验检查", "结果复核", "用药与饮食建议"],
                )
            ],
            devices=[
                DeviceSpec(id="lab_001", name="检验设备", type="lab_analyzer", location_id="LAB", capabilities=["血常规"], operation_duration=4.0)
            ],
            objectives=[
                ObjectiveSpec(
                    id="obj_001",
                    type="triage",
                    description="完成胃痛病人的分诊、医生问诊和检查建议",
                    success_conditions=["patient_received_triage", "doctor_reviewed_symptoms", "patient_informed"],
                )
            ],
            constraints={"source_intent": original_text, "intent_provider": "template", **constraints},
        )
        return ScenarioIntentResponse(
            scenario_type="stomach_pain",
            confidence=0.86,
            extracted_requirements={"disease": "疑似胃炎", "devices": ["检验设备"], "doctors": 1, "nurses": 2},
            assumptions=["未指定年龄和生命体征，使用低风险稳定生命体征。"],
            simulation_spec=spec,
        )

    def _trauma_spec(self, original_text: str, constraints: Dict[str, Any]) -> ScenarioIntentResponse:
        trauma_doctors = int(constraints.get("doctors", 2))
        actors = [
            self._triage_nurse(),
            ActorSpec(
                id="emergency_nurse_001",
                display_name="急救护士",
                type="nurse",
                profession="emergency_nurse",
                sprite="nurse_blue",
                location_id="ED_RESUS",
                priority_default=4,
                personality="快速、稳定、执行力强",
                knowledge=[{"condition": "创伤抢救", "action": "监测生命体征、建立通路、通知医生", "dept": "急诊"}],
                tools=["monitor_vitals", "request_transfer"],
            ),
            ActorSpec(
                id="doctor_001",
                display_name="急诊医生",
                type="doctor",
                profession="emergency_doctor",
                sprite="scrubs_green",
                location_id="ED_RESUS",
                priority_default=4,
                personality="果断、优先处理危及生命问题",
                knowledge=[{"condition": "车祸外伤", "action": "ABCDE评估、影像检查、会诊手术", "dept": "急诊"}],
                tools=["review_symptoms", "order_exam", "request_surgery"],
            ),
            ActorSpec(
                id="surgeon_001",
                display_name="创伤外科医生",
                type="doctor",
                profession="surgeon",
                sprite="scrubs_blue",
                location_id="DISPOSITION",
                priority_default=4,
                personality="专注、决策快",
                knowledge=[{"condition": "腹部闭合伤", "action": "评估是否手术探查", "dept": "创伤外科"}],
                tools=["surgery_consult", "request_or"],
            ),
            ActorSpec(
                id="imaging_nurse_001",
                display_name="影像护士",
                type="nurse",
                profession="imaging_nurse",
                sprite="nurse_green",
                location_id="IMAGING",
                priority_default=2,
                personality="流程化、注重安全转运",
                knowledge=[{"condition": "CT", "action": "安排影像检查并回传报告", "dept": "影像科"}],
                tools=["use_device"],
            ),
            self._common_patient_actor("车祸患者"),
        ]
        if trauma_doctors > 2:
            actors.append(ActorSpec(id="doctor_002", display_name="麻醉医生", type="doctor", profession="anesthesiologist", sprite="doctor_white", location_id="DISPOSITION", priority_default=3, personality="谨慎、关注气道和麻醉风险", tools=["airway_assessment"]))
        spec = SimulationSpec(
            title="车祸创伤急诊流程演示",
            locale="zh-CN",
            scene=SceneSpec(map_id="edmas", start_time="14:00", locations=self._base_locations()),
            actors=actors,
            patients=[
                PatientSpec(
                    id="patient_001",
                    actor_id="patient_actor_001",
                    name="车祸患者",
                    age=int(constraints.get("age", 42)),
                    sex=str(constraints.get("sex", "male")),
                    chief_complaint="车祸后腹痛、头晕，血压偏低",
                    symptoms=["腹痛", "头晕", "右下肢疼痛"],
                    vitals={"temperature": 36.5, "heart_rate": 118, "blood_pressure": "90/58", "spo2": 94},
                    medical_history=[],
                    disease_ids=["trauma_case_001"],
                    risk_level=4,
                )
            ],
            diseases=[
                DiseaseSpec(
                    id="trauma_case_001",
                    name="车祸多发伤",
                    severity="high",
                    possible_diagnoses=["腹腔内出血待排", "骨折待排", "失血性休克风险"],
                    recommended_checks=["生命体征监测", "CT"],
                    expected_findings=[{"test": "CT", "result": "腹腔少量积液，需创伤外科会诊"}],
                    care_pathway=["急诊入口", "分诊", "抢救区", "影像检查", "结果复核", "创伤外科会诊", "ICU或手术室"],
                )
            ],
            devices=[
                DeviceSpec(id="monitor_001", name="生命体征监护仪", type="ecg_monitor", location_id="ED_RESUS", capabilities=["生命体征监测"], operation_duration=2.0),
                DeviceSpec(id="ct_001", name="CT扫描仪", type="ct_scanner", location_id="IMAGING", capabilities=["CT"], operation_duration=5.0),
                DeviceSpec(id="or_table_001", name="手术床", type="operation_table", location_id="DISPOSITION", capabilities=["手术准备"], operation_duration=6.0),
            ],
            objectives=[
                ObjectiveSpec(
                    id="obj_001",
                    type="emergency",
                    description="完成车祸创伤患者的急诊抢救、检查、资源调度和去向决策",
                    success_conditions=["resus_started", "ct_completed", "surgeon_consulted", "patient_disposition_decided"],
                )
            ],
            constraints={"source_intent": original_text, "requested_doctors": trauma_doctors, "intent_provider": "template", **constraints},
        )
        return ScenarioIntentResponse(
            scenario_type="trauma_rescue",
            confidence=0.9,
            extracted_requirements={"disease": "车祸多发伤", "devices": ["监护仪", "CT", "手术床"], "doctors": trauma_doctors, "nurses": 3},
            assumptions=["未指定资源数量时默认急诊医生1名、创伤外科医生1名、急救护士1名、影像护士1名。"],
            simulation_spec=spec,
        )

    def _headache_spec(self, original_text: str, constraints: Dict[str, Any]) -> ScenarioIntentResponse:
        path = __import__("pathlib").Path(__file__).resolve().parents[1] / "data" / "examples" / "headache_triage.simulation.json"
        spec = model_validate(SimulationSpec, json.loads(path.read_text(encoding="utf-8")))
        spec.constraints["source_intent"] = original_text
        spec.constraints["intent_provider"] = "template"
        spec.constraints.update(constraints)
        return ScenarioIntentResponse(
            scenario_type="headache_triage",
            confidence=0.55,
            extracted_requirements={"disease": "待查头痛", "devices": ["CT"], "doctors": 1, "nurses": 1},
            assumptions=["未识别到明确疾病类型，使用头痛分诊模板作为默认示例。"],
            simulation_spec=spec,
        )


def _system_prompt() -> str:
    schema_data = (
        ScenarioIntentResponse.model_json_schema()
        if hasattr(ScenarioIntentResponse, "model_json_schema")
        else ScenarioIntentResponse.schema()
    )
    schema = json.dumps(schema_data, ensure_ascii=False)
    return (
        "你是 EDMAS 医院急诊仿真系统的场景意图解析 agent。"
        "你必须把用户的自然语言需求转换成严格 JSON。不要输出 Markdown。"
        "输出必须符合 ScenarioIntentResponse schema，其中 simulation_spec 必须符合 SimulationSpec。"
        "只能使用这些 actor.type: doctor, nurse, patient, technician。"
        "只能使用这些 sprite: doctor_white, nurse_white, nurse_blue, nurse_green, scrubs_green, scrubs_blue, patient_blue, patient_green。"
        "只能使用这些 device.type: ct_scanner, lab_analyzer, ecg_monitor, operation_table, medicine_cart。"
        "所有 actor.location_id、device.location_id 和 patient actor 初始位置必须来自地图房间 id。"
        "必须给每个患者创建对应 patient actor，patients[].actor_id 要指向该 actor。"
        "如果用户提到设备、医生数量、护士数量、资源调度，要体现在 actors/devices/objectives/constraints 中。"
        "如果信息缺失，可以合理假设，但要写入 assumptions。"
        "地图上下文如下：\n"
        f"{describe_map_context()}\n"
        "JSON schema 如下：\n"
        f"{schema}"
    )


def _user_prompt(text: str, constraints: Dict[str, Any]) -> str:
    return json.dumps(
        {
            "user_scene_request": text,
            "constraints": constraints,
            "output_contract": "Return only valid JSON for ScenarioIntentResponse.",
        },
        ensure_ascii=False,
    )


def _parse_intent_response(raw: Dict[str, Any]) -> ScenarioIntentResponse:
    if "simulation_spec" not in raw:
        if "spec" in raw:
            raw["simulation_spec"] = raw.pop("spec")
        elif "title" in raw and "scene" in raw:
            raw = {
                "scenario_type": raw.get("scenario_type", "custom"),
                "confidence": raw.get("confidence", 0.75),
                "extracted_requirements": raw.get("extracted_requirements", {}),
                "assumptions": raw.get("assumptions", []),
                "simulation_spec": raw,
            }
    response = model_validate(ScenarioIntentResponse, raw)
    return response


