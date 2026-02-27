import os
import shutil
import argparse
from pathlib import Path

def port_emerald_tilesets(emerald_dir: Path, target_dir: Path, dry_run: bool = False):
    tilesets_dir = emerald_dir / "data" / "tilesets"
    
    if not tilesets_dir.exists():
        print(f"Error: Could not find Emerald tilesets at {tilesets_dir}")
        return

    copied_pngs = 0
    copied_pals = 0

    print(f"Porting tilesets from {tilesets_dir} to {target_dir}...")

    # We want to iterate through primary and secondary tilesets
    for category in ["primary", "secondary"]:
        cat_dir = tilesets_dir / category
        if not cat_dir.exists(): continue
        
        for root, dirs, files in os.walk(cat_dir):
            root_path = Path(root)
            
            # We are looking for tiles.png inside specific tileset folders
            if "tiles.png" in files:
                tileset_name = root_path.name
                # E.g. primary_general.png, secondary_petalburg.png
                new_filename = f"{category}_{tileset_name}.png"
                
                src_file = root_path / "tiles.png"
                dst_file = target_dir / new_filename
                
                if not dry_run:
                    target_dir.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src_file, dst_file)
                copied_pngs += 1
                
                # Now lets grab the palettes folder!
                palettes_dir = root_path / "palettes"
                if palettes_dir.exists():
                    # e.g. target_dir / "palettes" / "primary_general"
                    dst_palettes_dir = target_dir / "palettes" / f"{category}_{tileset_name}"
                    
                    if not dry_run:
                        dst_palettes_dir.mkdir(parents=True, exist_ok=True)
                    
                    for pal_file in os.listdir(palettes_dir):
                        if pal_file.endswith(".pal"):
                            src_pal_path = palettes_dir / pal_file
                            dst_pal_path = dst_palettes_dir / pal_file
                                
                            if not dry_run:
                                shutil.copy2(src_pal_path, dst_pal_path)
                            copied_pals += 1

    verb = "Would copy" if dry_run else "Successfully copied"
    print(f"{verb} {copied_pngs} Tileset PNGs and {copied_pals} Palette (.pal) files.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Port tilesets from pokeemerald decompilation.")
    
    current_file_path = Path(__file__).resolve()
    primal_harmony_tools = current_file_path.parent
    primal_harmony_root = primal_harmony_tools.parent
    projects_root = primal_harmony_root.parent.parent
    
    default_emerald = projects_root / "pokeemerald"
    default_target = primal_harmony_root / "assets" / "tilesets" # Output to assets/tilesets
    
    parser.add_argument("--emerald", type=Path, default=default_emerald, help="Path to the pokeemerald decompilation root directory")
    parser.add_argument("--target", type=Path, default=default_target, help="Path to primal-harmony/assets/tilesets directory")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be done without actually making changes")

    args = parser.parse_args()

    port_emerald_tilesets(args.emerald, args.target, args.dry_run)
