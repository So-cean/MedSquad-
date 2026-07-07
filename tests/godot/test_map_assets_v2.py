from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MAP_DIR = ROOT / "assets" / "maps" / "normalized"
MASK_DIR = ROOT / "assets" / "maps" / "masks"
HOSPITAL_MAP = ROOT / "scens" / "edmas" / "HospitalMap.tscn"
CONFIG = ROOT / "scripts" / "edmas" / "config.gd"


def _size(path: Path) -> tuple[int, int]:
    with Image.open(path) as im:
        return im.size


def test_normalized_maps_exist():
    for name in ("map1_norm.png", "map2_norm.png", "map3_norm.png"):
        assert (MAP_DIR / name).exists()


def test_normalized_maps_have_same_size():
    sizes = [_size(MAP_DIR / name) for name in ("map1_norm.png", "map2_norm.png", "map3_norm.png")]
    assert len(set(sizes)) == 1
    assert sizes[0] == (1672, 941)


def test_masks_exist_and_match_map_size():
    pairs = (
        ("map1_norm.png", "map1_walkable_mask.png"),
        ("map2_norm.png", "map2_walkable_mask.png"),
        ("map3_norm.png", "map3_walkable_mask.png"),
    )
    for map_name, mask_name in pairs:
        map_size = _size(MAP_DIR / map_name)
        mask_path = MASK_DIR / mask_name
        assert mask_path.exists()
        assert _size(mask_path) == map_size


def test_hospital_map_references_normalized_maps():
    text = HOSPITAL_MAP.read_text(encoding="utf-8")
    assert "res://assets/maps/normalized/map1_norm.png" in text
    assert "res://assets/maps/normalized/map2_norm.png" in text
    assert "res://assets/maps/normalized/map3_norm.png" in text


def test_config_keeps_map_ids():
    text = CONFIG.read_text(encoding="utf-8")
    assert "MAP_ED_CORE" in text
    assert "MAP_DIAGNOSTICS" in text
    assert "MAP_DOWNSTREAM" in text

