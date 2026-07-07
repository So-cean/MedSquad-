import json
from pathlib import Path

from app.schemas.compat import model_validate
from app.schemas.simulation import SimulationSpec
from app.services.agent_context_service import AgentContextService
from app.services.map_context_service import describe_map_context


EXAMPLE = Path(__file__).resolve().parents[1] / "app" / "data" / "examples" / "stomach_pain.simulation.json"


def test_map_context_contains_rooms_and_bounds():
    text = describe_map_context()
    assert "TRIAGE" in text
    assert "LAB" in text
    assert "bounds=" in text


def test_agent_prompts_include_role_and_map_constraints():
    spec = model_validate(SimulationSpec, json.loads(EXAMPLE.read_text(encoding="utf-8")))
    prompts = AgentContextService().build_system_prompts(spec)
    doctor_prompt = prompts["doctor_001"]
    nurse_prompt = prompts["nurse_001"]

    assert "消化科医生" in doctor_prompt
    assert "胃病相关病史采集" in doctor_prompt
    assert "DOCTOR" in doctor_prompt
    assert "TRIAGE" in nurse_prompt
    assert "move_to 的 location_id 必须来自上面的区域 ID" in doctor_prompt
