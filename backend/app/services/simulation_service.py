import json
from pathlib import Path
from typing import Optional
from uuid import uuid4

from app.config import settings
from app.schemas.compat import model_to_dict, model_validate
from app.schemas.plan import ActionPlan, AgentStepRequest, AgentStepResult
from app.schemas.simulation import CreateSimulationResponse, SimulationSpec, WorldState
from app.schemas.timeline import DemoTimeline
from app.services.agent_service import AgentService
from app.services.timeline_service import TimelineService
from app.services.validation_service import ValidationService
from app.services.world_state_service import WorldStateService
from app.storage.file_store import FileStore


class SimulationNotFound(Exception):
    pass


class SimulationService:
    def __init__(
        self,
        store: Optional[FileStore] = None,
        agent_service: Optional[AgentService] = None,
        timeline_service: Optional[TimelineService] = None,
    ):
        self.store = store or FileStore(settings.runtime_dir)
        self.validation = ValidationService()
        self.world_state_service = WorldStateService()
        self.agent_service = agent_service or AgentService(settings.agent_provider)
        self.timeline_service = timeline_service or TimelineService()

    def create(self, spec: SimulationSpec, simulation_id: Optional[str] = None) -> CreateSimulationResponse:
        warnings = self.validation.validate(spec)
        sim_id = simulation_id or self._new_id()
        world_state = self.world_state_service.create_initial_state(sim_id, spec)
        self.store.create_session(sim_id)
        self.store.write_json(sim_id, "input.json", spec)
        self.store.write_json(sim_id, "world_state.json", world_state)
        self.store.write_json(sim_id, "warnings.json", warnings)
        return CreateSimulationResponse(
            simulation_id=sim_id,
            status=world_state.status,
            world_state=world_state,
            warnings=warnings,
        )

    def generate_plan(self, simulation_id: str) -> ActionPlan:
        spec = self.get_spec(simulation_id)
        world_state = self.get_world_state(simulation_id)
        plan = self.agent_service.generate_plan(spec, world_state)
        self.store.write_json(simulation_id, "plan.json", plan)
        return plan

    def get_or_create_timeline(self, simulation_id: str, copy_to_godot: bool = False) -> DemoTimeline:
        if self.store.exists(simulation_id, "timeline.json"):
            return model_validate(DemoTimeline, self.store.read_json(simulation_id, "timeline.json"))

        plan = self.get_plan(simulation_id) if self.store.exists(simulation_id, "plan.json") else self.generate_plan(simulation_id)
        spec = self.get_spec(simulation_id)
        world_state = self.get_world_state(simulation_id)
        timeline = self.timeline_service.build_timeline(plan, spec, world_state)
        self.store.write_json(simulation_id, "timeline.json", timeline)

        if copy_to_godot:
            self.copy_timeline_to_godot(timeline, settings.godot_timeline_output)

        return timeline

    def copy_timeline_to_godot(self, timeline: DemoTimeline, output_path: Path) -> None:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(model_to_dict(timeline), ensure_ascii=False, indent=2), encoding="utf-8")

    def agent_step(self, simulation_id: str, request: AgentStepRequest) -> AgentStepResult:
        return self.agent_service.step(request, self.get_spec(simulation_id), self.get_world_state(simulation_id))

    def get_spec(self, simulation_id: str) -> SimulationSpec:
        self._ensure_session(simulation_id)
        return model_validate(SimulationSpec, self.store.read_json(simulation_id, "input.json"))

    def get_world_state(self, simulation_id: str) -> WorldState:
        self._ensure_session(simulation_id)
        return model_validate(WorldState, self.store.read_json(simulation_id, "world_state.json"))

    def get_plan(self, simulation_id: str) -> ActionPlan:
        self._ensure_session(simulation_id)
        return model_validate(ActionPlan, self.store.read_json(simulation_id, "plan.json"))

    def _ensure_session(self, simulation_id: str) -> None:
        if not self.store.exists(simulation_id):
            raise SimulationNotFound(simulation_id)

    def _new_id(self) -> str:
        return f"sim_{uuid4().hex[:12]}"
