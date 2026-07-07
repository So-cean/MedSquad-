import argparse
import json
from pathlib import Path
from typing import Callable, Dict, Optional, Tuple

from app.agents.scenario_intent_agent import ScenarioIntentAgent
from app.schemas.compat import model_to_dict, model_validate
from app.schemas.simulation import SimulationSpec
from app.services.agent_context_service import AgentContextService
from app.services.simulation_service import SimulationService
from app.storage.file_store import FileStore


EXAMPLE_DIR = Path(__file__).resolve().parents[1] / "data" / "examples"


def main() -> None:
    parser = argparse.ArgumentParser(description="Run an EDMAS simulation in the terminal.")
    parser.add_argument(
        "--case",
        default="",
        choices=["stomach", "headache"],
        help="Built-in case to run.",
    )
    parser.add_argument(
        "--spec",
        default="",
        help="Path to a custom SimulationSpec JSON file.",
    )
    parser.add_argument(
        "--intent",
        nargs="?",
        const="",
        default=None,
        help="Natural-language scenario request. Example: 我想模拟一个病人车祸后的急诊流程",
    )
    parser.add_argument(
        "--save-generated-spec",
        default="",
        help="Optional path to save the JSON generated from --intent.",
    )
    parser.add_argument(
        "--show-prompts",
        action="store_true",
        help="Print full per-agent system prompts before the demo.",
    )
    args = parser.parse_args()

    spec, intent_response = resolve_spec(args, input)

    service = SimulationService(store=FileStore(Path("runtime")))
    created = service.create(spec)
    plan = service.generate_plan(created.simulation_id)
    timeline = service.get_or_create_timeline(created.simulation_id)

    prompts = AgentContextService().build_system_prompts(spec)
    actor_names = {actor.id: actor.display_name for actor in spec.actors}
    actor_locations = {actor.id: actor.location_id for actor in spec.actors}
    device_names = {device.id: device.name for device in spec.devices}

    print("=" * 72)
    print(f"EDMAS Terminal Demo: {spec.title}")
    print(f"simulation_id: {created.simulation_id}")
    if intent_response:
        print(f"intent_type: {intent_response.scenario_type} confidence={intent_response.confidence}")
        print(f"extracted_requirements: {intent_response.extracted_requirements}")
        if intent_response.assumptions:
            print("assumptions:")
            for item in intent_response.assumptions:
                print(f"- {item}")
    print("=" * 72)
    print("\n角色分工:")
    for actor in spec.actors:
        print(f"- {actor.display_name} [{actor.id}] type={actor.type}, profession={actor.profession}, start={actor.location_id}")
    print("\nAgent system prompt 输入:")
    for actor_id, prompt in prompts.items():
        if args.show_prompts:
            print("\n" + "-" * 72)
            print(prompt)
        else:
            first_lines = "\n".join(prompt.splitlines()[:8])
            print("\n" + "-" * 72)
            print(first_lines)
            print("... 使用 --show-prompts 查看完整地图、房间范围和职责约束")

    print("\n" + "=" * 72)
    print("流程演示:")
    print("=" * 72)
    _print_timeline(timeline.actions, actor_names, actor_locations, device_names)
    print("\n演示结束。")


def resolve_spec(
    args,
    input_func: Callable[[str], str] = input,
    agent_factory: Callable[[], ScenarioIntentAgent] = ScenarioIntentAgent,
) -> Tuple[SimulationSpec, Optional[object]]:
    if args.spec:
        spec_path = Path(args.spec)
        return model_validate(SimulationSpec, json.loads(spec_path.read_text(encoding="utf-8"))), None

    if args.case:
        spec_path = _case_path(args.case)
        return model_validate(SimulationSpec, json.loads(spec_path.read_text(encoding="utf-8"))), None

    intent_text = args.intent
    if intent_text is None or not intent_text.strip():
        intent_text = input_func("请输入场景：").strip()
    if not intent_text:
        raise SystemExit("未输入场景。请重新运行并输入自然语言场景，或使用 --spec 加载 JSON。")

    intent_response = agent_factory().build_spec(intent_text)
    spec = intent_response.simulation_spec
    if args.save_generated_spec:
        output_path = Path(args.save_generated_spec)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(model_to_dict(spec), ensure_ascii=False, indent=2), encoding="utf-8")
    return spec, intent_response


def _case_path(case_name: str) -> Path:
    if case_name == "headache":
        return EXAMPLE_DIR / "headache_triage.simulation.json"
    return EXAMPLE_DIR / "stomach_pain.simulation.json"


def _print_timeline(actions, actor_names: Dict[str, str], actor_locations: Dict[str, str], device_names: Dict[str, str]) -> None:
    for action in actions:
        actor_id = action.actor_id or ""
        actor_name = actor_names.get(actor_id, actor_id or "系统")
        current_location = actor_locations.get(actor_id, "-")
        print(f"\n[{action.time:05.1f}s] {action.type} | {actor_name} | at={current_location}")

        if action.type == "move_to":
            target = action.location_id or "-"
            reason = action.payload.get("reason", "")
            print(f"  位置切换: {current_location} -> {target} {reason}")
            if actor_id:
                actor_locations[actor_id] = target
        elif action.type == "speak":
            target_name = actor_names.get(action.target_actor_id or "", action.target_actor_id or "对方")
            if action.think:
                print(f"  THINK: {action.think}")
            print(f"  {actor_name} -> {target_name}: {action.dialogue}")
        elif action.type == "use_device":
            device_name = device_names.get(action.device_id or "", action.payload.get("device_name", action.device_id or "设备"))
            result = action.payload.get("result", "检查完成")
            print(f"  使用设备: {device_name}, 结果: {result}")
        elif action.type == "wait":
            print(f"  等待 {action.duration:.1f}s")
        elif action.type == "end_simulation":
            print("  状态: completed")
        else:
            print(f"  payload={action.payload}")


if __name__ == "__main__":
    main()
