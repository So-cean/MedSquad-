from typing import Any, Dict, Optional
from pydantic import BaseModel, Field


class Position(BaseModel):
    x: float
    y: float


class ValidationWarning(BaseModel):
    code: str
    message: str
    path: Optional[str] = None


class ApiError(BaseModel):
    code: str
    message: str
    path: Optional[str] = None
    details: Dict[str, Any] = Field(default_factory=dict)


class EntityRef(BaseModel):
    id: str
    type: str
