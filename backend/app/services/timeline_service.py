from app.schemas.plan import ActionPlan
from app.schemas.simulation import SimulationSpec, WorldState
from app.schemas.timeline import DemoTimeline, TimelineAction


class TimelineService:
    def build_timeline(self, plan: ActionPlan, spec: SimulationSpec, world_state: WorldState) -> DemoTimeline:
        actions = []
        current_time = 0.0
        locations = {location.id: location for location in spec.scene.locations}

        for index, step in enumerate(plan.steps, start=1):
            position = None
            if step.location_id and step.location_id in locations:
                position = locations[step.location_id].position

            duration = step.duration
            if step.type == "use_device" and step.device_id:
                device = next((device for device in spec.devices if device.id == step.device_id), None)
                if device:
                    duration = device.operation_duration

            action = TimelineAction(
                id=f"act_{index:03d}",
                time=round(current_time, 3),
                type=step.type,
                duration=duration,
                actor_id=step.actor_id,
                target_actor_id=step.target_actor_id,
                location_id=step.location_id,
                device_id=step.device_id,
                position=position,
                think=step.think,
                dialogue=step.dialogue,
                priority=step.priority,
                payload=step.payload,
            )
            actions.append(action)
            current_time += max(duration, 0.0)

        if not actions or actions[-1].type != "end_simulation":
            actions.append(TimelineAction(
                id=f"act_{len(actions) + 1:03d}",
                time=round(current_time, 3),
                type="end_simulation",
                duration=0.0,
                payload={"status": "completed"},
            ))

        return DemoTimeline(
            simulation_id=world_state.simulation_id,
            timeline_id="tl_001",
            version=1,
            actions=actions,
        )
