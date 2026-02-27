import os
import shutil
import argparse
from pathlib import Path

def port_emerald_fonts(emerald_dir: Path, target_dir: Path, dry_run: bool = False):
    fonts_dir = emerald_dir / "graphics" / "fonts"
    
    if not fonts_dir.exists():
        print(f"Error: Could not find Emerald fonts at {fonts_dir}")
        return

    copied_count = 0

    print(f"Porting fonts from {fonts_dir} to {target_dir}...")

    if not dry_run:
        target_dir.mkdir(parents=True, exist_ok=True)

    for root, dirs, files in os.walk(fonts_dir):
        root_path = Path(root)
        for file in files:
            # We only care about the visual representation of the font
            if not file.endswith(".png"): continue
            
            src_file = root_path / file
            dst_file = target_dir / file
            
            if dry_run:
                # print(f"[Dry Run] {src_file.name} -> {target_dir.name}")
                pass
            else:
                shutil.copy2(src_file, dst_file)
            copied_count += 1

    verb = "Would copy" if dry_run else "Successfully copied"
    print(f"{verb} {copied_count} base font PNG grids.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Port font PNG grids from pokeemerald decompilation.")
    
    current_file_path = Path(__file__).resolve()
    primal_harmony_tools = current_file_path.parent
    primal_harmony_root = primal_harmony_tools.parent
    projects_root = primal_harmony_root.parent.parent
    
    default_emerald = projects_root / "pokeemerald"
    # Dump them into a raw_png_grids folder so we don't confuse them with future .ttf files
    default_target = primal_harmony_root / "assets" / "fonts" / "raw_png_grids" 
    
    parser.add_argument("--emerald", type=Path, default=default_emerald, help="Path to the pokeemerald decompilation root directory")
    parser.add_argument("--target", type=Path, default=default_target, help="Path to primal-harmony/assets/fonts/raw_png_grids directory")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be done without actually making changes")

    args = parser.parse_args()

    port_emerald_fonts(args.emerald, args.target, args.dry_run)
