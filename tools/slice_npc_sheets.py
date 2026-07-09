"""
Slice NPC 8-direction sprite sheets into individual 32x32 PNGs.

Source layout (character/):
  {npc}.png                  — 32x32 standalone front-facing idle (-> idle_down.png)
  {npc} idle 8dir.png        — 96x96 3x3 tight grid (8 directions, center empty)
  {npc} walk 8dir.png        — 96x96 3x3 tight grid (8 directions, center empty)

Grid mapping (verified against existing nurse_frames):
  (0,0)=up_left  (0,1)=up         (0,2)=up_right
  (1,0)=left     (1,1)=EMPTY      (1,2)=right
  (2,0)=down_left (2,1)=down       (2,2)=down_right

Output (assets/{npc}_frames/):
  idle_down.png          — copied from {npc}.png (front-facing idle)
  idle_up.png            — sliced from idle 8dir cell (0,1)
  idle_up_left.png       — cell (0,0)
  idle_up_right.png      — cell (0,2)
  idle_left.png          — cell (1,0)
  idle_right.png         — cell (1,2)
  idle_down_left.png     — cell (2,0)
  idle_down_right.png    — cell (2,2)
  walk_down_a.png        — sliced from walk 8dir cell (2,1)
  walk_down_left_a.png   — cell (2,0)
  walk_down_right_a.png  — cell (2,2)
  walk_up_a.png          — cell (0,1)
  walk_up_left_a.png     — cell (0,0)
  walk_up_right_a.png    — cell (0,2)
  walk_left_a.png        — cell (1,0)
  walk_right_a.png       — cell (1,2)

Note: idle_down.png comes from the standalone {npc}.png (NOT from the sheet's
cell (2,1)) because the standalone is a higher-quality front-facing idle frame.
The sheet's cell (2,1) is only used for walk_down_a.

Usage:
  python slice_npc_sheets.py
"""
import os
import shutil
from PIL import Image

CHARACTER_DIR = r"C:\Users\DELL\Documents\Projects\character"
ASSETS_DIR = r"C:\Users\DELL\Documents\Projects\assets"

# (row, col) -> direction name
GRID_MAPPING = {
    (0, 0): "up_left",
    (0, 1): "up",
    (0, 2): "up_right",
    (1, 0): "left",
    (1, 1): None,  # center, empty
    (1, 2): "right",
    (2, 0): "down_left",
    (2, 1): "down",
    (2, 2): "down_right",
}

# NPC name -> (source files). Files in character/ have spaces in names.
# Output dir uses underscores.
NPCS = {
    "labrad_blue": {
        "idle_standalone": "labrad blue.png",
        "idle_sheet": "labrad blue idle 8dir.png",
        "walk_sheet": "labrad blud walk 8dir.png",  # typo "blud" in source
    },
    "qa_gray": {
        "idle_standalone": "qa gray.png",
        "idle_sheet": "qa gray idle 8dir.png",
        "walk_sheet": "qa gray walk 8dir.png",
    },
    "doctor_red": {
        "idle_standalone": "doctor red.png",
        "idle_sheet": "doctor red idle 8dir.png",
        "walk_sheet": "doctor red walk 8dir.png",
    },
    "doctor_green": {
        "idle_standalone": "doctor green.png",
        "idle_sheet": "doctor green idle 8dir.png",
        "walk_sheet": "doctor green walk 8dir.png",
    },
}


def slice_sheet(sheet_path: str, out_dir: str, prefix: str, suffix: str) -> int:
    """Slice a 96x96 3x3 sheet into 8 direction PNGs. Returns count."""
    img = Image.open(sheet_path).convert("RGBA")
    assert img.size == (96, 96), f"Expected 96x96, got {img.size} for {sheet_path}"
    count = 0
    for (r, c), name in GRID_MAPPING.items():
        if name is None:
            continue
        cell = img.crop((c * 32, r * 32, (c + 1) * 32, (r + 1) * 32))
        out_name = f"{prefix}{name}{suffix}.png"
        out_path = os.path.join(out_dir, out_name)
        cell.save(out_path)
        count += 1
    return count


def process_npc(npc_key: str, files: dict) -> None:
    out_dir = os.path.join(ASSETS_DIR, f"{npc_key}_frames")
    os.makedirs(out_dir, exist_ok=True)

    # 1. Copy standalone idle as idle_down.png (front-facing)
    idle_src = os.path.join(CHARACTER_DIR, files["idle_standalone"])
    idle_down_dst = os.path.join(out_dir, "idle_down.png")
    shutil.copy2(idle_src, idle_down_dst)
    print(f"  {npc_key}: idle_down.png <- {files['idle_standalone']}")

    # 2. Slice idle 8dir sheet (7 cells, skip center, skip down since down is standalone)
    idle_sheet_path = os.path.join(CHARACTER_DIR, files["idle_sheet"])
    cnt = 0
    img = Image.open(idle_sheet_path).convert("RGBA")
    assert img.size == (96, 96), f"Expected 96x96 for {idle_sheet_path}, got {img.size}"
    for (r, c), name in GRID_MAPPING.items():
        if name is None or name == "down":
            continue  # skip center + down (down uses standalone)
        cell = img.crop((c * 32, r * 32, (c + 1) * 32, (r + 1) * 32))
        out_path = os.path.join(out_dir, f"idle_{name}.png")
        cell.save(out_path)
        cnt += 1
    print(f"  {npc_key}: {cnt} idle frames from sheet")

    # 3. Slice walk 8dir sheet (8 cells, all directions)
    walk_sheet_path = os.path.join(CHARACTER_DIR, files["walk_sheet"])
    walk_cnt = slice_sheet(walk_sheet_path, out_dir, "walk_", "_a")
    print(f"  {npc_key}: {walk_cnt} walk frames from sheet")

    total = 1 + cnt + walk_cnt
    print(f"  {npc_key}: total {total} PNGs in {out_dir}")


if __name__ == "__main__":
    for npc_key, files in NPCS.items():
        # Verify source files exist
        missing = []
        for k, fn in files.items():
            if not os.path.exists(os.path.join(CHARACTER_DIR, fn)):
                missing.append(f"{k}={fn}")
        if missing:
            print(f"SKIP {npc_key}: missing source files: {missing}")
            continue
        process_npc(npc_key, files)
    print("Done.")
