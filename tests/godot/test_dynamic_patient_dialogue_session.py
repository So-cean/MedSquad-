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
    for token in ("case_chest_pain", "case_fever", "case_leg_numbness", "case_abdominal_pain", "case_shortness_breath", "chief_complaint", "patient_detail", "vitals_line", "acuity_hint"):
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
        "PLAYER_INTERVENTION_RADIUS := 120.0",
        "PatientFactory",
        "PatientCasePool",
        "Patient",
        "Nurse",
        "Doctor",
        "Advance",
    ):
        assert token in text
    assert "_panel.visible = false" in text
    assert "button.disabled = not can_intervene" in text
    assert "llm" not in text.lower() or "no llm" not in text.lower()


def test_dynamic_patient_contract_and_mock_decoupling():
    factory_text = (ROOT / "scripts" / "edmas" / "patient_factory.gd").read_text(encoding="utf-8")
    session_text = (ROOT / "scripts" / "edmas" / "dialogue" / "session_manager.gd").read_text(encoding="utf-8")
    patient_blue_text = (ROOT / "scripts" / "patient_blue.gd").read_text(encoding="utf-8")
    patient_green_text = (ROOT / "scripts" / "patient_green.gd").read_text(encoding="utf-8")

    for token in ("create_patient_record", '"patient_id"', '"ARRIVED"', '"ED_ENTRANCE"', "PatientCasePool.get_case"):
        assert token in factory_text
    assert 'set_meta("state", "TRIAGE")' in session_text
    assert 'set_meta("location", "TRIAGE")' in session_text
    assert "_say(_patient_node" in session_text
    assert "local_result" in session_text
    assert 'return "dynamic_patients"' in patient_blue_text
    assert 'return "dynamic_patients"' in patient_green_text


def test_session_manager_has_waypoint_movement_and_optional_llm_case_api():
    text = (ROOT / "scripts" / "edmas" / "dialogue" / "session_manager.gd").read_text(encoding="utf-8")
    for token in (
        "_move_patient_to_triage",
        "move_along_path",
        "Vector2(760.0, 790.0)",
        "Vector2(610.0, 390.0)",
        "EDMAS_LLM_API_URL",
        "EDMAS_LLM_API_KEY",
        "_fetch_llm_case_if_configured",
        "_parse_llm_case_response",
    ):
        assert token in text

