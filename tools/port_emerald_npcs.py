import os
import argparse
from pathlib import Path
from PIL import Image


def _key_out_and_save(src: Path, dst: Path) -> None:
    """Copy a sprite PNG with the GBA transparent colour (palette index 0) keyed out.

    GBA sprites store transparent pixels as palette index 0; the colour itself is
    arbitrary (often mint-green for pokeemerald player/NPC sheets).  Pillow opens
    the indexed PNG, reads that palette entry, converts to RGBA, and zeroes every
    pixel that matches the background colour so Godot renders it as transparent.
    """
    img = Image.open(src)

    if img.mode == "P":
        # Indexed PNG — transparent colour index is stored in PNG metadata.
        transparent_idx: int = img.info.get("transparency", 0)
        palette = img.getpalette()
        bg_rgb = (
            palette[transparent_idx * 3],
            palette[transparent_idx * 3 + 1],
            palette[transparent_idx * 3 + 2],
        )
        img = img.convert("RGBA")
    else:
        img = img.convert("RGBA")
        # Fall back to sampling the top-left corner as background.
        bg_rgb = img.getpixel((0, 0))[:3]

    # Replace background-coloured pixels with fully transparent.
    data = list(img.getdata())
    data = [(0, 0, 0, 0) if (r, g, b) == bg_rgb else (r, g, b, a)
            for r, g, b, a in data]
    img.putdata(data)
    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst, "PNG")


def port_emerald_npcs(emerald_dir: Path, target_dir: Path, dry_run: bool = False):
    people_dir = emerald_dir / "graphics" / "object_events" / "pics" / "people"
    
    if not people_dir.exists():
        print(f"Error: Could not find Emerald sprites at {people_dir}")
        return

    npc_target = target_dir / "npcs"
    player_target = target_dir / "player"
    
    if not dry_run:
        npc_target.mkdir(parents=True, exist_ok=True)
        player_target.mkdir(parents=True, exist_ok=True)

    print(f"Porting NPC sprites from {people_dir} to {target_dir}...")

    # Player specific directories
    player_dirs = ["brendan", "may", "ruby_sapphire_brendan", "ruby_sapphire_may"]

    copied_count = 0

    # Walk through the people directory
    for root, dirs, files in os.walk(people_dir):
        root_path = Path(root)
        
        for file in files:
            if not file.endswith(".png"):
                continue
                
            src_file = root_path / file
            
            # Determine destination based on whether it's in a player directory
            is_player = False
            rel_path = root_path.relative_to(people_dir)
            
            # Check if this file falls under any of the player directories
            if rel_path.parts and rel_path.parts[0] in player_dirs:
                is_player = True
                
            if is_player:
                # E.g. player_target / "brendan" / "walking.png"
                dst_folder = player_target / rel_path
            else:
                # Put other NPCs cleanly into the npcs folder, maintaining subfolders if they exist 
                # (like gym_leaders, team_aqua, etc.)
                if rel_path == Path('.'):
                    # It's in the root of 'people', so put directly in 'npcs'
                    dst_folder = npc_target
                else:
                    # It's in a subdirectory like 'gym_leaders'
                    dst_folder = npc_target / rel_path

            dst_file = dst_folder / file
            
            if dry_run:
                print(f"[Dry Run] Would copy {src_file.name} to {dst_folder.relative_to(target_dir.parent)}")
            else:
                _key_out_and_save(src_file, dst_file)
                copied_count += 1

    verb = "Would copy" if dry_run else "Successfully copied"
    print(f"{verb} {copied_count} NPC and Player sprite sheets.")
    
    # Just a safety reminder log for the user
    print("\nNote: Pokemon object events were strictly ignored to preserve existing assets.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Port overworld NPC sprites from pokeemerald decompilation.")
    
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

    port_emerald_npcs(args.emerald, args.target, args.dry_run)
