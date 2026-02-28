import os
from pathlib import Path
import struct
from PIL import Image

def parse_pal(pal_path: Path):
    colors = []
    if not pal_path.exists():
        return [(255, 0, 255)] * 16
    with open(pal_path, 'r') as f:
        lines = f.read().splitlines()
    for line in lines[3:]:
        if not line.strip(): continue
        parts = line.split()
        if len(parts) == 3:
            r, g, b = map(int, parts)
            colors.append((r, g, b))
    while len(colors) < 16:
        colors.append((255, 0, 255))
    return colors[:16]

def extract_gba_tile(src_img, x, y, palette, x_flip, y_flip):
    """Extracts an 8x8 tile from the given tile coordinate in src_img, applying the palette."""
    tile = Image.new("RGBA", (8, 8), (0,0,0,0))
    pixels = tile.load()

    px = x * 8
    py = y * 8

    for ty in range(8):
        for tx in range(8):
            src_x = px + tx
            src_y = py + ty

            if src_x >= src_img.width or src_y >= src_img.height:
                continue

            idx = src_img.getpixel((src_x, src_y))
            if idx > 0 and idx < 16:
                r, g, b = palette[idx]

                dest_x = (7 - tx) if x_flip else tx
                dest_y = (7 - ty) if y_flip else ty

                pixels[dest_x, dest_y] = (r, g, b, 255)
    return tile

def process_tileset(tilesets_dir: Path, pokeemerald_dir: Path, ts_name: str, is_primary: bool,
                    paired_primary: str = "general",
                    src_dir_override: Path = None,
                    metatiles_bin_override: Path = None):
    """
    Render a metatile atlas for the given tileset.

    For secondary tilesets, metatile tile attributes use GLOBAL VRAM tile indices:
      - t_idx < 512  → primary tile reference  → fetch from primary tiles.png
      - t_idx >= 512 → secondary own tile       → local = t_idx - 512, fetch from secondary tiles.png

    paired_primary: the primary tileset name (subdirectory under primary/) to use for
                    cross-references when rendering a secondary tileset.
    """
    if src_dir_override is not None:
        src_dir = src_dir_override
    elif is_primary:
        src_dir = pokeemerald_dir / "data" / "tilesets" / "primary" / ts_name.replace("primary_", "")
    else:
        src_dir = pokeemerald_dir / "data" / "tilesets" / "secondary" / ts_name.replace("secondary_", "")

    tiles_png = src_dir / "tiles.png"
    metatiles_bin = metatiles_bin_override if metatiles_bin_override is not None else (src_dir / "metatiles.bin")
    pal_dir = src_dir / "palettes"

    if not tiles_png.exists() or not metatiles_bin.exists():
        return

    print(f"Building Godot Metatiles for {ts_name}...")

    palettes = [parse_pal(pal_dir / f"{i:02d}.pal") for i in range(16)]
    src_img = Image.open(tiles_png).convert("P")
    tiles_per_row = src_img.width // 8

    # For secondary tilesets: load the paired primary for primary tile cross-references.
    prim_img      = None
    prim_palettes = None
    prim_tpr      = 0
    if not is_primary:
        prim_dir      = pokeemerald_dir / "data" / "tilesets" / "primary" / paired_primary
        prim_tiles    = prim_dir / "tiles.png"
        prim_pal_dir  = prim_dir / "palettes"
        if prim_tiles.exists():
            prim_img      = Image.open(prim_tiles).convert("P")
            prim_tpr      = prim_img.width // 8
            prim_palettes = [parse_pal(prim_pal_dir / f"{i:02d}.pal") for i in range(16)]
        else:
            print(f"  [WARN] Paired primary tiles not found: {prim_tiles}")

    with open(metatiles_bin, "rb") as f:
        data = f.read()

    num_metatiles = len(data) // 16

    cols = 8
    rows = (num_metatiles + cols - 1) // cols

    out_bottom = Image.new("RGBA", (cols * 16, rows * 16), (0,0,0,0))
    out_top    = Image.new("RGBA", (cols * 16, rows * 16), (0,0,0,0))

    for m in range(num_metatiles):
        layer_tiles = struct.unpack("<8H", data[m*16 : (m+1)*16])

        mx = (m % cols) * 16
        my = (m // cols) * 16

        for out_img, offset in ((out_bottom, 0), (out_top, 4)):
            for i in range(4):
                val     = layer_tiles[i + offset]
                t_idx   = val & 0x03FF
                h_flip  = (val & 0x0400) != 0
                v_flip  = (val & 0x0800) != 0
                pal_idx = (val & 0xF000) >> 12

                if not is_primary and t_idx >= 512:
                    # Secondary own tile: GLOBAL index → LOCAL index
                    local = t_idx - 512
                    sub_x = local % tiles_per_row
                    sub_y = local // tiles_per_row
                    use_img = src_img
                    use_pal = palettes
                elif not is_primary and prim_img is not None:
                    # Primary tile reference from a secondary metatile.
                    # GBA palette bank ownership: primary owns banks 0-5, secondary owns 6+.
                    # A secondary metatile can cross-reference a primary tile but still use
                    # a secondary palette bank (pal_idx >= 6), so select accordingly.
                    sub_x = t_idx % prim_tpr
                    sub_y = t_idx // prim_tpr
                    use_img = prim_img
                    use_pal = palettes if pal_idx >= 6 else prim_palettes
                else:
                    # Primary tileset (or secondary without a paired primary)
                    sub_x = t_idx % tiles_per_row
                    sub_y = t_idx // tiles_per_row
                    use_img = src_img
                    use_pal = palettes

                sub_tile = extract_gba_tile(use_img, sub_x, sub_y, use_pal[pal_idx], h_flip, v_flip)

                dx = mx + (8 if i % 2 == 1 else 0)
                dy = my + (8 if i >= 2 else 0)

                out_img.paste(sub_tile, (dx, dy), sub_tile)

    out_bottom.save(tilesets_dir / f"{ts_name}_bottom.png", "PNG")
    out_top.save(tilesets_dir / f"{ts_name}_top.png", "PNG")
    print(f"  -> Generated {num_metatiles} metatiles.")

def main():
    root_dir = Path("c:/Users/levib/pokemon_projects/primal_harmony/primal-harmony")
    pokeemerald_dir = Path("C:/Users/levib/pokemon_projects/pokeemerald")
    tilesets_dir = root_dir / "assets" / "tilesets"

    # ── Primaries ────────────────────────────────────────────────────────────
    process_tileset(tilesets_dir, pokeemerald_dir, "primary_general",     True)
    process_tileset(tilesets_dir, pokeemerald_dir, "primary_building",    True)
    process_tileset(tilesets_dir, pokeemerald_dir, "primary_secret_base", True)

    # ── Secondaries paired with primary_general (outdoor maps) ───────────────
    for sec in [
        "battle_frontier_outside_east", "battle_frontier_outside_west",
        "battle_palace", "bike_shop", "cave", "dewford", "ever_grande",
        "facility", "fallarbor", "fortree", "inside_of_truck", "inside_ship",
        "island_harbor", "lavaridge", "lilycove", "mauville", "meteor_falls",
        "mirage_tower", "mossdeep", "navel_rock", "pacifidlog", "petalburg",
        "rustboro", "rusturf_tunnel", "slateport", "sootopolis", "underwater",
    ]:
        process_tileset(tilesets_dir, pokeemerald_dir, f"secondary_{sec}", False, "general")

    # ── Secondaries paired with primary_building (indoor maps) ───────────────
    for sec in [
        "battle_arena", "battle_dome", "battle_factory", "battle_frontier",
        "battle_frontier_ranking_hall", "battle_pike", "battle_pyramid",
        "battle_tent", "brendans_mays_house", "cable_club", "contest",
        "dewford_gym", "elite_four", "fortree_gym", "generic_building",
        "lab", "lavaridge_gym", "lilycove_museum", "mauville_game_corner",
        "mauville_gym", "mossdeep_game_corner", "mossdeep_gym",
        "mystery_events_house", "oceanic_museum", "petalburg_gym",
        "pokemon_center", "pokemon_day_care", "pokemon_fan_club",
        "pokemon_school", "pretty_petal_flower_shop", "rustboro_gym",
        "seashore_house", "shop", "sootopolis_gym", "trainer_hill",
        "trick_house_puzzle", "union_room", "unused_1", "unused_2",
    ]:
        process_tileset(tilesets_dir, pokeemerald_dir, f"secondary_{sec}", False, "building")

    # ── Secret base variants (shared metatiles.bin, per-variant tiles) ───────
    sb_sec = pokeemerald_dir / "data" / "tilesets" / "secondary" / "secret_base"
    for variant in ["blue_cave", "brown_cave", "red_cave", "shrub", "tree", "yellow_cave"]:
        process_tileset(
            tilesets_dir, pokeemerald_dir,
            f"secondary_secret_base_{variant}", False, "secret_base",
            src_dir_override=sb_sec / variant,
            metatiles_bin_override=sb_sec / "metatiles.bin",
        )

if __name__ == "__main__":
    main()
