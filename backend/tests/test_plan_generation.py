import json
from pathlib import Path

from app.agents.mock_agent import MockAgent
from app.schemas.compat import model_to_dict, model_validate
from app.schemas.simulation import SimulationSpec
from app.services.world_state_service import WorldStateService


EXAMPLE = Path(__file__).resolve().parents[1] / "app" / "data" / "examples" / "headache_triage.simulation.json"


def test_mock_agent_generates_stable_p0_plan():
    spec = model_validate(SimulationSpec, json.loads(EXAMPLE.read_text(encoding="utf-8")))
    world_state = WorldStateService().create_initial_state("sim_test", spec)
    plan_a = MockAgent().generate_plan(spec, world_state)
    plan_b = MockAgent().generate_plan(spec, world_state)

    assert len(plan_a.steps) >= 5
    assert len([step for step in plan_a.steps if step.type == "speak"]) >= 2
    assert any(step.type == "use_device" for step in plan_a.steps)
    assert model_to_dict(plan_a) == model_to_dict(plan_b)
