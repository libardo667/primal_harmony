import os
import shutil
import argparse
from pathlib import Path

def port_emerald_assets(emerald_dir: Path, target_dir: Path, dry_run: bool = False):
    graphics_dir = emerald_dir / "graphics"
    
    if not graphics_dir.exists():
        print(f"Error: Could not find Emerald graphics at {graphics_dir}")
        return

    # Mappings from pokeemerald/graphics folder to primal-harmony/assets/sprites folder
    # Format: (Source Path relative to graphics, Target Path relative to assets/sprites)
    mappings = [
        # NPCs (we mapped this logic manually before, we can keep it standard now)
        ("object_events/pics/people", "npcs_and_player"),
        ("trainers/front_pics", "trainers/front_pics"),
        ("trainers/back_pics", "trainers/back_pics"),
        ("interface", "ui/interface"),
        ("battle_interface", "ui/battle_interface"),
        ("party_menu", "ui/party_menu"),
        ("summary_screen", "ui/summary_screen"),
        ("pokedex", "ui/pokedex"),
        ("bag", "ui/bag"),
        ("fonts", "ui/fonts")
    ]
    
    player_dirs = ["brendan", "may", "ruby_sapphire_brendan", "ruby_sapphire_may"]
    
    npc_target = target_dir / "npcs"
    player_target = target_dir / "player"

    copied_count = 0

    print(f"Porting expanded assets from {graphics_dir} to {target_dir}...")

    for src_rel, dst_rel in mappings:
        src_dir = graphics_dir / src_rel
        if not src_dir.exists():
            print(f"Warning: Source directory {src_dir} not found. Skipping.")
            continue
            
        # Specific logic for NPCs/Players like earlier
        if src_rel == "object_events/pics/people":
            for root, dirs, files in os.walk(src_dir):
                root_path = Path(root)
                for file in files:
                    if not file.endswith(".png"): continue
                    
                    src_file = root_path / file
                    rel_path = root_path.relative_to(src_dir)
                    
                    is_player = (rel_path.parts and rel_path.parts[0] in player_dirs)
                    
                    if is_player:
                        dst_folder = player_target / rel_path
                    else:
                        if rel_path == Path('.'): dst_folder = npc_target
                        else: dst_folder = npc_target / rel_path
                        
                    dst_file = dst_folder / file
                    if dry_run:
                        # print(f"[Dry Run] {src_file.name} -> {dst_folder.relative_to(target_dir)}")
                        pass
                    else:
                        dst_folder.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(src_file, dst_file)
                        copied_count += 1
            continue
            
        # Standard logic for other mapped folders (trainers, UI)
        dst_base = target_dir / dst_rel
        for root, dirs, files in os.walk(src_dir):
            root_path = Path(root)
            # Exclude palettes or weird files if desired, only get png
            for file in files:
                if not file.endswith(".png"): continue
                
                src_file = root_path / file
                rel_path = root_path.relative_to(src_dir)
                dst_folder = dst_base / rel_path
                dst_file = dst_folder / file
                
                if dry_run:
                    # To keep output from being 10,000 lines long, we'll mute dry run exact prints
                    pass
                else:
                    dst_folder.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src_file, dst_file)
                    copied_count += 1

    verb = "Would copy" if dry_run else "Successfully copied"
    print(f"{verb} {copied_count} UI, Trainer, and NPC sprite PNGs.")
    print("Pokemon assets were safely ignored.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Port overworld NPCs, Trainers, and UI sprites from pokeemerald decompilation.")
    
    current_file_path = Path(__file__).resolve()
    primal_harmony_tools = current_file_path.parent
    primal_harmony_root = primal_harmony_tools.parent
    projects_root = primal_harmony_root.parent.parent
    
    default_emerald = projects_root / "pokeemerald"
    default_target = primal_harmony_root / "assets" / "sprites"
    
    parser.add_argument("--emerald", type=Path, default=default_emerald, help="Path to the pokeemerald decompilation root directory")
    parser.add_argument("--target", type=Path, default=default_target, help="Path to primal-harmony/assets/sprites directory")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be done without actually making changes")

    args = parser.parse_args()

    port_emerald_assets(args.emerald, args.target, args.dry_run)
