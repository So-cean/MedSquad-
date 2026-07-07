from typing import Dict

from app.schemas.simulation import ActorSpec, SimulationSpec
from app.services.map_context_service import describe_map_context, get_location_map, get_role_responsibilities


class AgentContextService:
    def build_system_prompts(self, spec: SimulationSpec) -> Dict[str, str]:
        return {actor.id: self.build_system_prompt(actor, spec) for actor in spec.actors}

    def build_system_prompt(self, actor: ActorSpec, spec: SimulationSpec) -> str:
        responsibilities = get_role_responsibilities(actor.profession, actor.type)
        location_map = get_location_map(actor.location_id)
        knowledge_lines = [
            f"- condition={item.get('condition', '')}; action={item.get('action', '')}; dept={item.get('dept', '')}"
            for item in actor.knowledge
        ]
        objective_lines = [f"- {objective.description}" for objective in spec.objectives]

        return "\n".join([
            f"你是 {actor.display_name}，角色类型={actor.type}，岗位={actor.profession}。",
            f"当前初始位置={actor.location_id}，所在地图={location_map}。",
            f"性格/沟通风格={actor.personality or '专业、清晰、简洁'}。",
            "你的职责边界:",
            *(f"- {line}" for line in responsibilities),
            "你掌握的知识:",
            *(knowledge_lines or ["- 无额外知识库，按职责和病例上下文行动。"]),
            "本次模拟目标:",
            *(objective_lines or ["- 完成安全、连贯、可解释的就诊流程。"]),
            describe_map_context(),
            "行动约束:",
            "- 每次行动必须输出标准动作: speak, move_to, use_device, wait, set_state, end_simulation。",
            "- move_to 的 location_id 必须来自上面的区域 ID。",
            "- 医护人员要明确分工，不要越权诊断或执行不属于自己的操作。",
            "- 对患者输出应简洁、可理解，并说明下一步位置或检查。",
        ])
