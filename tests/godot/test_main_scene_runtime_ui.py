from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project.godot"
MAIN = ROOT / "scens" / "edmas" / "Main_EDMAS.tscn"
SCRIPT = ROOT / "scripts" / "edmas" / "main_edmas.gd"
CONFIG = ROOT / "scripts" / "edmas" / "config.gd"
SPRITE = ROOT / "scripts" / "edmas" / "patient_sprite.gd"


def test_project_main_scene_points_to_main_edmas():
    text = PROJECT.read_text(encoding="utf-8")
    assert 'run/main_scene="res://scens/edmas/Main_EDMAS.tscn"' in text


def test_main_scene_has_canvaslayer_and_ui_controls():
    text = MAIN.read_text(encoding="utf-8")
    assert "[node name=\"CanvasLayer\" type=\"CanvasLayer\" parent=\".\"]" in text
    assert "[node name=\"UI\" type=\"Control\" parent=\"CanvasLayer\"]" in text
    for token in [
        "LoadDemoAButton",
        "LoadDemoBButton",
        "LoadDemoCButton",
        "StepButton",
        "ResetButton",
        "MockModeToggle",
        "DialoguePanel",
        "TalkButton",
        "NextDialogueButton",
    ]:
        assert token in text


def test_main_script_contains_runtime_ready_log_and_fit_logic():
    text = SCRIPT.read_text(encoding="utf-8")
    assert "[EDMAS] Main_EDMAS scene loaded" in text
    assert "_fit_map_to_viewport" in text
    assert "MapRoot" in text


def test_config_contains_default_backend_url():
    text = CONFIG.read_text(encoding="utf-8")
    assert 'http://127.0.0.1:8000' in text


def test_patient_sprite_has_visibility_priority():
    text = SPRITE.read_text(encoding="utf-8")
    assert "z_index = 100" in text
    assert "ColorRect" in text
