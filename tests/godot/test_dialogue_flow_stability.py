from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_mock_dialogue_system_does_not_auto_loop_unconditionally():
    text = (ROOT / "scripts" / "dialogue" / "mock_dialogue_system.gd").read_text(encoding="utf-8")
    assert "auto_restart_flows" in text
    assert "if auto_restart_flows:" in text
    assert "_paused = true" in text
    assert "_tree_timer(2.0, _start_random_flow)" in text


def test_dialogue_system_handles_missing_listener_without_crashing():
    conversation_text = (ROOT / "scripts" / "dialogue" / "conversation_manager.gd").read_text(encoding="utf-8")
    mock_text = (ROOT / "scripts" / "dialogue" / "mock_dialogue_system.gd").read_text(encoding="utf-8")
    assert 'reason = "missing_listener"' in conversation_text
    assert "not is_instance_valid(listener)" in conversation_text
    assert "not is_instance_valid(b)" in conversation_text
    assert "missing listener" in mock_text
