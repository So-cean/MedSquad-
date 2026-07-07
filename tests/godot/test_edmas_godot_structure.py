from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT


def test_required_files_exist():
    assert (PROJECT / "project.godot").exists()
    assert (PROJECT / "scripts" / "edmas" / "config.gd").exists()
    assert (PROJECT / "scripts" / "edmas" / "api_client.gd").exists()
    assert (PROJECT / "scripts" / "edmas" / "hospital_map_manager.gd").exists()
    assert (PROJECT / "scripts" / "edmas" / "patient_manager.gd").exists()
    assert (PROJECT / "scens" / "edmas" / "Main_EDMAS.tscn").exists()
    assert (PROJECT / "scens" / "edmas" / "HospitalMap.tscn").exists()
    assert (PROJECT / "scens" / "edmas" / "PatientSprite.tscn").exists()


def test_main_scene_points_to_edmas_entry():
    text = (PROJECT / "project.godot").read_text(encoding="utf-8")
    assert 'run/main_scene="res://scens/edmas/Main_EDMAS.tscn"' in text


def test_main_edmas_contains_required_ui_and_ready_log():
    text = (PROJECT / "scripts" / "edmas" / "main_edmas.gd").read_text(encoding="utf-8")
    assert '[EDMAS] Main_EDMAS scene loaded' in text
    for name in (
        "LoadDemoAButton",
        "LoadDemoBButton",
        "LoadDemoCButton",
        "StepButton",
        "ResetButton",
        "CurrentLocationLabel",
        "CurrentStateLabel",
        "BackendStatusLabel",
    ):
        assert name in text


def test_api_client_contains_all_endpoints():
    text = (PROJECT / "scripts" / "edmas" / "api_client.gd").read_text(encoding="utf-8")
    for endpoint in (
        "/api/godot/demo/list",
        "/api/godot/demo/load",
        "/api/godot/demo/reset",
        "/api/godot/snapshot",
        "/api/godot/step",
        "/api/godot/events/recent",
        "/api/godot/model_calls/recent",
        "/api/godot/user_turn",
    ):
        assert endpoint in text


def test_config_contains_location_maps():
    text = (PROJECT / "scripts" / "edmas" / "config.gd").read_text(encoding="utf-8")
    assert "LOCATION_TO_MAP" in text
    assert "LOCATION_TO_MARKER" in text
    for key in (
        "ED_ENTRANCE",
        "TRIAGE",
        "WAITING_AREA",
        "DOCTOR",
        "ED_RESUS",
        "LAB",
        "IMAGING",
        "DIAGNOSTIC_WAITING",
        "RESULT_REVIEW",
        "DISPOSITION",
        "ICU",
        "WARD",
        "ED_BOARDING",
        "DISCHARGE",
    ):
        assert key in text


def test_hospital_map_contains_required_markers():
    text = (PROJECT / "scens" / "edmas" / "HospitalMap.tscn").read_text(encoding="utf-8")
    for marker in (
        "Marker_ED_Entrance",
        "Marker_Triage",
        "Marker_Waiting",
        "Marker_Doctor",
        "Marker_ED_Resus",
        "Marker_Lab",
        "Marker_Imaging",
        "Marker_Diagnostic_Waiting",
        "Marker_Result_Review",
        "Marker_Disposition",
        "Marker_ICU",
        "Marker_Ward",
        "Marker_ED_Boarding",
        "Marker_Discharge",
        "Marker_Elevator_ED",
        "Marker_Elevator_Diagnostics",
        "Marker_Elevator_Downstream",
    ):
        assert marker in text
