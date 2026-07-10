from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_api_client_uses_serial_queue():
    text = (ROOT / "scripts" / "edmas" / "api_client.gd").read_text(encoding="utf-8")
    for token in ("_request_queue", "_active_request", "_start_request", "_process_next_request"):
        assert token in text
    assert "_pending_endpoint" not in text


def test_main_edmas_resolves_active_patient_from_snapshot():
    text = (ROOT / "scripts" / "edmas" / "main_edmas.gd").read_text(encoding="utf-8")
    for token in (
        "_last_snapshot",
        "active_patient_changed",
        "_on_active_patient_changed",
        "_resolve_display_patient",
        "_find_patient_by_id",
    ):
        assert token in text
