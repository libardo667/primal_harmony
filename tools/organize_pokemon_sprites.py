import os
import json
import shutil
import argparse
from pathlib import Path

def get_base_mapping():
    """
    Since sprites-master uses PokeAPI IDs (e.g. 10100 for Alolan Raichu) and 
    all_pokemon.csv does not contain these IDs, we create a fallback mapping mechanism.
    If we can't find a direct PokeAPI variant ID, we will fallback to the base Dex ID.
    """
    return {
        "alolan_rattata": 10091,
        "alolan_raticate": 10092,
        "alolan_raichu": 10100,
        "alolan_sandshrew": 10101,
        "alolan_sandslash": 10102,
        "alolan_vulpix": 10103,
        "alolan_ninetales": 10104,
        "alolan_diglett": 10105,
        "alolan_dugtrio": 10106,
        "alolan_meowth": 10107,
        "alolan_persian": 10108,
        "alolan_geodude": 10109,
        "alolan_graveler": 10110,
        "alolan_golem": 10111,
        "alolan_grimer": 10112,
        "alolan_muk": 10113,
        "alolan_exeggutor": 10114,
        "alolan_marowak": 10115,
        "galarian_meowth": 10161,
        "galarian_ponyta": 10162,
        "galarian_rapidash": 10163,
        "galarian_slowpoke": 10164,
        "galarian_slowbro": 10165,
        "galarian_farfetch_d": 10166,
        "galarian_weezing": 10167,
        "galarian_mr_mime": 10168,
        "galarian_articuno": 10169,
        "galarian_zapdos": 10170,
        "galarian_moltres": 10171,
        "galarian_slowking": 10172,
        "galarian_corsola": 10173,
        "galarian_zigzagoon": 10174,
        "galarian_linoone": 10175,
        "galarian_darumaka": 10176,
        "galarian_zen_mode": 10177,
        "galarian_yamask": 10178,
        "galarian_stunfisk": 10179,
        # Default behavior handles Mega evolutions and other variants as base id if not mapped.
    }

def organize_pokemon_sprites(source_dir: Path, target_dir: Path, data_dir: Path, dry_run: bool = False):
    print(f"Aligning {data_dir} with {target_dir} based on {source_dir}...")

    # Load mapping for variants
    variant_mapping = get_base_mapping()

    valid_pkmn_ids = []

    for json_file in data_dir.glob("*.json"):
        if json_file.name == "_schema.json":
            continue

        with open(json_file, 'r', encoding='utf-8') as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError:
                print(f"  Warning: Could not parse {json_file.name}")
                continue

        pkmn_id = data.get('id', json_file.stem)
        valid_pkmn_ids.append(pkmn_id)
        national_dex = data.get('national_dex')
        is_corrupted = data.get('is_corrupted', False)

        if not national_dex and not is_corrupted:
            print(f"  Warning: No national_dex for {pkmn_id}")
            continue

        # Create target directory
        pkmn_sprite_dir = target_dir / pkmn_id
        if not dry_run:
            pkmn_sprite_dir.mkdir(parents=True, exist_ok=True)
            
        if is_corrupted:
            # Custom corrupted forms likely do not exist in sprites-master
            # We just create their folder so artists know where to place them
            continue

        # Determine Sprite Master ID
        sprite_id = variant_mapping.get(pkmn_id, national_dex)

        # Paths in sprites-master
        # Icons are usually found in versions/generation-viii/icons (or vii)
        front_src = source_dir / f"{sprite_id}.png"
        back_src = source_dir / "back" / f"{sprite_id}.png"
        icon_src = source_dir / "versions" / "generation-viii" / "icons" / f"{sprite_id}.png"
        
        # Fallback if Gen 8 icon doesn't exist (e.g. older mons without gen 8 data)
        if not icon_src.exists():
            icon_src = source_dir / "versions" / "generation-vii" / "icons" / f"{sprite_id}.png"

        # Shiny and Gender Variance
        front_shiny_src = source_dir / "shiny" / f"{sprite_id}.png"
        back_shiny_src = source_dir / "back" / "shiny" / f"{sprite_id}.png"
        front_female_src = source_dir / "female" / f"{sprite_id}.png"
        back_female_src = source_dir / "back" / "female" / f"{sprite_id}.png"
        front_shiny_female_src = source_dir / "shiny" / "female" / f"{sprite_id}.png"
        back_shiny_female_src = source_dir / "back" / "shiny" / "female" / f"{sprite_id}.png"

        files_to_copy = [
            (front_src, pkmn_sprite_dir / "front.png", "Front"),
            (back_src, pkmn_sprite_dir / "back.png", "Back"),
            (icon_src, pkmn_sprite_dir / "icon.png", "Icon"),
            (front_shiny_src, pkmn_sprite_dir / "front_shiny.png", "Front Shiny"),
            (back_shiny_src, pkmn_sprite_dir / "back_shiny.png", "Back Shiny"),
            (front_female_src, pkmn_sprite_dir / "front_female.png", "Front Female"),
            (back_female_src, pkmn_sprite_dir / "back_female.png", "Back Female"),
            (front_shiny_female_src, pkmn_sprite_dir / "front_shiny_female.png", "Front Shiny Female"),
            (back_shiny_female_src, pkmn_sprite_dir / "back_shiny_female.png", "Back Shiny Female"),
        ]

        for src, dst, name in files_to_copy:
            if src.exists():
                if not dst.exists() and not dry_run:
                    shutil.copy2(src, dst)
            else:
                if not dry_run:
                    # Provide an empty representation or warning
                    pass

    print(f"\nOrganization complete!")

def cleanup_stray_files(target_dir: Path, dry_run: bool = False):
    """
    Cleans up any stray .png files that were copied directly into the pokemon root
    directory by the previous script.
    """
    print("Cleaning up stray files in target directory...")
    stray_files = list(target_dir.glob("*.png"))
    for file in stray_files:
        if dry_run:
            print(f"  [Dry Run] Would remove {file}")
        else:
            file.unlink()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ensure structural consistency of pokemon sprites")
    
    current_file_path = Path(__file__).resolve()
    primal_harmony_root = current_file_path.parent.parent
    project_root = primal_harmony_root.parent
    
    default_source = project_root / "sprites-master" / "sprites" / "pokemon"
    default_target = primal_harmony_root / "assets" / "sprites" / "pokemon"
    default_data = primal_harmony_root / "data" / "pokemon"
    
    parser.add_argument("--source", type=Path, default=default_source, help="Path to sprites-master/sprites/pokemon directory")
    parser.add_argument("--target", type=Path, default=default_target, help="Path to primal-harmony/assets/sprites/pokemon directory")
    parser.add_argument("--data", type=Path, default=default_data, help="Path to primal-harmony/data/pokemon JSON directory")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be done without actually making changes")
    parser.add_argument("--cleanup", action="store_true", help="Clean up stray png files in the target directory")

    args = parser.parse_args()

    if args.cleanup:
        cleanup_stray_files(args.target, args.dry_run)
    organize_pokemon_sprites(args.source, args.target, args.data, args.dry_run)
