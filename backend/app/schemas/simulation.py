from typing import Any, Dict, List, Literal, Optional
from pydantic import BaseModel, Field

from .common import Position, ValidationWarning


ActorType = Literal["doctor", "nurse", "patient", "technician"]
SpriteId = Literal[
    "doctor_white",
    "nurse_white",
    "nurse_blue",
    "nurse_green",
    "scrubs_green",
    "scrubs_blue",
    "patient_blue",
    "patient_green",
]
DeviceType = Literal["ct_scanner", "lab_analyzer", "ecg_monitor", "operation_table", "medicine_cart"]


class LocationSpec(BaseModel):
    id: str
    name: str
    position: Position


class SceneSpec(BaseModel):
    map_id: str = "room1"
    start_time: str = "08:00"
    locations: List[LocationSpec] = Field(default_factory=list)


class ActorSpec(BaseModel):
    id: str
    display_name: str
    type: ActorType
    profession: str
    sprite: SpriteId
    location_id: str
    priority_default: int = 1
    personality: str = ""
    knowledge: List[Dict[str, Any]] = Field(default_factory=list)
    tools: List[str] = Field(default_factory=list)
    memory: List[Dict[str, Any]] = Field(default_factory=list)


class PatientSpec(BaseModel):
    id: str
    actor_id: str
    name: str
    age: int
    sex: str
    chief_complaint: str
    symptoms: List[str] = Field(default_factory=list)
    vitals: Dict[str, Any] = Field(default_factory=dict)
    allergies: List[str] = Field(default_factory=list)
    medical_history: List[str] = Field(default_factory=list)
    disease_ids: List[str] = Field(default_factory=list)
    risk_level: int = 1


class DiseaseSpec(BaseModel):
    id: str
    name: str
    severity: str = "medium"
    possible_diagnoses: List[str] = Field(default_factory=list)
    recommended_checks: List[str] = Field(default_factory=list)
    expected_findings: List[Dict[str, Any]] = Field(default_factory=list)
    care_pathway: List[str] = Field(default_factory=list)


class DeviceSpec(BaseModel):
    id: str
    name: str
    type: DeviceType
    location_id: str
    status: str = "idle"
    capabilities: List[str] = Field(default_factory=list)
    operation_duration: float = 5.0
    outputs: List[Dict[str, Any]] = Field(default_factory=list)


class ObjectiveSpec(BaseModel):
    id: str
    type: str
    description: str
    success_conditions: List[str] = Field(default_factory=list)


class SimulationSpec(BaseModel):
    title: str
    locale: str = "zh-CN"
    scene: SceneSpec
    actors: List[ActorSpec] = Field(default_factory=list)
    patients: List[PatientSpec] = Field(default_factory=list)
    diseases: List[DiseaseSpec] = Field(default_factory=list)
    devices: List[DeviceSpec] = Field(default_factory=list)
    objectives: List[ObjectiveSpec] = Field(default_factory=list)
    constraints: Dict[str, Any] = Field(default_factory=dict)


class WorldState(BaseModel):
    simulation_id: str
    status: str = "created"
    time: str
    actors: Dict[str, Dict[str, Any]] = Field(default_factory=dict)
    patients: Dict[str, Dict[str, Any]] = Field(default_factory=dict)
    diseases: Dict[str, Dict[str, Any]] = Field(default_factory=dict)
    devices: Dict[str, Dict[str, Any]] = Field(default_factory=dict)
    locations: Dict[str, Dict[str, Any]] = Field(default_factory=dict)
    objectives: Dict[str, Dict[str, Any]] = Field(default_factory=dict)
    completed_objectives: List[str] = Field(default_factory=list)
    events: List[Dict[str, Any]] = Field(default_factory=list)


class CreateSimulationResponse(BaseModel):
    simulation_id: str
    status: str
    world_state: WorldState
    warnings: List[ValidationWarning] = Field(default_factory=list)
