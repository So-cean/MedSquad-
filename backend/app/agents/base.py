from abc import ABC, abstractmethod

from app.schemas.plan import ActionPlan, AgentStepRequest, AgentStepResult
from app.schemas.simulation import SimulationSpec, WorldState


class BaseAgent(ABC):
    @abstractmethod
    def generate_plan(self, spec: SimulationSpec, world_state: WorldState) -> ActionPlan:
        raise NotImplementedError

    @abstractmethod
    def step(self, request: AgentStepRequest, spec: SimulationSpec, world_state: WorldState) -> AgentStepResult:
        raise NotImplementedError
