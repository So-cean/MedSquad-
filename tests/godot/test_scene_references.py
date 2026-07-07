from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCENES_DIR = ROOT / "scens" / "edmas"
SCRIPTS_DIR = ROOT / "scripts" / "edmas"
PROJECT = ROOT / "project.godot"


def test_required_scene_files_exist():
    assert (SCENES_DIR / "Main_EDMAS.tscn").exists()
    assert (SCENES_DIR / "HospitalMap.tscn").exists()
    assert (SCENES_DIR / "PatientSprite.tscn").exists()


def test_scene_and_script_references_exist():
    scene_text = (SCENES_DIR / "Main_EDMAS.tscn").read_text(encoding="utf-8")
    map_text = (SCENES_DIR / "HospitalMap.tscn").read_text(encoding="utf-8")
    for rel_path in (
        "res://scens/edmas/Main_EDMAS.tscn",
        "res://scens/edmas/HospitalMap.tscn",
        "res://scens/edmas/PatientSprite.tscn",
        "res://scripts/edmas/main_edmas.gd",
        "res://scripts/edmas/api_client.gd",
        "res://scripts/edmas/patient_manager.gd",
        "res://scripts/edmas/hospital_map_manager.gd",
        "res://scripts/edmas/patient_sprite.gd",
        "res://scripts/edmas/config.gd",
    ):
        assert rel_path in scene_text or rel_path in map_text or (ROOT / rel_path.replace("res://", "")).exists()


def test_hospital_map_uses_normalized_maps():
    text = (SCENES_DIR / "HospitalMap.tscn").read_text(encoding="utf-8")
    assert "res://assets/maps/normalized/map1_norm.png" in text
    assert "res://assets/maps/normalized/map2_norm.png" in text
    assert "res://assets/maps/normalized/map3_norm.png" in text


def test_no_old_map_paths_in_scene_or_scripts():
    paths = [
        SCENES_DIR / "Main_EDMAS.tscn",
        SCENES_DIR / "HospitalMap.tscn",
        SCRIPTS_DIR / "main_edmas.gd",
        SCRIPTS_DIR / "hospital_map_manager.gd",
        SCRIPTS_DIR / "patient_manager.gd",
        SCRIPTS_DIR / "patient_sprite.gd",
        SCRIPTS_DIR / "api_client.gd",
        SCRIPTS_DIR / "config.gd",
        PROJECT,
    ]
    forbidden = ("map1_v1.png", "map2_v3.png", "map3_v1.png", "week13\\MedSquad-", "week13/MedSquad-")
    for path in paths:
        text = path.read_text(encoding="utf-8")
        for item in forbidden:
            assert item not in text, f"forbidden reference {item!r} found in {path.name}"


def test_no_risky_variant_inference_patterns_in_edmas_scripts():
    for path in SCRIPTS_DIR.glob("*.gd"):
        text = path.read_text(encoding="utf-8")
        for pattern in (
            ":= JSON.parse_string",
            ":= json.get_data",
            ":= snapshot.get",
            ":= patient.get",
            ":= Dictionary.get",
            ":= get_node(",
            ":= get_node_or_null(",
            ":= find_child(",
            ":= patient_scene.instantiate",
        ):
            assert pattern not in text, f"forbidden pattern {pattern!r} found in {path.name}"

