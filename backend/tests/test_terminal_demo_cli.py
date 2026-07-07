from types import SimpleNamespace

from app.agents.scenario_intent_agent import ScenarioIntentAgent
from app.cli.terminal_demo import resolve_spec


def _args(**overrides):
    values = {
        "spec": "",
        "case": "",
        "intent": None,
        "save_generated_spec": "",
    }
    values.update(overrides)
    return SimpleNamespace(**values)


def _template_agent():
    return ScenarioIntentAgent(provider="template")


def test_resolve_spec_prompts_for_intent_when_no_json_or_case():
    prompts = []

    spec, intent = resolve_spec(
        _args(),
        input_func=lambda prompt: prompts.append(prompt) or "车祸急诊流程，需要设备和医生资源调度",
        agent_factory=_template_agent,
    )

    assert prompts == ["请输入场景："]
    assert intent.scenario_type == "trauma_rescue"
    assert spec.title


def test_resolve_spec_loads_json_without_prompt():
    def fail_input(prompt):
        raise AssertionError(f"unexpected prompt: {prompt}")

    spec, intent = resolve_spec(
        _args(spec="app/data/examples/stomach_pain.simulation.json"),
        input_func=fail_input,
        agent_factory=_template_agent,
    )

    assert intent is None
    assert spec.patients[0].chief_complaint
