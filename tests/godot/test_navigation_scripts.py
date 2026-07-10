from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_navigation_layer_files_exist_under_fixed_path():
    nav_dir = ROOT / "scripts" / "edmas" / "navigation"
    assert (nav_dir / "map_navigation_config.gd").exists()
    assert (nav_dir / "navigation_service.gd").exists()


def test_navigation_service_exposes_pure_interface_and_astar_grid():
    text = (ROOT / "scripts" / "edmas" / "navigation" / "navigation_service.gd").read_text(encoding="utf-8")
    for token in (
        "class_name NavigationService",
        "AStarGrid2D",
        "func build_for_map",
        "func get_path",
        "func world_to_cell",
        "func cell_to_world",
        "push_warning",
        "return []",
    ):
        assert token in text
    assert "global_position" not in text
    assert "viewport" not in text.lower()


def test_navigation_config_declares_maps_and_masks():
    text = (ROOT / "scripts" / "edmas" / "navigation" / "map_navigation_config.gd").read_text(encoding="utf-8")
    for token in (
        "MAP_ED_CORE",
        "MAP_DIAGNOSTICS",
        "MAP_DOWNSTREAM",
        "mask_path",
        "cell_size",
        "map_size",
    ):
        assert token in text


def test_hospital_map_marker_positions_are_map_local():
    text = (ROOT / "scripts" / "edmas" / "hospital_map_manager.gd").read_text(encoding="utf-8")
    assert "return marker_2d.position" in text
    assert "return marker_2d.global_position" not in text
