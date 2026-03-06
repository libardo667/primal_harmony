import os
import shutil
import subprocess
import argparse
import tempfile
from pathlib import Path

# Paths
POKEEMERALD_DIR = Path("C:/Users/levib/pokemon_projects/pokeemerald")
OUTPUT_BASE_DIR = Path("C:/Users/levib/pokemon_projects/primal_harmony/primal-harmony/assets/tilesets/layers")
BEHAVIORS_HEADER = POKEEMERALD_DIR / "include" / "constants" / "metatile_behaviors.h"

# Secret base variants share metatiles.bin / metatile_attributes.bin from the
# parent directory but have per-variant tiles.png + palettes/.
SECRET_BASE_VARIANTS = ["blue_cave", "brown_cave", "red_cave", "shrub", "tree", "yellow_cave"]

def run_wsl_command(cmd_list):
    """Run a command in WSL and return the output."""
    def to_wsl_path(win_path):
        p = str(win_path).replace('\\', '/')
        if p[1:3] == ':/':
            p = f"/mnt/{p[0].lower()}{p[2:]}"
        return p

    wsl_cmd = ["wsl"] + [to_wsl_path(c) if isinstance(c, Path) or (isinstance(c, str) and (':\\' in c or ':/' in c)) else c for c in cmd_list]
    print(f"Executing: {' '.join(wsl_cmd)}")
    # MSYS_NO_PATHCONV prevents Git Bash from mangling /mnt/... paths.
    env = os.environ.copy()
    env["MSYS_NO_PATHCONV"] = "1"
    result = subprocess.run(wsl_cmd, capture_output=True, text=True, env=env)
    if result.returncode != 0:
        print(f"Error executing command: {result.stderr}")
    return result


def decompile_tileset(ts_name, is_primary, primary_name="general", variant_of=None):
    """Decompile a single tileset via porytiles.

    Args:
        ts_name: Tileset name (e.g. "general", "cave", "blue_cave").
        is_primary: True for primary tilesets.
        primary_name: Paired primary name (for secondary decompilation).
        variant_of: If set, the parent secondary tileset name whose
            metatiles.bin/metatile_attributes.bin should be used (e.g. "secret_base").
            ts_name is then treated as a subdirectory of that parent.
    """
    category = "primary" if is_primary else "secondary"

    if variant_of:
        # Variant: combine parent's metatiles + variant's tiles/palettes in a temp dir.
        parent_dir = POKEEMERALD_DIR / "data" / "tilesets" / category / variant_of
        variant_dir = parent_dir / ts_name
        output_name = f"{category}_{variant_of}_{ts_name}"

        if not variant_dir.exists():
            print(f"Error: Variant dir {variant_dir} does not exist.")
            return
        if not parent_dir.exists():
            print(f"Error: Parent dir {parent_dir} does not exist.")
            return

        ts_out_dir = OUTPUT_BASE_DIR / output_name
        ts_out_dir.mkdir(parents=True, exist_ok=True)

        # Build a temp directory with the combined structure porytiles expects.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            shutil.copy2(parent_dir / "metatiles.bin", tmp_path / "metatiles.bin")
            shutil.copy2(parent_dir / "metatile_attributes.bin", tmp_path / "metatile_attributes.bin")
            shutil.copy2(variant_dir / "tiles.png", tmp_path / "tiles.png")
            if (variant_dir / "tiles.4bpp").exists():
                shutil.copy2(variant_dir / "tiles.4bpp", tmp_path / "tiles.4bpp")
            shutil.copytree(variant_dir / "palettes", tmp_path / "palettes")

            ts_prim_dir = POKEEMERALD_DIR / "data" / "tilesets" / "primary" / primary_name
            cmd = ["porytiles", "decompile-secondary", "-o", ts_out_dir, tmp_path, ts_prim_dir, BEHAVIORS_HEADER]
            run_wsl_command(cmd)
    else:
        ts_src_dir = POKEEMERALD_DIR / "data" / "tilesets" / category / ts_name
        output_name = f"{category}_{ts_name}"
        ts_out_dir = OUTPUT_BASE_DIR / output_name

        if not ts_src_dir.exists():
            print(f"Error: Tileset source dir {ts_src_dir} does not exist.")
            return

        ts_out_dir.mkdir(parents=True, exist_ok=True)

        if is_primary:
            cmd = ["porytiles", "decompile-primary", "-o", ts_out_dir, ts_src_dir, BEHAVIORS_HEADER]
        else:
            ts_prim_dir = POKEEMERALD_DIR / "data" / "tilesets" / "primary" / primary_name
            cmd = ["porytiles", "decompile-secondary", "-o", ts_out_dir, ts_src_dir, ts_prim_dir, BEHAVIORS_HEADER]

        run_wsl_command(cmd)


def main():
    parser = argparse.ArgumentParser(description="Decompile pokeemerald tilesets using Porytiles in WSL.")
    parser.add_argument("--all-primaries", action="store_true", help="Decompile all primary tilesets")
    parser.add_argument("--all-secondaries", action="store_true", help="Decompile all secondary tilesets (including secret base variants)")
    parser.add_argument("--all", action="store_true", help="Decompile every tileset")
    parser.add_argument("--tileset", type=str, help="Decompile a specific tileset")
    parser.add_argument("--secondary", action="store_true", help="Flag if --tileset is a secondary tileset")
    parser.add_argument("--primary", type=str, default="general", help="Primary tileset name for secondary decompilation")
    parser.add_argument("--variant-of", type=str, default=None,
                        help="Parent secondary tileset name for variant decompilation (e.g. 'secret_base')")

    args = parser.parse_args()

    do_primaries = args.all_primaries or args.all
    do_secondaries = args.all_secondaries or args.all

    if do_primaries:
        prim_dir = POKEEMERALD_DIR / "data" / "tilesets" / "primary"
        for ts in sorted(prim_dir.iterdir()):
            if ts.is_dir() and (ts / "tiles.png").exists():
                print(f"\n=== Processing primary: {ts.name} ===")
                decompile_tileset(ts.name, True)

    if do_secondaries:
        sec_dir = POKEEMERALD_DIR / "data" / "tilesets" / "secondary"
        for ts in sorted(sec_dir.iterdir()):
            if not ts.is_dir() or not (ts / "tiles.png").exists():
                continue
            # Secret base has variants — handle specially.
            if ts.name == "secret_base":
                for variant in SECRET_BASE_VARIANTS:
                    print(f"\n=== Processing secondary: secret_base/{variant} ===")
                    decompile_tileset(variant, False, "secret_base", variant_of="secret_base")
                continue
            print(f"\n=== Processing secondary: {ts.name} ===")
            # Determine paired primary from tileset name.
            # building-paired secondaries use primary "building", all others use "general".
            primary = _get_paired_primary(ts.name)
            decompile_tileset(ts.name, False, primary)

    if args.tileset and not do_primaries and not do_secondaries:
        is_primary = not args.secondary
        decompile_tileset(args.tileset, is_primary, args.primary, variant_of=args.variant_of)

    if not args.tileset and not do_primaries and not do_secondaries:
        print("No arguments provided. Use --all, --all-primaries, --all-secondaries, or --tileset <name>.")


# Secondary tilesets paired with primary_building (from build_godot_tilesets.py).
_BUILDING_PAIRED = {
    "battle_arena", "battle_dome", "battle_factory", "battle_frontier",
    "battle_frontier_outside_east", "battle_frontier_outside_west",
    "battle_frontier_ranking_hall", "battle_palace", "battle_pike",
    "battle_pyramid", "battle_tent", "brendans_mays_house", "cable_club",
    "contest", "dewford_gym", "elite_four", "fortree_gym", "generic_building",
    "lab", "lavaridge_gym", "lilycove_museum", "mauville_game_corner",
    "mauville_gym", "mossdeep_game_corner", "mossdeep_gym",
    "mystery_events_house", "oceanic_museum", "petalburg_gym",
    "pokemon_center", "pokemon_day_care", "pokemon_fan_club",
    "pokemon_school", "pretty_petal_flower_shop", "rustboro_gym",
    "seashore_house", "shop", "sootopolis_gym", "trainer_hill",
    "trick_house_puzzle", "union_room", "unused_1", "unused_2",
}

def _get_paired_primary(sec_name: str) -> str:
    """Return the paired primary tileset name for a secondary."""
    if sec_name in _BUILDING_PAIRED:
        return "building"
    return "general"


if __name__ == "__main__":
    main()
