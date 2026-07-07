import json
from pathlib import Path

from app.agents.openai_agent import OpenAIAgent
from app.schemas.compat import model_to_dict, model_validate
from app.schemas.plan import ActionPlan, AgentStepResult, PlanStep
from app.schemas.simulation import SimulationSpec
from app.services.world_state_service import WorldStateService


EXAMPLE = Path(__file__).resolve().parents[1] / "app" / "data" / "examples" / "stomach_pain.simulation.json"


def test_openai_agent_generates_plan_from_api_response(monkeypatch):
    spec = model_validate(SimulationSpec, json.loads(EXAMPLE.read_text(encoding="utf-8")))
    world_state = WorldStateService().create_initial_state("sim_llm", spec)
    expected = ActionPlan(
        simulation_id="sim_llm",
        plan_id="plan_llm_test",
        steps=[
            PlanStep(id="step_001", type="speak", actor_id="nurse_001", target_actor_id="patient_actor_001", think="先分诊", dialogue="您好，我先了解一下症状。", duration=2.0),
            PlanStep(id="step_002", type="end_simulation", payload={"status": "completed"}, duration=0.0),
        ],
    )
    calls = []

    def fake_chat_completion(*, messages, model=None, temperature=0.2, top_p=0.7,
                             max_tokens=4096, frequency_penalty=1.0,
                             response_format=None, extra_body=None, stream=False):
        calls.append({
            "messages": messages, "model": model, "temperature": temperature,
            "response_format": response_format, "extra_body": extra_body,
        })
        return {"choices": [{"message": {"content": json.dumps(model_to_dict(expected), ensure_ascii=False)}}]}

    monkeypatch.setattr("app.agents.openai_agent.settings.openai_api_key", "test-key")
    monkeypatch.setattr("app.agents.openai_agent.settings.openai_base_url", "https://example.test/v1")
    monkeypatch.setattr("app.agents.openai_agent.settings.openai_model", "test-model")
    monkeypatch.setattr("app.agents.openai_agent.chat_completion", fake_chat_completion)

    plan = OpenAIAgent().generate_plan(spec, world_state)

    assert plan.plan_id == "plan_llm_test"
    assert plan.steps[0].dialogue == "您好，我先了解一下症状。"
    assert calls
    # model is resolved inside chat_completion from settings, so the fake
    # receives None (the default) when the caller doesn't pass it explicitly.
    assert "agent_system_prompts" in calls[0]["messages"][1]["content"]


def test_openai_agent_step_uses_api_response(monkeypatch):
    spec = model_validate(SimulationSpec, json.loads(EXAMPLE.read_text(encoding="utf-8")))
    world_state = WorldStateService().create_initial_state("sim_step", spec)
    expected = AgentStepResult(
        think="需要解释检查安排",
        dialogue="请先去检验科，我们会尽快查看结果。",
        actions=[
            PlanStep(id="agent_step_001", type="speak", actor_id="doctor_001", target_actor_id="patient_actor_001", dialogue="请先去检验科，我们会尽快查看结果。")
        ],
    )

    def fake_chat_completion(*, messages, model=None, temperature=0.2, top_p=0.7,
                             max_tokens=4096, frequency_penalty=1.0,
                             response_format=None, extra_body=None, stream=False):
        return {"choices": [{"message": {"content": json.dumps(model_to_dict(expected), ensure_ascii=False)}}]}

    monkeypatch.setattr("app.agents.openai_agent.settings.openai_api_key", "test-key")
    monkeypatch.setattr("app.agents.openai_agent.chat_completion", fake_chat_completion)

    result = OpenAIAgent().step(
        __import__("app.schemas.plan", fromlist=["AgentStepRequest"]).AgentStepRequest(
            actor_id="doctor_001",
            target_actor_id="patient_actor_001",
            intent="explain_exam",
        ),
        spec,
        world_state,
    )

    assert result.think
    assert result.dialogue == "请先去检验科，我们会尽快查看结果。"