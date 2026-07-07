"""
Interactive step-by-step simulation demo.

Unlike terminal_demo.py (which generates the entire plan upfront and prints
it at once), this demo runs the simulation ONE ROUND AT A TIME:

    while not finished:
        LLM decides the next single action
        print it to the terminal
        update world state
        advance time

Usage:
    python -m app.cli.interactive_demo
    python -m app.cli.interactive_demo --intent "车祸急诊流程，需要设备和医生资源调度"
"""

import argparse
import json
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from app.agents.scenario_intent_agent import ScenarioIntentAgent
from app.agents.step_agent import StepAgent
from app.config import settings
from app.schemas.compat import model_to_dict, model_validate
from app.schemas.plan import PlanStep
from app.schemas.simulation import SimulationSpec, WorldState
from app.services.simulation_service import SimulationService
from app.services.world_state_service import WorldStateService
from app.storage.file_store import FileStore


MAX_STEPS = 30


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run an EDMAS simulation step-by-step interactively."
    )
    parser.add_argument(
        "--case", default="", choices=["stomach", "headache"],
        help="Built-in case to run.",
    )
    parser.add_argument(
        "--spec", default="",
        help="Path to a custom SimulationSpec JSON file.",
    )
    parser.add_argument(
        "--intent", nargs="?", const="", default=None,
        help="Natural-language scenario request.",
    )
    parser.add_argument(
        "--mock", action="store_true",
        help="Use deterministic mock agent instead of LLM API.",
    )
    parser.add_argument(
        "--save-generated-spec", default="",
        help="Optional path to save the JSON generated from --intent.",
    )
    parser.add_argument(
        "--show-prompts", action="store_true",
        help="Print full system prompt before the demo.",
    )
    args = parser.parse_args()

    spec, intent_response = _resolve_spec(args)

    world_state = WorldStateService().create_initial_state("sim_interactive", spec)
    store = FileStore(Path("runtime"))
    store.create_session("sim_interactive")
    store.write_json("sim_interactive", "input.json", spec)
    store.write_json("sim_interactive", "world_state.json", world_state)

    actor_names = {a.id: a.display_name for a in spec.actors}
    actor_locations = {a.id: a.location_id for a in spec.actors}
    device_names = {d.id: d.name for d in spec.devices}

    print("=" * 72)
    print(f"EDMAS 逐轮交互演示: {spec.title}")
    if intent_response:
        print(f"intent_type: {intent_response.scenario_type}  confidence={intent_response.confidence}")
        print(f"extracted: {intent_response.extracted_requirements}")
        if intent_response.assumptions:
            for a in intent_response.assumptions:
                print(f"  assumption: {a}")
    print("=" * 72)
    print("\n角色:")
    for a in spec.actors:
        print(f"  {a.display_name} [{a.id}] type={a.type}, profession={a.profession}, start={a.location_id}")
    print(f"\n患者: {', '.join(p.name for p in spec.patients)}")
    print(f"疾病: {', '.join(d.name for d in spec.diseases)}")
    print(f"设备: {', '.join(d.name for d in spec.devices)}")
    print(f"目标: {', '.join(o.description for o in spec.objectives)}")
    print("\n" + "=" * 72)
    print("逐轮对话开始（每轮由 LLM 决定下一步动作）")
    print("=" * 72)

    # Main loop
    agent = StepAgent()
    history: List[Dict[str, Any]] = []
    current_time = 0.0
    timeline_actions: List[Dict[str, Any]] = []

    for step_idx in range(MAX_STEPS):
        print(f"\n--- 第 {step_idx + 1} 轮 ---")

        try:
            if args.mock or not settings.openai_api_key:
                step = agent.next_step_mock(spec, world_state, history, step_idx)
            else:
                step = agent.next_step(spec, world_state, history, step_idx)
        except Exception as exc:
            print(f"  [错误] API 调用失败: {exc}")
            print(f"  [回退] 使用 mock 模式继续...")
            step = agent.next_step_mock(spec, world_state, history, step_idx)

        _print_step(step, actor_names, actor_locations, device_names, current_time)

        # Record in history
        history.append(model_to_dict(step))

        # Build timeline action
        position = None
        if step.location_id:
            for loc in spec.scene.locations:
                if loc.id == step.location_id:
                    position = loc.position
                    break

        duration = step.duration
        if step.type == "use_device" and step.device_id:
            for dev in spec.devices:
                if dev.id == step.device_id:
                    duration = dev.operation_duration
                    break

        timeline_actions.append({
            "id": f"act_{step_idx + 1:03d}",
            "time": round(current_time, 3),
            "type": step.type,
            "duration": duration,
            "actor_id": step.actor_id,
            "target_actor_id": step.target_actor_id,
            "location_id": step.location_id,
            "device_id": step.device_id,
            "position": model_to_dict(position) if position else None,
            "think": step.think,
            "dialogue": step.dialogue,
            "priority": step.priority,
            "payload": step.payload,
        })

        # Update world state
        if step.type == "move_to" and step.actor_id and step.location_id:
            if step.actor_id in world_state.actors:
                world_state.actors[step.actor_id]["location_id"] = step.location_id
            actor_locations[step.actor_id] = step.location_id

        current_time += max(duration, 0.0)

        if step.type == "end_simulation":
            print("\n[流程结束]")
            break
    else:
        # Max steps reached
        timeline_actions.append({
            "id": f"act_{MAX_STEPS + 1:03d}",
            "time": round(current_time, 3),
            "type": "end_simulation",
            "duration": 0.0,
            "payload": {"status": "completed"},
        })
        print(f"\n[达到最大步数 {MAX_STEPS}，自动结束]")

    # Save timeline
    timeline = {
        "simulation_id": "sim_interactive",
        "timeline_id": "tl_001",
        "version": 1,
        "actions": timeline_actions,
    }
    store.write_json("sim_interactive", "timeline.json", timeline)
    print(f"\nTimeline 已保存到 runtime/simulations/sim_interactive/timeline.json")

    print("\n" + "=" * 72)
    print(f"演示结束。共 {len(timeline_actions)} 个动作，耗时 {current_time:.1f}s")
    print("=" * 72)


def _resolve_spec(args) -> Tuple[SimulationSpec, Optional[object]]:
    if args.spec:
        spec_path = Path(args.spec)
        return model_validate(SimulationSpec, json.loads(spec_path.read_text(encoding="utf-8"))), None

    if args.case:
        example_dir = Path(__file__).resolve().parents[1] / "data" / "examples"
        if args.case == "headache":
            return model_validate(
                SimulationSpec,
                json.loads((example_dir / "headache_triage.simulation.json").read_text(encoding="utf-8")),
            ), None
        return model_validate(
            SimulationSpec,
            json.loads((example_dir / "stomach_pain.simulation.json").read_text(encoding="utf-8")),
        ), None

    intent_text = args.intent
    if intent_text is None or not intent_text.strip():
        intent_text = input("请输入场景：").strip()
    if not intent_text:
        raise SystemExit("未输入场景。请重新运行并输入自然语言场景，或使用 --spec 加载 JSON。")

    intent_response = ScenarioIntentAgent().build_spec(intent_text)
    spec = intent_response.simulation_spec
    if args.save_generated_spec:
        output_path = Path(args.save_generated_spec)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(
            json.dumps(model_to_dict(spec), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
    return spec, intent_response


def _print_step(
    step: PlanStep,
    actor_names: Dict[str, str],
    actor_locations: Dict[str, str],
    device_names: Dict[str, str],
    current_time: float,
) -> None:
    actor_name = actor_names.get(step.actor_id or "", step.actor_id or "系统")
    location = actor_locations.get(step.actor_id or "", "-")

    if step.type == "speak":
        target_name = actor_names.get(step.target_actor_id or "", step.target_actor_id or "对方")
        if step.think:
            print(f"  [{actor_name} 内心] {step.think}")
        print(f"  [{current_time:05.1f}s] {actor_name} -> {target_name}: {step.dialogue}")

    elif step.type == "move_to":
        reason = step.payload.get("reason", "")
        print(f"  [{current_time:05.1f}s] {actor_name} 从 {location} 移动到 {step.location_id}  {reason}")

    elif step.type == "use_device":
        device_name = device_names.get(step.device_id or "", step.payload.get("device_name", step.device_id or "设备"))
        result = step.payload.get("result", "检查完成")
        print(f"  [{current_time:05.1f}s] {actor_name} 使用 {device_name}，结果: {result}")

    elif step.type == "wait":
        print(f"  [{current_time:05.1f}s] {actor_name} 等待 {step.duration:.1f}s")

    elif step.type == "end_simulation":
        print(f"  [{current_time:05.1f}s] 流程结束")

    else:
        print(f"  [{current_time:05.1f}s] {step.type} | {actor_name} | payload={step.payload}")


if __name__ == "__main__":
    main()