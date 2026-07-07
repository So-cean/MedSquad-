import os
from pathlib import Path


def _load_local_env() -> None:
    env_path = Path(__file__).resolve().parents[1] / ".env"
    if not env_path.exists():
        return
    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), _clean_env_value(value))


def _clean_env_value(value: str) -> str:
    cleaned = value.strip().rstrip(",").strip()
    for _ in range(2):
        cleaned = cleaned.strip().strip('"').strip("'").strip()
        cleaned = cleaned.rstrip(",").strip()
    return cleaned


class Settings:
    def __init__(self):
        _load_local_env()
        self.app_name: str = os.getenv("EDMAS_APP_NAME", "EDMAS Backend")
        self.agent_provider: str = os.getenv("EDMAS_AGENT_PROVIDER", "openai")
        self.runtime_dir: Path = Path(os.getenv(
            "EDMAS_RUNTIME_DIR",
            str(Path(__file__).resolve().parents[1] / "runtime"),
        ))
        self.deterministic: bool = os.getenv("EDMAS_DETERMINISTIC", "true").lower() == "true"
        self.godot_timeline_output: Path = Path(os.getenv(
            "EDMAS_GODOT_TIMELINE_OUTPUT",
            str(Path(__file__).resolve().parents[2] / "data" / "timelines" / "headache_triage.timeline.json"),
        ))
        self.intent_provider: str = os.getenv("EDMAS_INTENT_PROVIDER", "openai").lower()
        self.intent_fallback_provider: str = os.getenv("EDMAS_INTENT_FALLBACK_PROVIDER", "template").lower()
        self.openai_api_key: str = os.getenv("OPENAI_API_KEY", os.getenv("api_key", ""))
        self.openai_base_url: str = os.getenv("OPENAI_BASE_URL", os.getenv("base_url", "https://api.openai.com/v1"))
        self.openai_model: str = os.getenv("OPENAI_MODEL", os.getenv("model_name", "gpt-4.1-mini"))
        self.openai_timeout_seconds: float = float(os.getenv("OPENAI_TIMEOUT_SECONDS", "45"))


settings = Settings()
