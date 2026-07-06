# EDMAS — Agent Instructions

Godot 4.7 project. Hospital-themed 2D top-down game.

## Project structure

| Path | Purpose |
|---|---|
| `scens/` (note: not `scenes/`) | Godot scenes. Main scene: `scens/room1.tscn` |
| `assets/rooms/` | Room background images (CT room, lab room) |
| `Tilesets/` | Hospital-themed tile sprites (lab, maternity, operation, room) |
| `assets/doctor.png` | Doctor white player sprite sheet source (128×128, 32×32 frames, 3×3 grid with 8px padding, center empty). Row 0 = down. Row 1 = up. Row 2 = side (idle + walk). Cell (1,2) = side idle. Cells (0,2)/(2,2) = side walk right/left leg. |
| `assets/doctor_frames/` | Individual sliced 32×32 frame PNGs for doctor white — loaded directly by `player.gd`. Side: `side_idle` (middle), `side_walk_r` (right leg), `side_walk_l` (left leg). |
| `character/doctor walk.png` | Doctor white walk frames source, 3×3 grid with 8px padding, center empty. Row 0 = down walk (3 frames). Cells (0,2)+(1,2) = up walk (2 frames). The remaining cells (row 1 + cell (2,2)) are unused side/other frames. |
| `character/doctor white idle.png` | Doctor white separate front-facing idle frame (32×32, used as `down_idle.png`) |
| `character/doctor.png` | Doctor white 128×128 source sheet (3×3 grid, 8px padding, center empty) |
| `addons/` | Empty — no Godot plugins yet |
| `scripts/` | GDScript source files (`player.gd`, `nurse.gd`, `scrubs_green.gd`, `nurse_blue.gd`, `scrubs_blue.gd`, `nurse_green.gd`) |
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
- **Main scene**: `res://scens/room1.tscn` (uid `dj5e7k2td4sek`). Contains a CT room and lab room with collision shapes + TileMapLayer floor.
- **GDScript files** live in `scripts/`. Currently has `player.gd`, `nurse.gd`, `scrubs_green.gd`, `nurse_blue.gd`, `scrubs_blue.gd`, and `nurse_green.gd`.
- **Animations**: Uses `AnimatedSprite2D` with code-generated `SpriteFrames` in `_ready()`. Player uses individual sliced 32×32 PNGs. All NPCs now use separate idle/walk 8-direction sheets with 2-frame idle→walk_a cycles at 6fps. Per-direction idle/walk animations with manual `play()`/`stop()` control.
- **NPC system**: NPCs have profession-specific scripts. Nurse white NPC (`nurse.gd`) uses 8-direction frames from `assets/nurse_frames/`. Scrubs green NPC (`scrubs_green.gd`) uses 8-direction frames from `assets/scrubs_green_frames/`. Nurse blue NPC (`nurse_blue.gd`) uses 8-direction frames from `assets/nurse_blue_frames/`. Scrubs blue NPC (`scrubs_blue.gd`) uses 8-direction frames from `assets/scrubs_blue_frames/`. Nurse green NPC (`nurse_green.gd`) uses separate idle/walk 8-direction sheets from `assets/nurse_green_frames/`. All NPCs now use separate idle/walk sheets with play() animation.
- **Player**: Doctor white. Pre-sliced frames at `assets/doctor_frames/` loaded directly. `down_idle.png` sourced from `character/doctor white idle.png` (32×32 front-facing). Walk_down frames from `character/doctor walk.png` (8px padding, 3×3 grid, cell row 0 = down walk, cells (0,2)+(1,2) = up walk). Side/right uses doctor.png row 2. Left uses flip_h.
- **Nurse white**: 8-direction NPC with separate idle_down frame (front-facing, 32×32) and 8 directional frames from 96×96 sheet (3×3 tight grid). Row 0 = UP/back view, Row 2 = DOWN/front view. Uses separate idle/walk sheets — idle (legs together) + walk_a (legs apart) 2-frame cycle. Wanders in any of 8 directions.
- **Scrubs green**: 8-direction NPC with separate idle_down frame (front-facing, 32×32) and 8 directional frames from 96×96 sheet (3×3 tight grid). **Updated to separate idle/walk sheets** — same animation as nurse green: idle (legs together) + walk_a (legs apart) 2-frame cycle. Wanders in any of 8 directions.
- **Nurse blue**: 8-direction NPC with separate idle_down frame (front-facing, 32×32) and 8 directional frames from 96×96 sheet (3×3 tight grid). **Updated to separate idle/walk sheets** — same animation as nurse white: idle (legs together) + walk_a (legs apart) 2-frame cycle. Wanders in any of 8 directions.
- **Scrubs blue**: 8-direction NPC with separate idle_down frame (front-facing, 32×32) and 8 directional frames from 96×96 sheet (3×3 tight grid). **Updated to separate idle/walk sheets** — same animation as nurse white: idle (legs together) + walk_a (legs apart) 2-frame cycle. Wanders in any of 8 directions.
- **Nurse green**: 8-direction NPC using **separate idle/walk 8-direction sheets**. Idle frames (legs together) from `nurse green idle 8dir.png`, walk frames (legs apart) from `nurse green walk 8dir.png`. Separate idle_down.png for front-facing idle. Walk animation: idle → walk_a (flipped) 2-frame cycle at 6fps. Idle/walk show different poses per direction. Wanders in any of 8 directions.
- **Collision setup**: Existing walls use StaticBody2D (layer 1). Player and NPCs use CharacterBody2D with layer=2, mask=3 (collides with walls + other characters).
- **No addons, no codegen, no migrations.** Straightforward 2D scene tree.
- **NPC attribution**: Sprites by Jephed (Game Between The Lines). Credit when shipping.
- **No `.gitignore` yet.** If initializing git, add `/.godot/` to avoid committing the editor cache.

## Workflow

- Open the project in Godot editor. No terminal commands needed.
- Scenes use `uid://` resource references (Godot 4 built-in UID system).
- Tilesets use `TileSet` resources with `TileMapLayer` nodes (Godot 4 approach).
- `.png.import` files are auto-generated by the editor. Treat as build artifacts.
- `.gdignore` at `/.godot/.gdignore` excludes the editor cache from Godot's file dock.

## What would be confusing

- **`scens/` is intentionally misspelled** (not `scenes/`). Do not rename it.
- **Hospital theme** — lab, maternity, operation room, and patient room tilesets are the visual vocabulary.
