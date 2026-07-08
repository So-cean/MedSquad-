# EDMAS — Agent Instructions

Godot 4.7 project. Hospital-themed 2D top-down game.

## Project structure

| Path | Purpose |
|---|---|
| `scens/` (note: not `scenes/`) | Godot scenes. Main scene: `scens/edmas/DialogueTest.tscn` |
| `assets/rooms/` | Room background images (CT room, lab room) |
| `Tilesets/` | Hospital-themed tile sprites (lab, maternity, operation, room) |
| `assets/doctor.png` | Doctor white player sprite sheet source (128×128, 32×32 frames, 3×3 grid with 8px padding, center empty). Row 0 = down. Row 1 = up. Row 2 = side (idle + walk). Cell (1,2) = side idle. Cells (0,2)/(2,2) = side walk right/left leg. |
| `assets/doctor_frames/` | Individual sliced 32×32 frame PNGs for doctor white — loaded directly by `player.gd`. Side: `side_idle` (middle), `side_walk_r` (right leg), `side_walk_l` (left leg). |
| `character/doctor walk.png` | Doctor white walk frames source, 3×3 grid with 8px padding, center empty. Row 0 = down walk (3 frames). Cells (0,2)+(1,2) = up walk (2 frames). The remaining cells (row 1 + cell (2,2)) are unused side/other frames. |
| `character/doctor white idle.png` | Doctor white separate front-facing idle frame (32×32, used as `down_idle.png`) |
| `character/doctor.png` | Doctor white 128×128 source sheet (3×3 grid, 8px padding, center empty) |
| `addons/` | Empty — no Godot plugins yet |
| `scripts/` | GDScript source files — `player.gd`, `base_npc.gd`, `camera.gd`, `ui/virtual_joystick.gd`, `dialogue/` (FontRegistry, DialogueBubble, DialogueEntry, DialogueManager, ConversationManager, MemoryStore, TimeSystem), `edmas/` (NpcManager, HospitalMapData, MapSystem, MapNpc, NpcHoverCard, NpcInteractionZone, NpcFsm, ConversationContext, ScenarioConfig, ResourceRegistry, MedicalResource, PatientPlan, Scheduler, Session, InteractionSession, PromptContext) |
| `assets/nurse_frames/` | Nurse white 8-direction 32×32 frame PNGs — **separate idle/walk sheets**: idle_*.png (legs together) + walk_*_a.png (legs apart) + idle_down.png (front-facing idle) |
| `assets/scrubs_green_frames/` | Scrubs green 8-direction 32×32 frame PNGs — **separate idle/walk sheets**: idle_*.png (legs together) + walk_*_a.png (legs apart) + idle_down.png (front-facing idle) |
| `assets/nurse_blue_frames/` | Nurse blue 8-direction 32×32 frame PNGs — **separate idle/walk sheets** (same format) + idle_down |
| `assets/scrubs_blue_frames/` | Scrubs blue 8-direction 32×32 frame PNGs — **separate idle/walk sheets** (same format) + idle_down |
| `assets/nurse_green_frames/` | Nurse green 8-direction 32×32 frame PNGs — **separate idle/walk sheets**: idle_*.png (legs together) + walk_*.png (legs apart) + idle_down.png (front-facing idle) |
| `character/nurse white idle 8dir.png` | Nurse white 8-direction idle sheet (96×96, 3×3 grid, tight, center empty) |
| `character/nurse white walk 8dir.png` | Nurse white 8-direction walk sheet (96×96, 3×3 grid, tight, center empty) |
| `character/nurse white.png` | Nurse white separate idle frame (32×32) |
| `character/nurse blue idle 8dir.png` | Nurse blue 8-direction idle sheet (96×96, 3×3 grid, tight, center empty) |
| `character/nurse blue walk 8dir.png` | Nurse blue 8-direction walk sheet (96×96, 3×3 grid, tight, center empty) |
| `character/nurse blue.png` | Nurse blue separate idle frame (32×32) |
| `character/scrubs blue idle 8dir.png` | Scrubs blue 8-direction idle sheet (96×96, 3×3 grid, tight, center empty) |
| `character/scrubs blue walk 8dir.png` | Scrubs blue 8-direction walk sheet (96×96, 3×3 grid, tight, center empty) |
| `character/scrubs blue.png` | Scrubs blue separate idle frame (32×32) |
| `character/nurse green idle 8dir.png` | Nurse green 8-direction idle sheet (96×96, 3×3 grid, tight, center empty) |
| `character/nurse green walk 8dir.png` | Nurse green 8-direction walk sheet (96×96, 3×3 grid, tight, center empty) |
| `character/nurse green.png` | Nurse green separate idle frame (32×32) |
| `default_env.tres` | Default environment (procedural sky) |

## Key facts

- **Engine**: Godot 4.7 — no npm, no build scripts, no CI. Editor-only workflow.
- **Main scene**: `res://scens/edmas/DialogueTest.tscn` (confirmed in `project.godot` `run/main_scene`).
- **GDScript files** live in `scripts/`. Currently has `player.gd`, `camera.gd`, `base_npc.gd`, `ui/virtual_joystick.gd`, `dialogue/` (FontRegistry, DialogueBubble, DialogueEntry, DialogueManager, ConversationManager, MemoryStore, TimeSystem), `edmas/` (NpcManager, HospitalMapData, MapSystem, MapNpc, NpcHoverCard, NpcInteractionZone, NpcFsm, ConversationContext, ScenarioConfig, ResourceRegistry, MedicalResource, PatientPlan, Scheduler, Session, InteractionSession, PromptContext).
- **Animations**: Uses `AnimatedSprite2D` with code-generated `SpriteFrames` in `_ready()`. Player uses individual sliced 32×32 PNGs. All NPCs use `map_npc.gd` with `@export` vars (`npc_display_name`, `npc_frames_dir`, `npc_walk_flip`) — no per-profession subclass scripts. NPC prefabs (`scens/nurse.tscn`, `scens/nurse_blue.tscn`, `scens/patient_green.tscn`, etc.) all reference `scripts/edmas/map_npc.gd` and set their unique values via `@export` properties. Runtime spawning via `NpcManager._create_map_npc()` also uses `map_npc.gd` + dynamic export assignment.
- **NPC system**: All NPCs use `map_npc.gd` with `@export` vars (`npc_display_name`, `npc_frames_dir`, `npc_walk_flip`) — no per-profession subclass scripts. Each prefab scene (`scens/nurse.tscn`, etc.) sets its own values via @export. Runtime spawning via `NpcManager._create_map_npc()` also uses `map_npc.gd` + dynamic export assignment. Nurse white uses 8-direction frames from `assets/nurse_frames/`. Scrubs green uses `assets/scrubs_green_frames/`. Nurse blue uses `assets/nurse_blue_frames/`. Scrubs blue uses `assets/scrubs_blue_frames/`. Nurse green uses separate idle/walk 8-direction sheets from `assets/nurse_green_frames/`. Patient green/blue use `assets/patient_{green,blue}_frames/` with `npc_walk_flip=["up","down"]`. All NPCs use separate idle/walk sheets with `play()` animation. Stationary by default (`can_wander=false`).
- **Player**: Doctor white. Pre-sliced frames at `assets/doctor_frames/` loaded directly. `down_idle.png` sourced from `character/doctor white idle.png` (32×32 front-facing). Walk_down frames from `character/doctor walk.png` (8px padding, 3×3 grid, cell row 0 = down walk, cells (0,2)+(1,2) = up walk). Side/right uses doctor.png row 2. Left uses flip_h.
- **Nurse white**: 8-direction NPC with separate idle_down frame (front-facing, 32×32) and 8 directional frames from 96×96 sheet (3×3 tight grid). Row 0 = UP/back view, Row 2 = DOWN/front view. Uses separate idle/walk sheets — idle (legs together) + walk_a (legs apart) 2-frame cycle. Stationary by default (`can_wander=false`). Wanders only if `can_wander=true`.
- **Scrubs green**: 8-direction NPC with separate idle_down frame (front-facing, 32×32) and 8 directional frames from 96×96 sheet (3×3 tight grid). **Updated to separate idle/walk sheets** — same animation as nurse green: idle (legs together) + walk_a (legs apart) 2-frame cycle. Stationary by default (`can_wander=false`). Wanders only if `can_wander=true`.
- **Nurse blue**: 8-direction NPC with separate idle_down frame (front-facing, 32×32) and 8 directional frames from 96×96 sheet (3×3 tight grid). **Updated to separate idle/walk sheets** — same animation as nurse white: idle (legs together) + walk_a (legs apart) 2-frame cycle. Stationary by default (`can_wander=false`). Wanders only if `can_wander=true`.
- **Scrubs blue**: 8-direction NPC with separate idle_down frame (front-facing, 32×32) and 8 directional frames from 96×96 sheet (3×3 tight grid). **Updated to separate idle/walk sheets** — same animation as nurse white: idle (legs together) + walk_a (legs apart) 2-frame cycle. Stationary by default (`can_wander=false`). Wanders only if `can_wander=true`.
- **Nurse green**: 8-direction NPC using **separate idle/walk 8-direction sheets**. Idle frames (legs together) from `nurse green idle 8dir.png`, walk frames (legs apart) from `nurse green walk 8dir.png`. Separate idle_down.png for front-facing idle. Walk animation: idle → walk_a (flipped) 2-frame cycle at 6fps. Idle/walk show different poses per direction. Stationary by default (`can_wander=false`). Wanders only if `can_wander=true`.
- **Collision setup**: Existing walls use StaticBody2D (layer 1). Player and NPCs use CharacterBody2D with layer=2, mask=3 (collides with walls + other characters).
- **No addons, no codegen, no migrations.** Straightforward 2D scene tree.
- **NPC attribution**: Sprites by Jephed (Game Between The Lines). Credit when shipping.
- **FontRegistry**: Static helper (`class_name FontRegistry`) at `scripts/dialogue/font_registry.gd`. Provides `FontRegistry.get_cn_font() → FontVariation` with caching. Used by dialogue_bubble, npc_hover_card, and dialogue_manager instead of duplicated font-loading code.
- **Nav agent lazy init**: `BaseNpc._ensure_nav_agent()` centralizes NavigationAgent2D creation + signal wiring (velocity_computed, target_reached, navigation_finished). Called from `_ready()`, `walk_to()`, and `walk_to_pos()`.

## Workflow

- Open the project in Godot editor. No terminal commands needed.
- Scenes use `uid://` resource references (Godot 4 built-in UID system).
- Tilesets use `TileSet` resources with `TileMapLayer` nodes (Godot 4 approach).
- `.png.import` files are auto-generated by the editor. Treat as build artifacts.
- `.gdignore` at `/.godot/.gdignore` excludes the editor cache from Godot's file dock.

## Coding rules

- **Never use `:=` for type inference.** Always specify explicit types: `var x: Type = value` not `var x := value`.
- Functions that return Variant (`JSON.parse_string`, `Dictionary.get()`, array `slice()`, etc.) must have explicit type on the receiving variable.
- **No hardcoded mock data** in production paths. Mock only exists in `DialogueTest` scenes.
- **No Python backend.** All LLM calls go through `npc_fsm.gd` → HTTPRequest → Gitee AI.

## What would be confusing

- **`scens/` is intentionally misspelled** (not `scenes/`). Do not rename it.
- **Hospital theme** — lab, maternity, operation room, and patient room tilesets are the visual vocabulary.

## Auto-record discipline (mandatory)

Every work session must keep two markdown files in sync. Treat this as part of "done", not optional cleanup.

### `issues.md` — problems + solutions
- Every bug observed (in logs, in playtests, in code review) gets an entry: symptom, root cause, fix, status.
- Update the entry when the fix lands; mark `fixed` only after compile + scenario run confirms it.
- Never delete historical entries — append a `## Resolved` subsection if the list gets long.

### `REQUIREMENTS.md` — current requirements
- Every new feature, behavior rule, or spec change is summarized here.
- If two requirements conflict (e.g. "bubble auto-height" vs "bubble fixed 3-line clip"), **do not guess** —
  stop and `question` the user with both options and the trade-off, then write the chosen one into REQUIREMENTS.md.
- Requirements gathered from chat must be merged into the existing section, not appended as new top-level duplicates.

### Workflow
1. User reports a problem or asks for a feature → write to `issues.md` (problem) or `REQUIREMENTS.md` (need) **first**.
2. Plan the work, fix/refactor.
3. After verification, update `issues.md` status to `fixed` with the commit hash.
4. If a fix changes behavior spec, also update `REQUIREMENTS.md`.

### Conflict resolution
When requirements contradict each other, the orchestrator must `question` the user before implementing. Never silently pick one. Record the resolved decision in REQUIREMENTS.md with a short rationale.

