"""build_world_connections.py

Reads all pokeemerald data/maps/*/map.json files and
data/layouts/layouts.json, then outputs:

  data/world_connections.json

Structure:
  {
    "maps": {
      "MAP_PETALBURG_CITY": {
        "scene_path": "res://maps/hoenn/cities/petalburg_city.tscn",
        "width": 30, "height": 30,
        "connections": [{"direction": "left", "map": "MAP_ROUTE104", "offset": -50}],
        "warps": [{"x": 10, "y": 19, "dest_map": "MAP_PETALBURG_CITY_HOUSE1", "dest_warp_id": 0}]
      }, ...
    },
    "scene_to_map": {
      "res://maps/hoenn/cities/petalburg_city.tscn": "MAP_PETALBURG_CITY", ...
    }
  }

Run from the project root:
  /c/Users/levib/anaconda3/python.exe tools/build_world_connections.py
"""

import json
import os
import re
from pathlib import Path

POKEEMERALD = Path("C:/Users/levib/pokemon_projects/pokeemerald")
PROJECT_ROOT = Path("c:/Users/levib/pokemon_projects/primal_harmony/primal-harmony")
MAPS_DIR     = POKEEMERALD / "data" / "maps"
LAYOUTS_JSON = POKEEMERALD / "data" / "layouts" / "layouts.json"
OUT_FILE     = PROJECT_ROOT / "data" / "world_connections.json"


# ── Name conversion (matches batch_paint_maps.gd logic) ──────────────────────

def camel_to_snake(s: str) -> str:
    """'MauvilleGym' → 'mauville_gym'"""
    return re.sub(r"(?<!^)(?=[A-Z])", "_", s).lower()


def map_name_to_snake(name: str) -> str:
    """'LittlerootTown_BrendansHouse_1F' → 'littleroot_town_brendans_house_1_f'"""
    parts = name.split("_")
    return "_".join(camel_to_snake(p) for p in parts)


def get_category(name: str) -> str:
    if name.startswith("Route"):
        return "routes"
    elif "_" in name:
        return "interiors"
    else:
        return "cities"


def map_id_to_scene_path(map_id: str) -> str:
    """
    'MAP_PETALBURG_CITY' → 'res://maps/hoenn/cities/petalburg_city.tscn'
    Derives the map name from the directory listing, not just the ID string,
    because the directory name is the authoritative form.
    Returns "" if no matching map directory exists.
    """
    # The map directory names are stored in _dir_names (built below)
    return ""  # placeholder; overridden after _dir_names is built


# ── Load layouts for dimensions ───────────────────────────────────────────────

def load_layout_dims() -> dict:
    """Returns {layout_name: (width, height), ...}"""
    with open(LAYOUTS_JSON) as f:
        data = json.load(f)
    dims = {}
    for layout in data["layouts"]:
        # layout["name"] is like "PetalburgCity_Layout"
        # layout["id"]   is like "LAYOUT_PETALBURG_CITY"
        dims[layout["id"]] = (int(layout["width"]), int(layout["height"]))
    return dims


# ── Build scene path from directory name (same logic as GDScript batch) ───────

def dir_name_to_scene_path(dir_name: str) -> str:
    cat  = get_category(dir_name)
    slug = map_name_to_snake(dir_name)
    return f"res://maps/hoenn/{cat}/{slug}.tscn"


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    # Build layout lookups from layouts.json.
    # layout_id → (scene_path, width, height)
    # The scene path is derived from the LAYOUT NAME (not the map directory name)
    # so it matches exactly what batch_paint_maps.gd generates.
    with open(LAYOUTS_JSON) as f:
        raw_layouts = json.load(f)["layouts"]

    layout_id_to_info: dict[str, tuple[str, int, int]] = {}
    for layout in raw_layouts:
        layout_id   = layout["id"]          # e.g. "LAYOUT_PETALBURG_CITY"
        layout_name = layout["name"].replace("_Layout", "")  # e.g. "PetalburgCity"
        scene_path  = dir_name_to_scene_path(layout_name)
        layout_id_to_info[layout_id] = (
            scene_path,
            int(layout["width"]),
            int(layout["height"]),
        )

    # Walk every map directory
    map_dirs = sorted(
        d for d in MAPS_DIR.iterdir()
        if d.is_dir() and (d / "map.json").exists()
    )

    print(f"build_world_connections: scanning {len(map_dirs)} map directories...")

    result_maps: dict = {}
    scene_to_map: dict = {}

    for map_dir in map_dirs:
        with open(map_dir / "map.json") as f:
            mdata = json.load(f)

        map_id: str    = mdata["id"]      # e.g. "MAP_PETALBURG_CITY"
        layout_id: str = mdata.get("layout", "")  # e.g. "LAYOUT_PETALBURG_CITY"

        # Scene path and dims come from the layout — this is the SAME path the
        # batch script wrote, even when multiple maps share a layout.
        if layout_id in layout_id_to_info:
            scene_path, w, h = layout_id_to_info[layout_id]
        else:
            scene_path, w, h = "", 0, 0  # map not in layouts.json (no painted scene)

        # Connections
        raw_conns = mdata.get("connections") or []
        connections = []
        for c in raw_conns:
            connections.append({
                "direction": c["direction"],
                "map": c["map"],
                "offset": int(c["offset"]),
            })

        # Warp events
        raw_warps = mdata.get("warp_events") or []
        warps = []
        for w_ev in raw_warps:
            wid_raw = w_ev["dest_warp_id"]
            try:
                wid = int(wid_raw)
            except (ValueError, TypeError):
                wid = -1  # WARP_ID_DYNAMIC, WARP_ID_SECRET_BASE, etc.
            warps.append({
                "x": int(w_ev["x"]),
                "y": int(w_ev["y"]),
                "dest_map": w_ev["dest_map"],
                "dest_warp_id": wid,
            })

        entry = {
            "scene_path": scene_path,
            "width": w,
            "height": h,
            "connections": connections,
            "warps": warps,
        }

        result_maps[map_id] = entry

        if scene_path:
            scene_to_map[scene_path] = map_id

    output = {
        "maps": result_maps,
        "scene_to_map": scene_to_map,
    }

    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_FILE, "w") as f:
        json.dump(output, f, indent=2)

    total_conns  = sum(len(v["connections"]) for v in result_maps.values())
    total_warps  = sum(len(v["warps"])       for v in result_maps.values())
    with_scene   = sum(1 for v in result_maps.values() if v["scene_path"])

    print(f"  {len(result_maps)} maps  |  {with_scene} with scene paths")
    print(f"  {total_conns} connections  |  {total_warps} warps")
    print(f"  Written to: {OUT_FILE}")


if __name__ == "__main__":
    main()
