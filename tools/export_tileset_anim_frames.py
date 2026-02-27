"""
export_tileset_anim_frames.py

Reads tileset_anims.c from the pokeemerald source tree, finds all animated
tile definitions, and renders per-metatile animation atlases into
assets/tilesets/anim/.  The output is self-contained: at runtime Godot
only needs the files in assets/, not the pokeemerald source tree.

Atlas layout (one PNG per tileset side: bottom / top):
    Each ROW  = one animated metatile (sorted by metatile index)
    Each COL  = one frame step in the animation sequence (may repeat)
    Width  = max_frame_count * 16 px
    Height = num_animated_metatiles * 16 px

Companion script build_anim_tilesets.gd reads the JSON config and
generates a TileSetAtlasSource .tres that Godot can animate natively.
"""

import re
import struct
import json
import copy
from pathlib import Path
from PIL import Image


# ── palette / tile helpers (mirrors build_godot_tilesets.py) ─────────────────

def parse_pal(pal_path: Path):
    colors = []
    if not pal_path.exists():
        return [(255, 0, 255)] * 16
    with open(pal_path, 'r') as f:
        lines = f.read().splitlines()
    for line in lines[3:]:
        if not line.strip():
            continue
        parts = line.split()
        if len(parts) == 3:
            colors.append(tuple(map(int, parts)))
    while len(colors) < 16:
        colors.append((255, 0, 255))
    return colors[:16]


def extract_gba_tile(src_img, x, y, palette, x_flip, y_flip):
    """Extract one 8×8 tile from the paletted tiles.png, apply palette → RGBA."""
    tile = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    pixels = tile.load()
    px, py = x * 8, y * 8
    for ty in range(8):
        for tx in range(8):
            sx, sy = px + tx, py + ty
            if sx >= src_img.width or sy >= src_img.height:
                continue
            idx = src_img.getpixel((sx, sy))
            if 0 < idx < 16:
                r, g, b = palette[idx]
                dest_x = (7 - tx) if x_flip else tx
                dest_y = (7 - ty) if y_flip else ty
                pixels[dest_x, dest_y] = (r, g, b, 255)
    return tile


def patch_src_img(src_img, tiles_per_row, dest_tile_start, frame_img):
    """
    Return a copy of the paletted src_img with frame_img's tiles patched
    over the tile slots starting at dest_tile_start.
    Loop order is ty-outer / tx-inner (row-major) to match GBA 4bpp layout.
    """
    result = src_img.copy()
    w_tiles = frame_img.width // 8
    h_tiles = frame_img.height // 8
    t_idx = 0
    for ty in range(h_tiles):
        for tx in range(w_tiles):
            vdest = dest_tile_start + t_idx
            dest_px = (vdest % tiles_per_row) * 8
            dest_py = (vdest // tiles_per_row) * 8
            crop = frame_img.crop((tx * 8, ty * 8, tx * 8 + 8, ty * 8 + 8))
            result.paste(crop, (dest_px, dest_py))
            t_idx += 1
    return result


def render_metatile(m_idx, raw, src_img, palettes, tiles_per_row,
                    primary_img=None, primary_palettes=None, primary_tpr=None):
    """Render metatile m_idx → (bottom 16×16 RGBA, top 16×16 RGBA).

    For secondary tilesets pass primary_img / primary_palettes / primary_tpr so
    that tile references < 512 (primary cross-refs) are fetched from the correct
    source, and references ≥ 512 are converted to local secondary indices.
    """
    layer_tiles = struct.unpack("<8H", raw[m_idx * 16: m_idx * 16 + 16])
    bottom = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    top    = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for out_img, offset in ((bottom, 0), (top, 4)):
        for i in range(4):
            val     = layer_tiles[i + offset]
            t_idx   = val & 0x03FF
            h_flip  = bool(val & 0x0400)
            v_flip  = bool(val & 0x0800)
            pal_idx = (val & 0xF000) >> 12
            if primary_img is not None and t_idx >= 512:
                # Secondary own tile: GLOBAL index → LOCAL index
                local = t_idx - 512
                sub_x = local % tiles_per_row
                sub_y = local // tiles_per_row
                tile_img = extract_gba_tile(src_img, sub_x, sub_y, palettes[pal_idx], h_flip, v_flip)
            elif primary_img is not None:
                # Primary tile cross-reference inside a secondary metatile
                sub_x = t_idx % primary_tpr
                sub_y = t_idx // primary_tpr
                tile_img = extract_gba_tile(primary_img, sub_x, sub_y, primary_palettes[pal_idx], h_flip, v_flip)
            else:
                sub_x = t_idx % tiles_per_row
                sub_y = t_idx // tiles_per_row
                tile_img = extract_gba_tile(src_img, sub_x, sub_y, palettes[pal_idx], h_flip, v_flip)
            dx = 8 if i % 2 == 1 else 0
            dy = 8 if i >= 2 else 0
            out_img.paste(tile_img, (dx, dy), tile_img)
    return bottom, top


def metatiles_referencing_range(raw, tile_start, tile_count):
    """Return the set of metatile indices whose data references any tile in [tile_start, tile_start+tile_count)."""
    affected = set()
    num = len(raw) // 16
    tile_end = tile_start + tile_count
    for m in range(num):
        for word_offset in range(0, 16, 2):
            val = struct.unpack_from("<H", raw, m * 16 + word_offset)[0]
            t = val & 0x03FF
            if tile_start <= t < tile_end:
                affected.add(m)
                break
    return affected


def snake_to_camel(s: str) -> str:
    """Convert snake_case to CamelCase: 'mauville_gym' → 'MauvilleGym'."""
    return "".join(w.capitalize() for w in s.split("_"))


# ── C source parser ───────────────────────────────────────────────────────────

def parse_tileset_anims_c(c_file: Path, pokeemerald_dir: Path):
    """
    Parse tileset_anims.c.

    Returns:
      frame_files  : { 'gTilesetAnims_Foo_FrameN': Path('...png') }
      sequences    : { 'gTilesetAnims_Foo': ['gTilesetAnims_Foo_Frame0', ...] }
      queue_anims  : [ { 'array': str, 'dest_tiles': [int,...], 'tile_count': int } ]
                     dest_tiles are tileset-relative tile indices.
    """
    text = c_file.read_text(encoding='utf-8', errors='replace')

    # 1. Frame file definitions
    #    const u16 gTilesetAnims_Foo_FrameN[] = INCBIN_U16("data/.../N.4bpp");
    frame_files = {}
    for m in re.finditer(
        r'(gTilesetAnims_\w+)\[\]\s*=\s*INCBIN_U16\("([^"]+\.4bpp)"\)',
        text
    ):
        name = m.group(1)
        png = pokeemerald_dir / m.group(2).replace('.4bpp', '.png')
        frame_files[name] = png

    # 2. Sequence arrays
    #    const u16 *const gTilesetAnims_Foo[] = { FrameA, FrameB, ... };
    sequences = {}
    for m in re.finditer(
        r'const\s+u16\s*\*const\s+(gTilesetAnims_\w+)\[\]\s*=\s*\{([^}]+)\}',
        text, re.DOTALL
    ):
        arr = m.group(1)
        refs = [r.strip().rstrip(',') for r in m.group(2).split(',') if r.strip().rstrip(',')]
        sequences[arr] = refs

    # 3. VDest arrays (broadcast to multiple tile slots, e.g. Mauville flowers)
    #    u16 *const gTilesetAnims_Foo_VDests[] = { TILE_OFFSET_4BPP(NUM_TILES_IN_PRIMARY + N), ... };
    vdests = {}
    for m in re.finditer(
        r'(gTilesetAnims_\w+_VDests)\[\]\s*=\s*\{([^}]+)\}',
        text, re.DOTALL
    ):
        tiles = [int(tm.group(1)) for tm in re.finditer(
            r'TILE_OFFSET_4BPP\(NUM_TILES_IN_PRIMARY\s*\+\s*(\d+)\)',
            m.group(2)
        )]
        vdests[m.group(1)] = tiles

    # 4. AppendTilesetAnimToBuffer calls
    queue_anims = []

    # Pattern A: fixed numeric VRAM dest
    for m in re.finditer(
        r'AppendTilesetAnimToBuffer\s*\(\s*(gTilesetAnims_\w+)\s*\[.*?\]\s*,'
        r'\s*\(u16 \*\)\s*\(BG_VRAM\s*\+\s*TILE_OFFSET_4BPP\s*\(\s*(\d+)\s*\)\)'
        r'\s*,\s*(\d+)\s*\*\s*TILE_SIZE_4BPP\s*\)',
        text
    ):
        queue_anims.append({
            'array':      m.group(1),
            'dest_tiles': [int(m.group(2))],
            'tile_count': int(m.group(3)),
        })

    # Pattern B: VDest array (broadcast)
    for m in re.finditer(
        r'AppendTilesetAnimToBuffer\s*\(\s*(gTilesetAnims_\w+)\s*\[.*?\]\s*,'
        r'\s*(gTilesetAnims_\w+_VDests)\s*\[.*?\]\s*,'
        r'\s*(\d+)\s*\*\s*TILE_SIZE_4BPP\s*\)',
        text
    ):
        tiles = vdests.get(m.group(2), [])
        queue_anims.append({
            'array':      m.group(1),
            'dest_tiles': tiles,
            'tile_count': int(m.group(3)),
        })

    return frame_files, sequences, queue_anims


# ── core builder ─────────────────────────────────────────────────────────────

def build_anim_atlas_for_tileset(
    ts_name, is_primary,
    pokeemerald_dir, out_dir,
    frame_files, sequences, queue_anims,
    fps, paired_primary="general"
):
    """
    For a single tileset:
      - Determine which queue_anim entries apply.
      - Find affected metatiles.
      - Render each metatile × each frame step.
      - Assemble and save the atlas PNGs.
      - Return the JSON config dict.
    """
    if is_primary:
        src_dir = pokeemerald_dir / "data" / "tilesets" / "primary" / ts_name.replace("primary_", "")
        # For primary anims: filter to only this primary's own animation sequences.
        prim_camel = snake_to_camel(ts_name.replace("primary_", ""))  # "General" or "Building"
        applicable = [q for q in queue_anims
                      if q['array'].startswith(f'gTilesetAnims_{prim_camel}_')]
    else:
        src_dir = pokeemerald_dir / "data" / "tilesets" / "secondary" / ts_name.replace("secondary_", "")
        # For secondary: pick animations whose name matches the tileset (CamelCase).
        # Skip _B variants (those are used by the GBA to stagger blooms; we use the main sequence).
        ts_short = snake_to_camel(ts_name.replace("secondary_", ""))  # e.g. "Mauville", "MauvilleGym"
        applicable = [q for q in queue_anims
                      if ts_short in q['array'] and not q['array'].endswith('_B')]

    tiles_png     = src_dir / "tiles.png"
    metatiles_bin = src_dir / "metatiles.bin"
    pal_dir       = src_dir / "palettes"

    if not tiles_png.exists() or not metatiles_bin.exists():
        print(f"  [SKIP] {ts_name}: tiles.png or metatiles.bin not found")
        return None

    palettes = [parse_pal(pal_dir / f"{i:02d}.pal") for i in range(16)]
    base_img = Image.open(tiles_png).convert("P")
    tiles_per_row = base_img.width // 8

    # For secondary tilesets: load paired primary so render_metatile can correctly
    # resolve primary tile cross-references (t_idx < 512) and secondary own tiles
    # (t_idx >= 512 → local = t_idx − 512).
    prim_img      = None
    prim_palettes = None
    prim_tpr      = None
    if not is_primary:
        prim_name = paired_primary
        prim_dir  = pokeemerald_dir / "data" / "tilesets" / "primary" / prim_name
        prim_png  = prim_dir / "tiles.png"
        if prim_png.exists():
            prim_img      = Image.open(prim_png).convert("P")
            prim_tpr      = prim_img.width // 8
            prim_palettes = [parse_pal(prim_dir / "palettes" / f"{i:02d}.pal") for i in range(16)]

    with open(metatiles_bin, "rb") as f:
        raw = f.read()
    num_metatiles = len(raw) // 16

    # Resolve each queue_anim to a list of { frame_imgs: [...], dest_tiles: [...], tile_count: int }
    # group_key → { frame_sequence_paths, dest_tiles, tile_count }
    anim_groups = []
    for qa in applicable:
        arr = qa['array']
        if arr not in sequences:
            print(f"  [WARN] sequence not found for {arr}")
            continue
        seq_names = sequences[arr]
        frame_imgs = []
        for fn in seq_names:
            if fn not in frame_files:
                print(f"  [WARN] frame file not found for {fn}")
                frame_imgs.append(None)
            else:
                p = frame_files[fn]
                if not p.exists():
                    print(f"  [WARN] PNG missing: {p}")
                    frame_imgs.append(None)
                else:
                    frame_imgs.append(Image.open(p).convert("P"))
        anim_groups.append({
            'array':      arr,
            'frame_imgs': frame_imgs,
            'dest_tiles': qa['dest_tiles'],
            'tile_count': qa['tile_count'],
        })

    if not anim_groups:
        print(f"  [SKIP] {ts_name}: no applicable animations found")
        return None

    # Find all animated metatile indices across all groups and dest_tiles.
    # For a VDest broadcast, each dest_tile slot covers its own metatile range.
    # We build: metatile_idx → list of (anim_group_idx, dest_tile_start)
    metatile_to_anims = {}  # metatile_idx → [ {group, dest_tile_start}, ... ]
    for gi, grp in enumerate(anim_groups):
        for dest in grp['dest_tiles']:
            affected = metatiles_referencing_range(raw, dest, grp['tile_count'])
            for m in affected:
                metatile_to_anims.setdefault(m, []).append({
                    'group_idx':       gi,
                    'dest_tile_start': dest,
                })

    if not metatile_to_anims:
        print(f"  [SKIP] {ts_name}: no metatiles reference animated tile ranges")
        return None

    # For each metatile × each animation group it participates in:
    # determine its frame sequence (which img to use for each frame step).
    # A single metatile may reference tiles from multiple anim groups (e.g. a tile
    # that has both water and sand_water_edge).  We handle this by patching ALL
    # active groups for each frame step.

    # First: determine max frames across all groups referenced by any metatile.
    max_frames = max(len(grp['frame_imgs']) for grp in anim_groups)

    sorted_metatiles = sorted(metatile_to_anims.keys())
    num_rows = len(sorted_metatiles)
    print(f"  {ts_name}: {num_rows} animated metatiles, {max_frames} max frames")

    atlas_w = max_frames * 16
    atlas_h = num_rows * 16
    atlas_bottom = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    atlas_top    = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))

    # Track per-metatile: row in atlas, num_frames for that metatile's animation.
    metatile_config = {}

    for row_idx, m_idx in enumerate(sorted_metatiles):
        anims = metatile_to_anims[m_idx]

        # Determine how many frames this metatile needs:
        # max over all groups it participates in.
        m_frame_count = max(len(anim_groups[a['group_idx']]['frame_imgs']) for a in anims)

        for frame_step in range(m_frame_count):
            # Build patched images for this frame step.
            # Primary-range destinations (< 512) patch into prim_patched;
            # secondary-range destinations (≥ 512, local = dest − 512) patch into sec_patched.
            sec_patched  = base_img.copy()
            prim_patched = prim_img.copy() if prim_img is not None else None

            for a in anims:
                grp = anim_groups[a['group_idx']]
                imgs = grp['frame_imgs']
                fi = frame_step % len(imgs)
                if imgs[fi] is not None:
                    dest = a['dest_tile_start']
                    if prim_img is not None and dest < 512:
                        # Primary tile position → patch the primary image copy
                        prim_patched = patch_src_img(
                            prim_patched, prim_tpr, dest, imgs[fi]
                        )
                    elif prim_img is not None:
                        # Secondary tile position → local = dest − 512
                        sec_patched = patch_src_img(
                            sec_patched, tiles_per_row, dest - 512, imgs[fi]
                        )
                    else:
                        sec_patched = patch_src_img(
                            sec_patched, tiles_per_row, dest, imgs[fi]
                        )

            b_tile, t_tile = render_metatile(
                m_idx, raw, sec_patched, palettes, tiles_per_row,
                primary_img=prim_patched, primary_palettes=prim_palettes, primary_tpr=prim_tpr,
            )
            px = frame_step * 16
            py = row_idx * 16
            atlas_bottom.paste(b_tile, (px, py), b_tile)
            atlas_top.paste(t_tile, (px, py), t_tile)

        metatile_config[str(m_idx)] = {
            "row":         row_idx,
            "frame_count": m_frame_count,
        }

    # Save atlases
    out_dir.mkdir(parents=True, exist_ok=True)
    bottom_path = out_dir / f"{ts_name}_anim_bottom.png"
    top_path    = out_dir / f"{ts_name}_anim_top.png"
    atlas_bottom.save(bottom_path, "PNG")
    atlas_top.save(top_path,    "PNG")
    print(f"  Saved {bottom_path.name}  ({atlas_w}×{atlas_h} px)")

    config = {
        "tileset":          ts_name,
        "fps":              fps,
        "bottom_atlas":     f"res://assets/tilesets/anim/{ts_name}_anim_bottom.png",
        "top_atlas":        f"res://assets/tilesets/anim/{ts_name}_anim_top.png",
        "animated_metatiles": metatile_config,
    }
    config_path = out_dir / f"{ts_name}_anim_config.json"
    config_path.write_text(json.dumps(config, indent=2))
    print(f"  Saved {config_path.name}  ({len(metatile_config)} metatile entries)")
    return config


# ── main ─────────────────────────────────────────────────────────────────────

def main():
    root_dir       = Path("c:/Users/levib/pokemon_projects/primal_harmony/primal-harmony")
    pokeemerald_dir = Path("C:/Users/levib/pokemon_projects/pokeemerald")
    out_dir        = root_dir / "assets" / "tilesets" / "anim"
    c_file         = pokeemerald_dir / "src" / "tileset_anims.c"

    print("Parsing tileset_anims.c...")
    frame_files, sequences, queue_anims = parse_tileset_anims_c(c_file, pokeemerald_dir)
    print(f"  {len(frame_files)} frame files, {len(sequences)} sequences, {len(queue_anims)} queue entries")

    # GBA animation timer rates:
    #   General callback: timer % 16 at 60 fps → 3.75 fps
    #   Building callback: timer % 8 at 60 fps → 7.50 fps
    GENERAL_FPS  = 60.0 / 16.0
    BUILDING_FPS = 60.0 / 8.0

    # (ts_name, is_primary, fps, paired_primary)
    tilesets = [
        # Primaries
        ("primary_general",  True,  GENERAL_FPS,  "general"),
        ("primary_building", True,  BUILDING_FPS, "building"),
        # Secondaries – general-paired (outdoor maps)
        ("secondary_battle_frontier_outside_east", False, GENERAL_FPS, "general"),
        ("secondary_battle_frontier_outside_west", False, GENERAL_FPS, "general"),
        ("secondary_battle_palace",   False, GENERAL_FPS, "general"),
        ("secondary_bike_shop",       False, GENERAL_FPS, "general"),
        ("secondary_cave",            False, GENERAL_FPS, "general"),
        ("secondary_dewford",         False, GENERAL_FPS, "general"),
        ("secondary_ever_grande",     False, GENERAL_FPS, "general"),
        ("secondary_facility",        False, GENERAL_FPS, "general"),
        ("secondary_fallarbor",       False, GENERAL_FPS, "general"),
        ("secondary_fortree",         False, GENERAL_FPS, "general"),
        ("secondary_inside_of_truck", False, GENERAL_FPS, "general"),
        ("secondary_inside_ship",     False, GENERAL_FPS, "general"),
        ("secondary_island_harbor",   False, GENERAL_FPS, "general"),
        ("secondary_lavaridge",       False, GENERAL_FPS, "general"),
        ("secondary_lilycove",        False, GENERAL_FPS, "general"),
        ("secondary_mauville",        False, GENERAL_FPS, "general"),
        ("secondary_meteor_falls",    False, GENERAL_FPS, "general"),
        ("secondary_mirage_tower",    False, GENERAL_FPS, "general"),
        ("secondary_mossdeep",        False, GENERAL_FPS, "general"),
        ("secondary_navel_rock",      False, GENERAL_FPS, "general"),
        ("secondary_pacifidlog",      False, GENERAL_FPS, "general"),
        ("secondary_petalburg",       False, GENERAL_FPS, "general"),
        ("secondary_rustboro",        False, GENERAL_FPS, "general"),
        ("secondary_rusturf_tunnel",  False, GENERAL_FPS, "general"),
        ("secondary_slateport",       False, GENERAL_FPS, "general"),
        ("secondary_sootopolis",      False, GENERAL_FPS, "general"),
        ("secondary_underwater",      False, GENERAL_FPS, "general"),
        # Secondaries – building-paired (indoor maps)
        ("secondary_battle_arena",             False, BUILDING_FPS, "building"),
        ("secondary_battle_dome",              False, BUILDING_FPS, "building"),
        ("secondary_battle_factory",           False, BUILDING_FPS, "building"),
        ("secondary_battle_frontier",          False, BUILDING_FPS, "building"),
        ("secondary_battle_frontier_ranking_hall", False, BUILDING_FPS, "building"),
        ("secondary_battle_pike",              False, BUILDING_FPS, "building"),
        ("secondary_battle_pyramid",           False, BUILDING_FPS, "building"),
        ("secondary_battle_tent",              False, BUILDING_FPS, "building"),
        ("secondary_brendans_mays_house",      False, BUILDING_FPS, "building"),
        ("secondary_cable_club",               False, BUILDING_FPS, "building"),
        ("secondary_contest",                  False, BUILDING_FPS, "building"),
        ("secondary_dewford_gym",              False, BUILDING_FPS, "building"),
        ("secondary_elite_four",               False, BUILDING_FPS, "building"),
        ("secondary_fortree_gym",              False, BUILDING_FPS, "building"),
        ("secondary_generic_building",         False, BUILDING_FPS, "building"),
        ("secondary_lab",                      False, BUILDING_FPS, "building"),
        ("secondary_lavaridge_gym",            False, BUILDING_FPS, "building"),
        ("secondary_lilycove_museum",          False, BUILDING_FPS, "building"),
        ("secondary_mauville_game_corner",     False, BUILDING_FPS, "building"),
        ("secondary_mauville_gym",             False, BUILDING_FPS, "building"),
        ("secondary_mossdeep_game_corner",     False, BUILDING_FPS, "building"),
        ("secondary_mossdeep_gym",             False, BUILDING_FPS, "building"),
        ("secondary_mystery_events_house",     False, BUILDING_FPS, "building"),
        ("secondary_oceanic_museum",           False, BUILDING_FPS, "building"),
        ("secondary_petalburg_gym",            False, BUILDING_FPS, "building"),
        ("secondary_pokemon_center",           False, BUILDING_FPS, "building"),
        ("secondary_pokemon_day_care",         False, BUILDING_FPS, "building"),
        ("secondary_pokemon_fan_club",         False, BUILDING_FPS, "building"),
        ("secondary_pokemon_school",           False, BUILDING_FPS, "building"),
        ("secondary_pretty_petal_flower_shop", False, BUILDING_FPS, "building"),
        ("secondary_rustboro_gym",             False, BUILDING_FPS, "building"),
        ("secondary_seashore_house",           False, BUILDING_FPS, "building"),
        ("secondary_shop",                     False, BUILDING_FPS, "building"),
        ("secondary_sootopolis_gym",           False, BUILDING_FPS, "building"),
        ("secondary_trainer_hill",             False, BUILDING_FPS, "building"),
        ("secondary_trick_house_puzzle",       False, BUILDING_FPS, "building"),
        ("secondary_union_room",               False, BUILDING_FPS, "building"),
        ("secondary_unused_1",                 False, BUILDING_FPS, "building"),
        ("secondary_unused_2",                 False, BUILDING_FPS, "building"),
        # Secret base variants – no animations (will be skipped automatically)
        ("secondary_secret_base_blue_cave",   False, GENERAL_FPS, "secret_base"),
        ("secondary_secret_base_brown_cave",  False, GENERAL_FPS, "secret_base"),
        ("secondary_secret_base_red_cave",    False, GENERAL_FPS, "secret_base"),
        ("secondary_secret_base_shrub",       False, GENERAL_FPS, "secret_base"),
        ("secondary_secret_base_tree",        False, GENERAL_FPS, "secret_base"),
        ("secondary_secret_base_yellow_cave", False, GENERAL_FPS, "secret_base"),
    ]

    for ts_name, is_primary, fps, paired_primary in tilesets:
        print(f"\nProcessing {ts_name}...")
        build_anim_atlas_for_tileset(
            ts_name, is_primary,
            pokeemerald_dir, out_dir,
            frame_files, sequences, queue_anims,
            fps, paired_primary,
        )

    print("\nDone.")


if __name__ == "__main__":
    main()
