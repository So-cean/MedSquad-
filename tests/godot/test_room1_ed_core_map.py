from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_room1_uses_ed_core_map_asset():
    scene_text = (ROOT / "scens" / "room1.tscn").read_text(encoding="utf-8")
    assert "res://assets/maps/edmas/map1_v2.png" in scene_text
    assert "EDCoreMapSprite" in scene_text
    assert "centered = false" in scene_text
    assert "position = Vector2(0, 0)" in scene_text
    assert "z_index = -100" in scene_text


def test_edmas_map_assets_exist():
    for name in ("map1_v2.png", "map2_v4.png", "map3_v2.png"):
        assert (ROOT / "assets" / "maps" / "edmas" / name).exists()


def test_room1_retains_runtime_shell_and_camera_entry():
    scene_text = (ROOT / "scens" / "room1.tscn").read_text(encoding="utf-8")
    for token in (
        "res://scripts/edmas/npc_manager.gd",
        "res://scripts/edmas/npc_hover_card.gd",
        "res://scripts/edmas/dialogue/session_manager.gd",
        "res://scens/player.tscn",
    ):
        assert token in scene_text
    assert "visible = false" in scene_text

    player_text = (ROOT / "scens" / "player.tscn").read_text(encoding="utf-8")
    assert "Camera2D" in player_text
    assert "res://scripts/camera.gd" in player_text

    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    assert 'DialogueManager="*res://scripts/dialogue/dialogue_manager.gd"' in project_text
    assert 'run/main_scene="res://scens/room1.tscn"' in project_text
