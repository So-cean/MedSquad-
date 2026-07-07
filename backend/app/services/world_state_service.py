from app.schemas.simulation import SimulationSpec, WorldState
from app.schemas.compat import model_to_dict


class WorldStateService:
    def create_initial_state(self, simulation_id: str, spec: SimulationSpec) -> WorldState:
        return WorldState(
            simulation_id=simulation_id,
            status="created",
            time=spec.scene.start_time,
            actors={
                actor.id: {
                    "id": actor.id,
                    "display_name": actor.display_name,
                    "type": actor.type,
                    "profession": actor.profession,
                    "sprite": actor.sprite,
                    "location_id": actor.location_id,
                    "state": "idle",
                    "priority_default": actor.priority_default,
                    "personality": actor.personality,
                    "knowledge": actor.knowledge,
                    "tools": actor.tools,
                    "memory": actor.memory,
                }
                for actor in spec.actors
            },
            patients={
                patient.id: {
                    "id": patient.id,
                    "actor_id": patient.actor_id,
                    "name": patient.name,
                    "age": patient.age,
                    "sex": patient.sex,
                    "chief_complaint": patient.chief_complaint,
                    "symptoms": patient.symptoms,
                    "vitals": patient.vitals,
                    "allergies": patient.allergies,
                    "medical_history": patient.medical_history,
                    "disease_ids": patient.disease_ids,
                    "risk_level": patient.risk_level,
                    "state": "waiting",
                }
                for patient in spec.patients
            },
            diseases={disease.id: model_to_dict(disease) for disease in spec.diseases},
            devices={
                device.id: {
                    **model_to_dict(device),
                    "state": device.status,
                }
                for device in spec.devices
            },
            locations={location.id: model_to_dict(location) for location in spec.scene.locations},
            objectives={objective.id: model_to_dict(objective) for objective in spec.objectives},
            completed_objectives=[],
            events=[],
        )
