#!/usr/bin/env python3
"""
export_metatile_behaviors.py

Parses pokeemerald/include/constants/metatile_behaviors.h and outputs
assets/tilesets/behavior_constants.json with name → integer value mappings.

The enum is sequential starting at 0, so values are assigned by position.
MB_INVALID is a #define (= UCHAR_MAX = 255) and is appended separately.

Run from project root:
    python3 tools/export_metatile_behaviors.py
"""

import re
import json
import pathlib

POKEEMERALD = pathlib.Path("C:/Users/levib/pokemon_projects/pokeemerald")
HEADER = POKEEMERALD / "include/constants/metatile_behaviors.h"
OUT = pathlib.Path("assets/tilesets/behavior_constants.json")


def main() -> None:
    text = HEADER.read_text(encoding="utf-8")

    # Extract all MB_* identifiers from the enum body (sequential, 0-based).
    # We scan inside the enum { ... } block only to avoid picking up #defines.
    enum_match = re.search(r"enum\s*\{([^}]+)\}", text, re.DOTALL)
    if not enum_match:
        raise RuntimeError("Could not find enum block in metatile_behaviors.h")

    enum_body = enum_match.group(1)
    # Strip C single-line comments before matching to avoid picking up identifiers
    # that appear in comments (e.g. "// functionally the same as MB_DEEP_WATER").
    enum_body_no_comments = re.sub(r"//[^\n]*", "", enum_body)
    names = re.findall(r"\b(MB_[A-Z0-9_]+)\b", enum_body_no_comments)

    constants: dict[str, int] = {name: i for i, name in enumerate(names)}

    # MB_INVALID is a #define = UCHAR_MAX (255), not part of the enum.
    constants["MB_INVALID"] = 255

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(constants, indent=2), encoding="utf-8")
    print(f"Wrote {len(constants)} behavior constants to {OUT}")

    # Spot-check a few well-known values.
    checks = {
        "MB_NORMAL": 0x00,
        "MB_TALL_GRASS": 0x02,
        "MB_LONG_GRASS": 0x03,
        "MB_CAVE": 0x08,
        "MB_POND_WATER": 0x10,
        "MB_JUMP_EAST": 0x38,
    }
    all_ok = True
    for name, expected in checks.items():
        actual = constants.get(name, -1)
        status = "OK" if actual == expected else f"MISMATCH (got {actual:#04x})"
        print(f"  {name}: {expected:#04x} -> {status}")
        if actual != expected:
            all_ok = False
    if not all_ok:
        print("WARNING: Some spot-checks failed — verify metatile_behaviors.h enum order.")


if __name__ == "__main__":
    main()
