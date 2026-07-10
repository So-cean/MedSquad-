from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_mock_dialogue_system_does_not_auto_loop_unconditionally():
    text = (ROOT / "scripts" / "dialogue" / "mock_dialogue_system.gd").read_text(encoding="utf-8")
    assert "auto_restart_flows" in text
    assert "if auto_restart_flows:" in text
    assert "_paused = true" in text
    assert "_tree_timer(2.0, _start_random_flow)" in text

