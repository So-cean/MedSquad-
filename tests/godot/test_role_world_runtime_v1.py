from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_phase1_runtime_files_exist():
    required = [
        ROOT / "scripts" / "edmas" / "config" / "role_profiles.gd",
        ROOT / "scripts" / "edmas" / "config" / "floor_spawn_config.gd",
        ROOT / "scripts" / "edmas" / "scenario_config.gd",
        ROOT / "scripts" / "edmas" / "world" / "resource_registry.gd",
        ROOT / "scripts" / "edmas" / "npc_manager.gd",
        ROOT / "scripts" / "edmas" / "map_npc.gd",
        ROOT / "scripts" / "edmas" / "npc_hover_card.gd",
        ROOT / "docs" / "role_world_runtime_v1.md",
    ]
    for path in required:
        assert path.exists(), path


def test_room1_remains_default_runtime():
    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    assert 'run/main_scene="res://scens/room1.tscn"' in project_text


def test_room1_contains_role_runtime_and_hover_card():
    text = (ROOT / "scens" / "room1.tscn").read_text(encoding="utf-8")
    assert "RoleRuntime" in text
    assert "NpcHoverCard" in text
    assert "RoleOverlay" in text


def test_role_profiles_cover_required_ids_and_rules():
    text = (ROOT / "scripts" / "edmas" / "config" / "role_profiles.gd").read_text(encoding="utf-8")
    for role_id in (
        "player_doctor_001",
        "triage_nurse_001",
        "triage_nurse_002",
        "emergency_nurse_001",
        "doctor_green_001",
        "doctor_red_001",
        "patient_spawn_point",
        "lab_nurse_001",
        "lab_technician_001",
        "surgeon_001",
        "ward_nurse_001",
        "qa_officer_001",
    ):
        assert role_id in text
    assert '"role": "player"' in text
    assert '"resource_role": null' in text
    assert '"llm_enabled": false' in text
    assert '"scheduler_eligible": false' in text
    assert text.count('"role": "doctor"') >= 2


def test_floor_spawn_config_has_three_floors():
    text = (ROOT / "scripts" / "edmas" / "config" / "floor_spawn_config.gd").read_text(encoding="utf-8")
    for floor_id in ("F1", "F2", "F3"):
        assert floor_id in text
    for marker in ("Player", "Nurse", "NurseBlue", "NurseGreen", "ScrubsGreen", "ScrubsBlue", "PatientBlue"):
        assert marker in text


def test_npc_manager_logs_and_hover_fields():
    text = (ROOT / "scripts" / "edmas" / "npc_manager.gd").read_text(encoding="utf-8")
    assert "[ROLE INIT]" in text
    for token in ("hover_card_path", "_update_hover_card", "current_goal", "llm_enabled", "get_registered_npcs"):
        assert token in text
    hover = (ROOT / "scripts" / "edmas" / "npc_hover_card.gd").read_text(encoding="utf-8")
    for token in ("display_name", "role", "floor", "current_state", "current_location", "current_goal", "llm_enabled"):
        assert token in hover

