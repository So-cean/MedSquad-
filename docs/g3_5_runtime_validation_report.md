# G3.5 Runtime Validation Report

## Backend connection
- Default API base URL: `http://127.0.0.1:8000`
- Backend startup command:
  - `cd D:\projects\BME1325Spring2026\ED-MAS`
  - `python manage.py runserver 127.0.0.1:8000`

## Runtime layout
- `Main_EDMAS` now uses a `CanvasLayer` for UI.
- `MapRoot` holds the hospital map and patient nodes.
- UI stays fixed in the upper-left and is not affected by map scaling.

## Expected manual flow
1. Open `D:\projects\BME1325Spring2026\ED-MAS\godot_client\MedSquad-\project.godot`
2. Press `F5` or open `res://scens/edmas/Main_EDMAS.tscn`
3. Confirm the full map is visible.
4. Confirm buttons are visible:
   - `Load Demo A`
   - `Load Demo B`
   - `Load Demo C`
   - `Step`
   - `Reset`
   - `Mock Mode`
5. In mock mode, click `Load Demo A`, then `Step`.
6. Confirm the patient placeholder appears and moves.
7. Click `Talk` and `Next` to confirm mock dialogue.

## Notes
- Mock mode does not require the backend.
- Real API mode still points to the same backend endpoint.
