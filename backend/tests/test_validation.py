import json
from pathlib import Path

import pytest

from app.schemas.simulation import SimulationSpec
from app.schemas.compat import model_validate
from app.services.validation_service import ValidationException, ValidationService
from app.services.world_state_service import WorldStateService


EXAMPLE = Path(__file__).resolve().parents[1] / "app" / "data" / "examples" / "headache_triage.simulation.json"


def load_spec():
    return model_validate(SimulationSpec, json.loads(EXAMPLE.read_text(encoding="utf-8")))


def test_headache_triage_spec_validates():
    spec = load_spec()
    warnings = ValidationService().validate(spec)
    assert warnings == []


def test_missing_patient_actor_reference_fails():
    data = json.loads(EXAMPLE.read_text(encoding="utf-8"))
    data["patients"][0]["actor_id"] = "missing_actor"
    spec = model_validate(SimulationSpec, data)
    with pytest.raises(ValidationException) as exc:
        ValidationService().validate(spec)
    assert "patients[0].actor_id not found" in exc.value.errors[0].message


def test_world_state_contains_core_entities():
    spec = load_spec()
    world_state = WorldStateService().create_initial_state("sim_test", spec)
    assert "nurse_001" in world_state.actors
    assert "patient_001" in world_state.patients
    assert "ct_001" in world_state.devices
    assert world_state.time == "08:00"
