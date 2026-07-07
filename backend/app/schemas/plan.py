from typing import Any, Dict, List, Literal, Optional
from pydantic import BaseModel, Field


PlanStepType = Literal["spawn_actor", "move_to", "face_actor", "speak", "wait", "use_device", "set_state", "end_simulation"]


class PlanStep(BaseModel):
    id: str
    actor_id: Optional[str] = None
    type: PlanStepType
    target_actor_id: Optional[str] = None
    location_id: Optional[str] = None
    device_id: Optional[str] = None
    think: str = ""
    dialogue: str = ""
    priority: int = 1
    duration: float = 1.0
    payload: Dict[str, Any] = Field(default_factory=dict)


class ActionPlan(BaseModel):
    simulation_id: str
    plan_id: str
    steps: List[PlanStep] = Field(default_factory=list)


class AgentStepRequest(BaseModel):
    actor_id: str
    target_actor_id: Optional[str] = None
    intent: str
    context: Dict[str, Any] = Field(default_factory=dict)


class AgentStepResult(BaseModel):
    actions: List[PlanStep] = Field(default_factory=list)
    think: str = ""
    dialogue: str = ""
    state_patch: Dict[str, Any] = Field(default_factory=dict)
