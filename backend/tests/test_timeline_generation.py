import json
from pathlib import Path

from app.agents.mock_agent import MockAgent
from app.schemas.compat import model_validate
from app.schemas.simulation import SimulationSpec
from app.services.timeline_service import TimelineService
from app.services.world_state_service import WorldStateService


EXAMPLE = Path(__file__).resolve().parents[1] / "app" / "data" / "examples" / "headache_triage.simulation.json"


def test_timeline_contains_p0_action_set():
    spec = model_validate(SimulationSpec, json.loads(EXAMPLE.read_text(encoding="utf-8")))
    world_state = WorldStateService().create_initial_state("sim_test", spec)
    plan = MockAgent().generate_plan(spec, world_state)
    timeline = TimelineService().build_timeline(plan, spec, world_state)
    types = [action.type for action in timeline.actions]
    times = [action.time for action in timeline.actions]

    assert "move_to" in types
    assert types.count("speak") >= 2
    assert "use_device" in types
    assert types[-1] == "end_simulation"
    assert times == sorted(times)
    assert all(action.id.startswith("act_") for action in timeline.actions)
