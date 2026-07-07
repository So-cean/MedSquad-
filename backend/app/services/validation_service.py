from typing import Iterable, List, Set

from app.schemas.common import ApiError, ValidationWarning
from app.schemas.simulation import SimulationSpec


class ValidationException(Exception):
    def __init__(self, errors: List[ApiError]):
        detail = "simulation validation failed:\n" + "\n".join(
            f"  [{e.code}] {e.message} (path={e.path})" for e in errors
        )
        super().__init__(detail)
        self.errors = errors


class ValidationService:
    def validate(self, spec: SimulationSpec) -> List[ValidationWarning]:
        errors: List[ApiError] = []
        warnings: List[ValidationWarning] = []

        self._ensure_unique("actors", [a.id for a in spec.actors], errors)
        self._ensure_unique("patients", [p.id for p in spec.patients], errors)
        self._ensure_unique("diseases", [d.id for d in spec.diseases], errors)
        self._ensure_unique("devices", [d.id for d in spec.devices], errors)
        self._ensure_unique("locations", [l.id for l in spec.scene.locations], errors)
        self._ensure_unique("objectives", [o.id for o in spec.objectives], errors)

        actor_ids = {a.id for a in spec.actors}
        disease_ids = {d.id for d in spec.diseases}
        location_ids = {l.id for l in spec.scene.locations}

        for index, actor in enumerate(spec.actors):
            if actor.location_id not in location_ids:
                errors.append(ApiError(
                    code="reference_not_found",
                    message=f"actors[{index}].location_id not found: {actor.location_id}",
                    path=f"actors[{index}].location_id",
                ))

        for index, patient in enumerate(spec.patients):
            if patient.actor_id not in actor_ids:
                errors.append(ApiError(
                    code="reference_not_found",
                    message=f"patients[{index}].actor_id not found: {patient.actor_id}",
                    path=f"patients[{index}].actor_id",
                ))
            for disease_id in patient.disease_ids:
                if disease_id not in disease_ids:
                    errors.append(ApiError(
                        code="reference_not_found",
                        message=f"patients[{index}].disease_ids not found: {disease_id}",
                        path=f"patients[{index}].disease_ids",
                    ))

        for index, device in enumerate(spec.devices):
            if device.location_id not in location_ids:
                errors.append(ApiError(
                    code="reference_not_found",
                    message=f"devices[{index}].location_id not found: {device.location_id}",
                    path=f"devices[{index}].location_id",
                ))

        if len(spec.actors) > 8:
            warnings.append(ValidationWarning(
                code="actor_count_exceeds_scene_defaults",
                message="More actors were provided than the current default Godot room binds explicitly.",
                path="actors",
            ))

        if not any(a.type == "doctor" for a in spec.actors):
            warnings.append(ValidationWarning(
                code="doctor_missing",
                message="No doctor actor was provided; medical review dialogue may be simplified.",
                path="actors",
            ))

        if errors:
            raise ValidationException(errors)

        return warnings

    def _ensure_unique(self, name: str, ids: Iterable[str], errors: List[ApiError]) -> None:
        seen: Set[str] = set()
        for entity_id in ids:
            if entity_id in seen:
                errors.append(ApiError(
                    code="duplicate_id",
                    message=f"duplicate id in {name}: {entity_id}",
                    path=name,
                ))
            seen.add(entity_id)
