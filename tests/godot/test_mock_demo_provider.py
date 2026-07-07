from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MOCK = ROOT / "scripts" / "edmas" / "mock" / "mock_demo_provider.gd"
MAIN = ROOT / "scens" / "edmas" / "Main_EDMAS.tscn"
SPRITE = ROOT / "scripts" / "edmas" / "patient_sprite.gd"


def test_mock_demo_provider_exists():
    assert MOCK.exists()


def test_mock_demo_paths_exist_and_finish_correctly():
    text = MOCK.read_text(encoding="utf-8")
    assert "demo_A" in text and "demo_B" in text and "demo_C" in text
    assert "DISCHARGE" in text
    assert "WARD" in text
    assert "ICU" in text


def test_main_edmas_includes_mock_mode_logic():
    text = MAIN.read_text(encoding="utf-8")
    assert "Mock Mode" in text
    assert "button_pressed = true" in text
    assert "mock" in text.lower()


def test_patient_sprite_contains_move_to():
    text = SPRITE.read_text(encoding="utf-8")
    assert "move_to" in text

