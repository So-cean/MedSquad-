from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_DIR = ROOT / "scripts" / "edmas"

FORBIDDEN_PATTERNS = (
    ":= JSON.parse_string",
    ":= json.get_data",
    ":= snapshot.get",
    ":= patient.get",
    ":= Dictionary.get",
    ":= get_node(",
    ":= get_node_or_null(",
    ":= find_child(",
    ":= patient_scene.instantiate",
)


def test_edmas_gd_scripts_exist():
    files = list(SCRIPT_DIR.glob("*.gd"))
    assert files, "scripts/edmas/*.gd not found"


def test_no_high_risk_variant_inference_patterns():
    for path in SCRIPT_DIR.glob("*.gd"):
        text = path.read_text(encoding="utf-8")
        for pattern in FORBIDDEN_PATTERNS:
            assert pattern not in text, f"forbidden pattern {pattern!r} found in {path.name}"

