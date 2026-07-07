import json
from pathlib import Path
from typing import Any, Dict, Optional

from pydantic import BaseModel

from app.schemas.compat import model_to_dict


class FileStore:
    def __init__(self, runtime_dir: Path):
        self.runtime_dir = Path(runtime_dir)
        self.sessions_dir = self.runtime_dir / "simulations"
        self.sessions_dir.mkdir(parents=True, exist_ok=True)

    def session_dir(self, simulation_id: str) -> Path:
        return self.sessions_dir / simulation_id

    def create_session(self, simulation_id: str) -> Path:
        path = self.session_dir(simulation_id)
        path.mkdir(parents=True, exist_ok=True)
        return path

    def write_json(self, simulation_id: str, name: str, value: Any) -> None:
        path = self.create_session(simulation_id) / name
        path.write_text(json.dumps(self._to_data(value), ensure_ascii=False, indent=2), encoding="utf-8")

    def read_json(self, simulation_id: str, name: str) -> Dict[str, Any]:
        path = self.session_dir(simulation_id) / name
        return json.loads(path.read_text(encoding="utf-8"))

    def exists(self, simulation_id: str, name: Optional[str] = None) -> bool:
        path = self.session_dir(simulation_id)
        if name:
            path = path / name
        return path.exists()

    def _to_data(self, value: Any) -> Any:
        if isinstance(value, BaseModel):
            return model_to_dict(value)
        if isinstance(value, list):
            return [self._to_data(item) for item in value]
        if isinstance(value, dict):
            return {key: self._to_data(item) for key, item in value.items()}
        return value
