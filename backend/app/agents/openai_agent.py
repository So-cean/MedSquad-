import json
from typing import Any, Dict

from app.agents.base import BaseAgent
from app.config import settings
from app.schemas.compat import model_to_dict, model_validate
from app.schemas.plan import ActionPlan, AgentStepRequest, AgentStepResult
from app.schemas.simulation import SimulationSpec, WorldState
from app.services.agent_context_service import AgentContextService
from app.services.map_context_service import describe_map_context
from app.services.openai_client import chat_completion


class OpenAIAgent(BaseAgent):
    """API-backed planner for staff behavior, movement, and dialogue."""

    def generate_plan(self, spec: SimulationSpec, world_state: WorldState) -> ActionPlan:
        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY/api_key is not configured")

        result = chat_completion(
            messages=[
                {"role": "system", "content": _plan_system_prompt()},
                {"role": "user", "content": _plan_user_prompt(spec, world_state)},
            ],
            temperature=0.35,
            top_p=0.7,
            max_tokens=4096,
            frequency_penalty=1.0,
            response_format={"type": "json_object"},
            extra_body={"top_k": 50},
        )
        raw = json.loads(result["choices"][0]["message"]["content"])
        plan = _parse_action_plan(raw, world_state.simulation_id)
        _validate_plan_references(plan, spec)
        return plan

    def step(self, request: AgentStepRequest, spec: SimulationSpec, world_state: WorldState) -> AgentStepResult:
        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY/api_key is not configured")

        result = chat_completion(
            messages=[
                {"role": "system", "content": _step_system_prompt()},
                {"role": "user", "content": _step_user_prompt(request, spec, world_state)},
            ],
            temperature=0.45,
            top_p=0.7,
            max_tokens=4096,
            frequency_penalty=1.0,
            response_format={"type": "json_object"},
            extra_body={"top_k": 50},
        )
        raw = json.loads(result["choices"][0]["message"]["content"])
        return model_validate(AgentStepResult, raw)


def _plan_system_prompt() -> str:
    schema_data = ActionPlan.model_json_schema() if hasattr(ActionPlan, "model_json_schema") else ActionPlan.schema()
    return (
        "你是 EDMAS 医院仿真系统的多智能体流程导演。"
        "你要根据结构化病例 JSON，为医生、护士、患者和设备生成可播放的 ActionPlan。"
        "必须只输出 JSON，不要 Markdown。"
        "所有 step.actor_id、target_actor_id、location_id、device_id 必须来自输入 JSON。"
        "医生、护士的行为、think 和 dialogue 都必须由你根据角色职责、地图和病例生成。"
        "流程必须包含必要的 move_to、speak、use_device，并以 end_simulation 结束。"
        "不要生成 schema 外的 step.type。"
        "duration 使用 1 到 6 秒之间的合理数值。"
        "如果用户场景涉及资源调度，要让相应医生/护士明确说出调度理由。"
        "地图上下文如下：\n"
        f"{describe_map_context()}\n"
        "ActionPlan JSON schema 如下：\n"
        f"{json.dumps(schema_data, ensure_ascii=False)}"
    )


def _plan_user_prompt(spec: SimulationSpec, world_state: WorldState) -> str:
    prompts = AgentContextService().build_system_prompts(spec)
    return json.dumps(
        {
            "simulation_id": world_state.simulation_id,
            "simulation_spec": model_to_dict(spec),
            "world_state": model_to_dict(world_state),
            "agent_system_prompts": prompts,
            "output_contract": "Return only valid JSON matching ActionPlan.",
        },
        ensure_ascii=False,
    )


def _step_system_prompt() -> str:
    schema_data = AgentStepResult.model_json_schema() if hasattr(AgentStepResult, "model_json_schema") else AgentStepResult.schema()
    return (
        "你是 EDMAS 医院仿真系统中的单个角色即时行动 agent。"
        "根据当前角色、目标角色、意图和上下文，生成下一步动作与对白。"
        "必须只输出 JSON，不要 Markdown。"
        "输出必须符合 AgentStepResult schema。"
        f"{json.dumps(schema_data, ensure_ascii=False)}"
    )


def _step_user_prompt(request: AgentStepRequest, spec: SimulationSpec, world_state: WorldState) -> str:
    return json.dumps(
        {
            "request": model_to_dict(request),
            "simulation_spec": model_to_dict(spec),
            "world_state": model_to_dict(world_state),
            "agent_system_prompts": AgentContextService().build_system_prompts(spec),
        },
        ensure_ascii=False,
    )


def _parse_action_plan(raw: Dict[str, Any], simulation_id: str) -> ActionPlan:
    if "steps" not in raw and "action_plan" in raw:
        raw = raw["action_plan"]
    raw.setdefault("simulation_id", simulation_id)
    raw.setdefault("plan_id", "plan_llm_001")
    plan = model_validate(ActionPlan, raw)
    if plan.simulation_id != simulation_id:
        plan.simulation_id = simulation_id
    return plan


def _validate_plan_references(plan: ActionPlan, spec: SimulationSpec) -> None:
    actor_ids = {actor.id for actor in spec.actors}
    location_ids = {location.id for location in spec.scene.locations}
    device_ids = {device.id for device in spec.devices}

    for step in plan.steps:
        if step.actor_id and step.actor_id not in actor_ids:
            raise ValueError(f"LLM plan step {step.id} references unknown actor_id: {step.actor_id}")
        if step.target_actor_id and step.target_actor_id not in actor_ids:
            raise ValueError(f"LLM plan step {step.id} references unknown target_actor_id: {step.target_actor_id}")
        if step.location_id and step.location_id not in location_ids:
            raise ValueError(f"LLM plan step {step.id} references unknown location_id: {step.location_id}")
        if step.device_id and step.device_id not in device_ids:
            raise ValueError(f"LLM plan step {step.id} references unknown device_id: {step.device_id}")
