from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_dynamic_patient_session_files_exist():
    required = [
        ROOT / "scripts" / "edmas" / "patient_factory.gd",
        ROOT / "scripts" / "edmas" / "patient_case_pool.gd",
        ROOT / "scripts" / "edmas" / "dialogue" / "interaction_session.gd",
        ROOT / "scripts" / "edmas" / "dialogue" / "session_manager.gd",
        ROOT / "docs" / "dialogue_session_design_v1.md",
    ]
    for path in required:
        assert path.exists(), path


def test_patient_case_pool_defines_three_cases():
    text = (ROOT / "scripts" / "edmas" / "patient_case_pool.gd").read_text(encoding="utf-8")
    for token in ("case_chest_pain", "case_fever", "case_leg_numbness", "chief_complaint", "acuity_hint"):
        assert token in text


def test_interaction_session_contains_all_phases():
    text = (ROOT / "scripts" / "edmas" / "dialogue" / "interaction_session.gd").read_text(encoding="utf-8")
    for token in ("CREATED", "ACTIVE", "WAITING_RESPONSE", "PLAYER_INTERVENTION", "COMPLETED", "FAILED"):
        assert token in text
    for token in ("player_can_intervene", "player_intervention_role", "local_result", "participants"):
        assert token in text


def test_session_manager_has_mock_dialogue_and_intervention_ui():
    text = (ROOT / "scripts" / "edmas" / "dialogue" / "session_manager.gd").read_text(encoding="utf-8")
    for token in (
        "auto_start_demo",
        "spawn_patient",
        "InteractionSession",
        "PLAYER_INTERVENTION_RADIUS",
        "PatientFactory",
        "PatientCasePool",
        "Patient",
        "Nurse",
        "Doctor",
        "Advance",
    ):
        assert token in text
    assert "llm" not in text.lower() or "no llm" not in text.lower()

