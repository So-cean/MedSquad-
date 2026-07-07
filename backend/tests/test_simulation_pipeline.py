import json
from pathlib import Path

from app.schemas.compat import model_validate
from app.schemas.plan import AgentStepRequest
from app.schemas.simulation import SimulationSpec
from app.services.agent_service import AgentService
from app.services.simulation_service import SimulationService
from app.storage.file_store import FileStore


EXAMPLE = Path(__file__).resolve().parents[1] / "app" / "data" / "examples" / "headache_triage.simulation.json"


def test_simulation_service_e2e(tmp_path):
    service = SimulationService(store=FileStore(tmp_path), agent_service=AgentService("mock"))
    spec = model_validate(SimulationSpec, json.loads(EXAMPLE.read_text(encoding="utf-8")))

    created = service.create(spec, simulation_id="sim_test")
    plan = service.generate_plan(created.simulation_id)
    timeline = service.get_or_create_timeline(created.simulation_id)
    step = service.agent_step(created.simulation_id, AgentStepRequest(
        actor_id="nurse_001",
        target_actor_id="patient_actor_001",
        intent="triage_patient",
    ))

    assert created.simulation_id == "sim_test"
    assert len(plan.steps) >= 5
    assert len(timeline.actions) >= 5
    assert step.think
    assert service.get_world_state("sim_test").status == "created"
