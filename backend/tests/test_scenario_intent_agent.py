import json

from app.agents.mock_agent import MockAgent
from app.agents.scenario_intent_agent import ScenarioIntentAgent, TemplateScenarioIntentAgent
from app.schemas.compat import model_to_dict
from app.services.validation_service import ValidationService
from app.services.world_state_service import WorldStateService


def test_trauma_intent_generates_resource_rich_spec_and_plan():
    response = ScenarioIntentAgent(provider="template").build_spec(
        "我想试一下，现在如果有一个病人车祸了，会有一套怎样的急诊流程？需要模拟设备和医生资源调度。",
        {"doctors": 3},
    )
    spec = response.simulation_spec
    ValidationService().validate(spec)

    assert response.scenario_type == "trauma_rescue"
    assert response.extracted_requirements["doctors"] == 3
    assert {device.type for device in spec.devices} >= {"ecg_monitor", "ct_scanner", "operation_table"}
    assert len([actor for actor in spec.actors if actor.type == "doctor"]) >= 3
    assert any(actor.profession == "emergency_nurse" for actor in spec.actors)

    world_state = WorldStateService().create_initial_state("sim_trauma", spec)
    plan = MockAgent().generate_plan(spec, world_state)
    types = [step.type for step in plan.steps]
    locations = [step.location_id for step in plan.steps if step.location_id]

    assert "use_device" in types
    assert "ED_RESUS" in locations
    assert "IMAGING" in locations
    assert "DISPOSITION" in locations


def test_stomach_intent_generates_gastroenterology_spec():
    response = ScenarioIntentAgent(provider="template").build_spec("模拟一个胃痛病人看病")
    spec = response.simulation_spec
    ValidationService().validate(spec)

    assert response.scenario_type == "stomach_pain"
    assert any(actor.profession == "gastroenterologist" for actor in spec.actors)
    assert any(device.type == "lab_analyzer" for device in spec.devices)


def test_openai_intent_provider_uses_api_response(monkeypatch):
    template_response = TemplateScenarioIntentAgent().build_spec("模拟一个胃痛病人看病")
    calls = []

    def fake_chat_completion(*, messages, model=None, temperature=0.2, top_p=0.7,
                             max_tokens=4096, frequency_penalty=1.0,
                             response_format=None, extra_body=None, stream=False):
        calls.append({
            "messages": messages, "model": model, "temperature": temperature,
            "response_format": response_format, "extra_body": extra_body,
        })
        return {
            "choices": [
                {
                    "message": {
                        "content": json.dumps(model_to_dict(template_response), ensure_ascii=False)
                    }
                }
            ]
        }

    monkeypatch.setattr("app.agents.scenario_intent_agent.settings.openai_api_key", "test-key")
    monkeypatch.setattr("app.agents.scenario_intent_agent.settings.openai_base_url", "https://example.test/v1")
    monkeypatch.setattr("app.agents.scenario_intent_agent.settings.openai_model", "test-model")
    monkeypatch.setattr("app.agents.scenario_intent_agent.chat_completion", fake_chat_completion)

    response = ScenarioIntentAgent(provider="openai", fallback_provider="none").build_spec("模拟一个胃痛病人看病")

    assert response.scenario_type == "stomach_pain"
    assert calls
    assert calls[0]["response_format"] == {"type": "json_object"}
    assert calls[0]["extra_body"] == {"top_k": 50}
    assert response.simulation_spec.constraints["intent_provider"] == "openai"
