from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_patient_manager_prunes_stale_patients_and_tracks_active_patient():
    text = (ROOT / "scripts" / "edmas" / "patient_manager.gd").read_text(encoding="utf-8")
    for token in (
        "patient_sprites: Dictionary",
        "patient_states: Dictionary",
        "active_patient_id",
        "_prune_missing_patients",
        "_sync_active_patient",
        "no location change",
        "removed stale",
        "created",
    ):
        assert token in text


def test_patient_manager_updates_only_when_location_changes():
    text = (ROOT / "scripts" / "edmas" / "patient_manager.gd").read_text(encoding="utf-8")
    assert "if old_location == location_name" in text
    assert "old_state" not in text
    assert "move_to(target_position)" in text
    assert "queue_free()" in text
