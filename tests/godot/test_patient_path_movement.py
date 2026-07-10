from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_patient_manager_uses_navigation_path_with_fallback():
    text = (ROOT / "scripts" / "edmas" / "patient_manager.gd").read_text(encoding="utf-8")
    for token in (
        'preload("res://scripts/edmas/navigation/navigation_service.gd")',
        "_navigation_service",
        "_get_path_to_location",
        "build_for_map",
        "get_path",
        "move_along_path(path_points)",
        "navigation fallback move_to",
        "sprite.move_to(target_position)",
    ):
        assert token in text
    assert "marker_2d.position" in text
    assert "marker_2d.global_position" not in text


def test_patient_sprite_treats_path_points_as_absolute_and_stops_old_tween():
    text = (ROOT / "scripts" / "edmas" / "patient_sprite.gd").read_text(encoding="utf-8")
    for token in (
        "_move_tween",
        "_stop_move_tween()",
        "func move_along_path(path_points: Array[Vector2])",
        'tween_property(self, "position", point',
        'tween_property(self, "position", p_target_position',
        "_move_tween.kill()",
        "target_position = path_points[path_points.size() - 1]",
    ):
        assert token in text
    assert "global_position" not in text
