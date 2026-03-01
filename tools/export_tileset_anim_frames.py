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
    Parse tileset_anims.c (or its cleaned version).

    Returns:
      frame_files  : { 'gTilesetAnims_Foo_FrameN': Path('...png') }
      sequences    : { 'gTilesetAnims_Foo': ['gTilesetAnims_Foo_Frame0', ...] }
      queue_anims  : [ { 'array': str, 'dest_tiles': [int,...], 'tile_count': int } ]
                     dest_tiles are tileset-relative tile indices.
    """
    # Prefer the cleaned version if it exists
    cleaned_file = c_file.parent.parent.parent / "primal-harmony" / "tools" / "tileset_anims_cleaned.c"
    if cleaned_file.exists():
        print(f"  Using cleaned source: {cleaned_file}")
        text = cleaned_file.read_text(encoding='utf-8', errors='replace')
    else:
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
    vdests = {}
    # Handles both TILE_OFFSET_4BPP(NUM_TILES_IN_PRIMARY + N) and expanded (0x06000000 + ((512 + N) * 32))
    for m in re.finditer(
        r'(gTilesetAnims_\w+_VDests)\[\]\s*=\s*\{([^}]+)\}',
        text, re.DOTALL
    ):
        name = m.group(1)
        tiles = []
        for line in m.group(2).split(','):
            line = line.strip()
            if not line: continue
            
            # Case 1: Original macro
            ov = re.search(r'TILE_OFFSET_4BPP\(NUM_TILES_IN_PRIMARY\s*\+\s*(\d+)\)', line)
            if ov:
                tiles.append(int(ov.group(1)))
                continue
                
            # Case 2: Expanded macro (0x06000000 + ((512 + N) * 32))
            ev = re.search(r'0x06000000\s*\+\s*\(\((512\s*\+\s*\d+)\)\s*\*\s*32\)', line)
            if ev:
                # We want just the N part from (512 + N)
                n_match = re.search(r'512\s*\+\s*(\d+)', ev.group(1))
                if n_match:
                    tiles.append(int(n_match.group(1)))
                    continue
            
            # Case 3: Simple expanded (0x06000000 + (N * 32)) - for primaries
            sv = re.search(r'0x06000000\s*\+\s*\(\(([^)]+)\)\s*\*\s*32\)', line)
            if sv:
                try:
                    addr_offset = eval(sv.group(1))
                    tiles.append(addr_offset)
                except:
                    pass
                    
        vdests[name] = tiles

    # 4. AppendTilesetAnimToBuffer calls
    queue_anims = []

    def parse_dest(call_text):
        # Expanded: (u16 *)(0x06000000 + ((508) * 32))
        # Support newlines/whitespace with \s*
        m = re.search(r'0x06000000\s*\+\s*\(\s*\(([^)]+)\)\s*\*\s*32\s*\)', call_text)
        if m:
            try: return eval(m.group(1).replace('\n', ' '))
            except: pass
            
        # Original: (u16 *)(BG_VRAM + TILE_OFFSET_4BPP(508))
        m = re.search(r'TILE_OFFSET_4BPP\s*\(\s*(\d+)\s*\)', call_text)
        if m: return int(m.group(1))
        return None

    def parse_count(call_text):
        # Expanded: 4 * 32
        m = re.search(r',\s*(\d+)\s*\*\s*32\s*\)', call_text)
        if m: return int(m.group(1))
        # Original: 4 * TILE_SIZE_4BPP
        m = re.search(r',\s*(\d+)\s*\*\s*TILE_SIZE_4BPP\s*\)', call_text)
        if m: return int(m.group(1))
        return None

    # Pattern A: fixed numeric VRAM dest
    # AppendTilesetAnimToBuffer(gTilesetAnims_General_Flower[i], (u16 *)(0x06000000 + ((508) * 32)), 4 * 32);
    for m in re.finditer(r'AppendTilesetAnimToBuffer\s*\(([^;]+);', text):
        call = m.group(1)
        if '[' not in call: continue # Likely a VDest version or something else
        
        arr_m = re.search(r'(gTilesetAnims_\w+)', call)
        if not arr_m: continue
        
        dest = parse_dest(call)
        count = parse_count(call + ")") # Add closing parens if missing from group
        
        if dest is not None and count is not None:
            queue_anims.append({
                'array':      arr_m.group(1),
                'dest_tiles': [dest],
                'tile_count': count,
            })

    # Pattern B: VDest array (broadcast)
    for m in re.finditer(
        r'AppendTilesetAnimToBuffer\s*\(\s*(gTilesetAnims_\w+)\s*\[.*?\]\s*,'
        r'\s*(gTilesetAnims_\w+_VDests)\s*\[.*?\]\s*,'
        r'\s*(\d+)\s*\*\s*32\s*\)',
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
      - Render each metatile × each frame step into 3 Porytile-compatible layers.
      - Assemble and save the atlas PNGs.
      - Return the JSON config dict.
    """
    if is_primary:
        src_dir = pokeemerald_dir / "data" / "tilesets" / "primary" / ts_name.replace("primary_", "")
        prim_camel = snake_to_camel(ts_name.replace("primary_", ""))
        applicable = [q for q in queue_anims if q['array'].startswith(f'gTilesetAnims_{prim_camel}_')]
    else:
        src_dir = pokeemerald_dir / "data" / "tilesets" / "secondary" / ts_name.replace("secondary_", "")
        ts_short = snake_to_camel(ts_name.replace("secondary_", ""))
        applicable = [q for q in queue_anims if ts_short in q['array'] and not q['array'].endswith('_B')]

    # Check for Porytiles-decompile output
    layers_base = out_dir.parent / "layers" / ts_name
    bottom_png = layers_base / "bottom.png"
    middle_png = layers_base / "middle.png"
    top_png    = layers_base / "top.png"

    if not bottom_png.exists():
        print(f"  [SKIP] {ts_name}: Porytile layers not found at {bottom_png}")
        return None

    # Load Porytile layers (8-column metatile sheets)
    pory_bottom = Image.open(bottom_png).convert("RGBA")
    pory_middle = Image.open(middle_png).convert("RGBA")
    pory_top    = Image.open(top_png).convert("RGBA")

    # Original GBA data for tile references
    tiles_png     = src_dir / "tiles.png"
    metatiles_bin = src_dir / "metatiles.bin"
    pal_dir       = src_dir / "palettes"

    if not tiles_png.exists() or not metatiles_bin.exists():
        print(f"  [SKIP] {ts_name}: tiles.png or metatiles.bin not found")
        return None

    palettes = [parse_pal(pal_dir / f"{i:02d}.pal") for i in range(16)]
    base_img = Image.open(tiles_png).convert("P")
    tiles_per_row = base_img.width // 8

    # Secondary paired primary for tile resolution
    prim_img = None; prim_palettes = None; prim_tpr = None
    if not is_primary:
        prim_dir = pokeemerald_dir / "data" / "tilesets" / "primary" / paired_primary
        prim_png = prim_dir / "tiles.png"
        if prim_png.exists():
            prim_img = Image.open(prim_png).convert("P")
            prim_tpr = prim_img.width // 8
            prim_palettes = [parse_pal(prim_dir / "palettes" / f"{i:02d}.pal") for i in range(16)]

    with open(metatiles_bin, "rb") as f:
        raw = f.read()

    # Resolve sequences
    anim_groups = []
    for qa in applicable:
        arr = qa['array']
        if arr not in sequences: continue
        frame_imgs = []
        for fn in sequences[arr]:
            if fn not in frame_files: frame_imgs.append(None)
            else:
                p = frame_files[fn]
                frame_imgs.append(Image.open(p).convert("P") if p.exists() else None)
        anim_groups.append({
            'array': arr,
            'frame_imgs': frame_imgs,
            'dest_tiles': qa['dest_tiles'],
            'tile_count': qa['tile_count'],
        })

    if not anim_groups:
        print(f"  [SKIP] {ts_name}: no animations")
        return None

    # metatile_idx -> [ {group_idx, dest_tile_start}, ... ]
    metatile_to_anims = {}
    for gi, grp in enumerate(anim_groups):
        for dest in grp['dest_tiles']:
            affected = metatiles_referencing_range(raw, dest, grp['tile_count'])
            for m in affected:
                metatile_to_anims.setdefault(m, []).append({'group_idx': gi, 'dest_tile_start': dest})

    if not metatile_to_anims:
        print(f"  [SKIP] {ts_name}: no animated metatiles found")
        return None

    max_frames = max(len(grp['frame_imgs']) for grp in anim_groups)
    sorted_metatiles = sorted(metatile_to_anims.keys())
    num_rows = len(sorted_metatiles)
    print(f"  {ts_name}: {num_rows} animated metatiles, {max_frames} max frames")

    atlas_w = max_frames * 16
    atlas_h = num_rows * 16
    atlas_b = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    atlas_m = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    atlas_t = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))

    metatile_config = {}

    for row_idx, m_idx in enumerate(sorted_metatiles):
        anims = metatile_to_anims[m_idx]
        m_frame_count = max(len(anim_groups[a['group_idx']]['frame_imgs']) for a in anims)

        # 1. Capture "Pixel Layer Template" from frame 0 Porymap output
        # Metatile 'idx' is at (idx % 8 * 16, idx // 8 * 16) in Porymap PNGs
        px0, py0 = (m_idx % 8) * 16, (m_idx // 8) * 16
        template_b = pory_bottom.crop((px0, py0, px0+16, py0+16))
        template_m = pory_middle.crop((px0, py0, px0+16, py0+16))
        template_t = pory_top.crop((px0, py0, px0+16, py0+16))
        
        # layer_map[x,y] = 0 (bottom), 1 (middle), 2 (top), or None
        layer_map = {}
        for y in range(16):
            for x in range(16):
                # Priority: Top > Middle > Bottom
                # Porytiles often uses opaque magenta (255, 0, 255) as background.
                def is_real_pixel(px):
                    return px[3] > 0 and not (px[0] == 255 and px[1] == 0 and px[2] == 255)

                if is_real_pixel(template_t.getpixel((x, y))): layer_map[(x,y)] = 2
                elif is_real_pixel(template_m.getpixel((x, y))): layer_map[(x,y)] = 1
                elif is_real_pixel(template_b.getpixel((x, y))): layer_map[(x,y)] = 0
                else: layer_map[(x,y)] = None

        for frame_step in range(m_frame_count):
            sec_patched  = base_img.copy()
            prim_patched = prim_img.copy() if prim_img is not None else None

            for a in anims:
                grp = anim_groups[a['group_idx']]
                imgs = grp['frame_imgs']
                fi = frame_step % len(imgs)
                if imgs[fi] is not None:
                    dest = a['dest_tile_start']
                    if prim_img is not None and dest < 512:
                        prim_patched = patch_src_img(prim_patched, prim_tpr, dest, imgs[fi])
                    elif prim_img is not None:
                        sec_patched = patch_src_img(sec_patched, tiles_per_row, dest - 512, imgs[fi])
                    else:
                        sec_patched = patch_src_img(sec_patched, tiles_per_row, dest, imgs[fi])

            # Render ALL 8 GBA layers into a single 16x16 reference image for this frame
            ref_rgba = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
            b_tile, t_tile = render_metatile(
                m_idx, raw, sec_patched, palettes, tiles_per_row,
                primary_img=prim_patched, primary_palettes=prim_palettes, primary_tpr=prim_tpr,
            )
            # Composite them (Top usually covers Bottom)
            ref_rgba.paste(b_tile, (0, 0), b_tile)
            ref_rgba.paste(t_tile, (0, 0), t_tile)

            # 2. Distribute ref_rgba pixels into 3 layers based on Pixel Layer Template
            fb = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
            fm = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
            ft = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
            
            ref_pix = ref_rgba.load()
            fb_pix, fm_pix, ft_pix = fb.load(), fm.load(), ft.load()
            
            for y in range(16):
                for x in range(16):
                    l_idx = layer_map[(x,y)]
                    if l_idx is None: continue
                    rgba = ref_pix[x,y]
                    if l_idx == 0: fb_pix[x,y] = rgba
                    elif l_idx == 1: fm_pix[x,y] = rgba
                    elif l_idx == 2: ft_pix[x,y] = rgba

            # Paste into atlas
            ax, ay = frame_step * 16, row_idx * 16
            atlas_b.paste(fb, (ax, ay), fb)
            atlas_m.paste(fm, (ax, ay), fm)
            atlas_t.paste(ft, (ax, ay), ft)

        metatile_config[str(m_idx)] = {"row": row_idx, "frame_count": m_frame_count}

    out_dir.mkdir(parents=True, exist_ok=True)
    atlas_b.save(out_dir / f"{ts_name}_anim_bottom.png", "PNG")
    atlas_m.save(out_dir / f"{ts_name}_anim_middle.png", "PNG")
    atlas_t.save(out_dir / f"{ts_name}_anim_top.png",    "PNG")

    config = {
        "tileset": ts_name,
        "fps": fps,
        "bottom_atlas": f"res://assets/tilesets/anim/{ts_name}_anim_bottom.png",
        "middle_atlas": f"res://assets/tilesets/anim/{ts_name}_anim_middle.png",
        "top_atlas":    f"res://assets/tilesets/anim/{ts_name}_anim_top.png",
        "animated_metatiles": metatile_config,
    }
    (out_dir / f"{ts_name}_anim_config.json").write_text(json.dumps(config, indent=2))
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
