from typing import Any, Dict, List, Literal, Optional
from pydantic import BaseModel, Field

from .common import Position


TimelineActionType = Literal["spawn_actor", "move_to", "face_actor", "speak", "wait", "use_device", "set_state", "end_simulation"]


class TimelineAction(BaseModel):
    id: str
    time: float
    type: TimelineActionType
    duration: float = 0.0
    actor_id: Optional[str] = None
    target_actor_id: Optional[str] = None
    location_id: Optional[str] = None
    device_id: Optional[str] = None
    position: Optional[Position] = None
    think: str = ""
    dialogue: str = ""
    priority: int = 1
    payload: Dict[str, Any] = Field(default_factory=dict)


class DemoTimeline(BaseModel):
    simulation_id: str
    timeline_id: str
    version: int = 1
    actions: List[TimelineAction] = Field(default_factory=list)
