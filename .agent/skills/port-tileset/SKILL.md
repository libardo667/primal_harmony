---
name: port-tileset
description: >
  Port a pokeemerald tileset (primary or secondary) into Primal Harmony's
  Godot-ready format: static metatile atlases, animated metatile atlases,
  Godot .tres atlas sources, and the runtime AnimTileLoader registration.
  Use this skill whenever adding graphics for a new area, route, or town —
  any time you need to make a pokeemerald tileset visible and animated in-game.
  Trigger on: "add tileset for X", "port route/town tileset", "new map needs
  graphics", "add secondary_X", "bring in tiles for Y", or any request to
  make a new area's tiles work in Godot. Also trigger after a new map scene
  is created and the tiles appear wrong or blank.
---

# Skill: port-tileset

Ports one pokeemerald tileset pair (one primary + one secondary) into Godot's
native animated tile format. Run this whenever a new area is added to the game.

---

## 0. Understand the pokeemerald tileset structure

**Source paths** (read-only — never modify pokeemerald files):
```
pokeemerald/data/tilesets/primary/{name}/
    tiles.png        ← 128px wide, paletted ("P" mode PNG)
    metatiles.bin    ← 16 bytes per metatile (8 × uint16 tile attributes)
    palettes/00.pal … 15.pal

pokeemerald/data/tilesets/secondary/{name}/
    tiles.png
    metatiles.bin
    palettes/00.pal … 15.pal

pokeemerald/src/tileset_anims.c   ← animation definitions (shared, parsed once)
```

**To find which tilesets a map uses**, look in pokeemerald:
```
data/layouts/{MapName}/layout.json
  or
src/data/maps/{MapName}/header.json
```
Look for `"primary_tileset"` and `"secondary_tileset"` fields.
The value after the last `_` is the folder name under `primary/` or `secondary/`.
For example `"gTileset_General"` → folder `general`.

**Tile index rules (CRITICAL):**
- Metatile tile attributes store **global VRAM indices**.
- `t_idx < 512` → primary tileset tile, fetch from primary `tiles.png`.
- `t_idx >= 512` → secondary own tile, local = `t_idx - 512`, fetch from secondary `tiles.png`.

---

## 1. Register the new tileset in the Python build scripts

### 1a. `tools/build_godot_tilesets.py` — static atlas generator

In `main()`, add one `process_tileset` call per new tileset. Primary tilesets
are standalone; secondary tilesets name their paired primary.

```python
# In main():
process_tileset(tilesets_dir, pokeemerald_dir, "primary_{name}",   True)
process_tileset(tilesets_dir, pokeemerald_dir, "secondary_{name}", False, "{primary_name}")
```

Example — adding Route 110 (uses `secondary_mauville` + `primary_general`, already done)
and a hypothetical new area using `secondary_rustboro` + `primary_general`:
```python
process_tileset(tilesets_dir, pokeemerald_dir, "primary_general",    True)
process_tileset(tilesets_dir, pokeemerald_dir, "secondary_mauville", False, "general")
process_tileset(tilesets_dir, pokeemerald_dir, "secondary_rustboro", False, "general")
```

**Primary tilesets only need to be listed once** no matter how many secondary
tilesets reference them.

### 1b. `tools/export_tileset_anim_frames.py` — animated atlas generator

In `main()`, add an entry to the `tilesets` list. Use `GENERAL_FPS` (3.75)
for outdoor areas. Use `60.0 / 8.0` (7.5 fps) for building/indoor animations.

```python
tilesets = [
    ("primary_general",    True,  GENERAL_FPS),
    ("secondary_mauville", False, GENERAL_FPS),
    ("secondary_{name}",   False, GENERAL_FPS),  # ← add this line
]
```

---

## 2. Register the new tileset in the runtime loader

**`systems/world/AnimTileLoader.gd`** — add four entries to `TEXTURE_STEM_TO_TILESET`.
Both `_bottom` and `_top` stems must be listed for both terrain and decoration
layers to be rerouted correctly.

```gdscript
const TEXTURE_STEM_TO_TILESET := {
    "primary_general_bottom":    "primary_general",
    "primary_general_top":       "primary_general",
    "secondary_mauville_bottom": "secondary_mauville",
    "secondary_mauville_top":    "secondary_mauville",
    # ↓ Add new secondary tileset:
    "secondary_{name}_bottom":   "secondary_{name}",
    "secondary_{name}_top":      "secondary_{name}",
}
```

If the new tileset is a primary (rare — most maps share `primary_general`),
add `primary_{name}_bottom` and `primary_{name}_top` instead.

---

## 3. Run the build pipeline (three steps, in order)

All commands run from the project root:
`c:/Users/levib/pokemon_projects/primal_harmony/primal-harmony`

### Step 1 — Generate static metatile atlases

```bash
/c/Users/levib/anaconda3/python.exe tools/build_godot_tilesets.py
```

**Expected output per tileset:**
```
Building Godot Metatiles for primary_general...
  -> Generated 512 metatiles.
Building Godot Metatiles for secondary_{name}...
  -> Generated NNN metatiles.
```

**Output files:**
```
assets/tilesets/primary_general_bottom.png
assets/tilesets/primary_general_top.png
assets/tilesets/secondary_{name}_bottom.png
assets/tilesets/secondary_{name}_top.png
```

### Step 2 — Generate animated metatile atlases

```bash
/c/Users/levib/anaconda3/python.exe tools/export_tileset_anim_frames.py
```

**Expected output per tileset:**
```
Processing secondary_{name}...
  Saved secondary_{name}_anim_bottom.png  (NNN×NNN px)
  Saved secondary_{name}_anim_config.json  (NN metatile entries)
```

**Output files:**
```
assets/tilesets/anim/secondary_{name}_anim_bottom.png
assets/tilesets/anim/secondary_{name}_anim_top.png
assets/tilesets/anim/secondary_{name}_anim_config.json
```

If the script prints `0 animated metatiles` for a tileset, that tileset has
no animations — this is normal and not an error.

### Step 3 — Generate Godot .tres atlas sources

```bash
"/c/Program Files/Godot/Godot_v4.6.1-stable_win64.exe" --headless --script res://tools/build_anim_tilesets.gd
```

**Expected output:**
```
  Processing: secondary_{name}  (NN animated metatiles)
    Saved: res://assets/tilesets/secondary_{name}_anim_bottom.tres
    Saved: res://assets/tilesets/secondary_{name}_anim_top.tres
build_anim_tilesets: done.
```

**Output files:**
```
assets/tilesets/secondary_{name}_anim_bottom.tres
assets/tilesets/secondary_{name}_anim_top.tres
```

---

## 4. Verify the outputs

Quick sanity checks with Python:

```python
from PIL import Image
img = Image.open("assets/tilesets/secondary_{name}_bottom.png")
print(img.size)   # Should be (128, rows*16) where rows = ceil(num_metatiles/8)

# Check that the first metatile isn't transparent
px = img.convert("RGBA").getpixel((8, 8))  # centre of metatile 0
print(px)  # Should NOT be (0,0,0,0)
```

If metatile 0 (the blank/empty metatile) is fully transparent, that's expected
and correct — it represents empty space.

---

## 5. Create the map paint script (new map only)

If this is a new map, create `tools/paint_{map_name}.gd` based on
`tools/paint_route_117.gd`. Key values to update:

```gdscript
# 1. Scene path
var scene_path = "res://maps/hoenn/{area}/{map_name}.tscn"

# 2. Atlas source paths — use the new tileset names
{"id": 0, "path": "res://assets/tilesets/primary_{prim}_bottom.png"},
{"id": 1, "path": "res://assets/tilesets/primary_{prim}_top.png"},
{"id": 2, "path": "res://assets/tilesets/secondary_{sec}_bottom.png"},
{"id": 3, "path": "res://assets/tilesets/secondary_{sec}_top.png"},

# 3. Map dimensions (from pokeemerald layout header or map.json)
var map_width  = NN
var map_height = NN

# 4. Map binary path
var file = FileAccess.open("C:/Users/levib/pokemon_projects/pokeemerald/data/layouts/{MapName}/map.bin", FileAccess.READ)
```

Run the script from the Godot Script Editor (open it → Run button, or
`@tool`/`extends EditorScript` pattern).

---

## 6. Atlas layout reference

**Static atlas** (`*_bottom.png`, `*_top.png`):
- Width: 128px (8 metatiles × 16px)
- Each cell: 16×16px
- Atlas coord → metatile index: `idx = ty * 8 + tx`
- Metatile index 0–511 = primary, 512–1023 = secondary (local = idx - 512)

**Animated atlas** (`*_anim_bottom.png`, `*_anim_top.png`):
- Each **row** = one animated metatile
- Each **column** = one animation frame
- Width = `max_frame_count × 16` px (varies per tileset)
- AnimTileLoader reads row assignment from `*_anim_config.json`

**Source IDs in TileSet** (paint_route_*.gd convention):
- 0 = primary bottom, 1 = primary top
- 2 = secondary bottom, 3 = secondary top

---

## 7. Troubleshooting

**Transparent squares on the map:**
- Secondary metatile tiles are rendering out-of-bounds.
- Verify `build_godot_tilesets.py` subtracts 512 from global tile index for
  secondary tiles (`t_idx >= 512 → local = t_idx - 512`). This was the
  root-cause bug fixed in Feb 2026.

**Wrong palette / misplaced tiles:**
- Secondary metatile is using primary cross-references but fetching from
  secondary tiles.png.
- Verify the `t_idx < 512` branch uses `prim_img` and `prim_palettes`.

**AnimTileLoader does nothing (no animation):**
- Run the Python diagnostic below to check if any map metatile indices
  overlap with the anim config:
  ```python
  import json, struct
  raw = open("C:/Users/levib/pokemon_projects/pokeemerald/data/layouts/{MapName}/map.bin","rb").read()
  map_ids = {struct.unpack_from("<H", raw, i)[0] & 0x03FF for i in range(0, len(raw), 2)}
  cfg = json.load(open("assets/tilesets/anim/secondary_{name}_anim_config.json"))
  anim_ids = {int(k) + 512 for k in cfg["animated_metatiles"]}  # secondary are 512+
  print("Overlap:", map_ids & anim_ids)
  ```
  If overlap is empty, the map simply doesn't use those animated metatile
  types — not a bug.

**`build_anim_tilesets.gd` skips a tileset:**
- Verify the `*_anim_config.json` exists and has at least one `animated_metatiles` entry.
- Verify the atlas PNGs are in `assets/tilesets/anim/` and match the paths in the JSON.

**Godot executable not found:**
- Binary: `/c/Program Files/Godot/Godot_v4.6.1-stable_win64.exe`
- Python: `/c/Users/levib/anaconda3/python.exe` (do NOT use bare `python` or `python3`)
