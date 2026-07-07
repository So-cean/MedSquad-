from typing import Any, Dict, List
from pydantic import BaseModel, Field

from app.schemas.simulation import SimulationSpec


class ScenarioIntentRequest(BaseModel):
    text: str
    constraints: Dict[str, Any] = Field(default_factory=dict)


class ScenarioIntentResponse(BaseModel):
    scenario_type: str
    confidence: float
    extracted_requirements: Dict[str, Any] = Field(default_factory=dict)
    assumptions: List[str] = Field(default_factory=list)
    simulation_spec: SimulationSpec
