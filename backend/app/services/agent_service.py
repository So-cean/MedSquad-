from app.agents.mock_agent import MockAgent
from app.agents.openai_agent import OpenAIAgent
from app.schemas.plan import ActionPlan, AgentStepRequest, AgentStepResult
from app.schemas.simulation import SimulationSpec, WorldState


class AgentService:
    def __init__(self, provider: str = "mock"):
        self.provider = provider

    def _agent(self):
        if self.provider == "openai":
            return OpenAIAgent()
        return MockAgent()

    def generate_plan(self, spec: SimulationSpec, world_state: WorldState) -> ActionPlan:
        return self._agent().generate_plan(spec, world_state)

    def step(self, request: AgentStepRequest, spec: SimulationSpec, world_state: WorldState) -> AgentStepResult:
        return self._agent().step(request, spec, world_state)
