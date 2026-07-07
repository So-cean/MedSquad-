from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROFILES = ROOT / "scripts" / "edmas" / "mock" / "mock_agent_profiles.gd"
MAIN = ROOT / "scens" / "edmas" / "Main_EDMAS.tscn"
SCRIPT = ROOT / "scripts" / "edmas" / "main_edmas.gd"


def test_mock_agent_profiles_exists():
    assert PROFILES.exists()


def test_mock_patient_profiles_have_dialogue_lines():
    text = PROFILES.read_text(encoding="utf-8")
    assert "mock_patient_A" in text
    assert "mock_patient_B" in text
    assert "mock_patient_C" in text
    assert text.count("dialogue_lines") >= 3


def test_main_scene_includes_dialogue_panel():
    text = MAIN.read_text(encoding="utf-8")
    assert "DialoguePanel" in text
    assert "DialogueTextLabel" in text
    assert "TalkButton" in text or "NextDialogueButton" in text


def test_main_script_contains_mock_dialogue_logic():
    text = SCRIPT.read_text(encoding="utf-8")
    assert "_on_talk_pressed" in text
    assert "_on_next_dialogue_pressed" in text
    assert "_refresh_dialogue_panel" in text
    assert "MockAgentProfiles" in text


def test_no_real_llm_or_rag_hooks_in_mock_dialogue_path():
    text = SCRIPT.read_text(encoding="utf-8")
    lower = text.lower()
    assert "api_key" not in lower
    assert "openai" not in lower
    assert "deepseek" not in lower
    assert "rag" not in lower
