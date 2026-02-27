import os
import shutil
import argparse
from pathlib import Path

def port_emerald_audio(emerald_dir: Path, target_dir: Path, dry_run: bool = False):
    sound_dir = emerald_dir / "sound"
    
    if not sound_dir.exists():
        print(f"Error: Could not find Emerald sound at {sound_dir}")
        return

    # Targets
    sfx_target = target_dir / "sfx"
    cries_target = target_dir / "cries"
    bgm_midi_target = target_dir / "bgm" / "midi"

    copied_cries = 0
    copied_sfx = 0
    copied_midi = 0

    print(f"Porting audio from {sound_dir} to {target_dir}...")

    # 1. Port SFX and Cries (.wav)
    samples_dir = sound_dir / "direct_sound_samples"
    if samples_dir.exists():
        for root, dirs, files in os.walk(samples_dir):
            root_path = Path(root)
            for file in files:
                if not file.endswith(".wav"): continue
                
                src_file = root_path / file
                
                # Check if it's a cry
                is_cry = "cries" in root_path.parts
                
                if is_cry:
                    dst_folder = cries_target
                    copied_cries += 1
                else:
                    dst_folder = sfx_target
                    copied_sfx += 1
                    
                dst_file = dst_folder / file
                
                if not dry_run:
                    dst_folder.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src_file, dst_file)
    else:
        print(f"Warning: {samples_dir} does not exist.")

    # 2. Port BGM (.mid)
    songs_dir = sound_dir / "songs" / "midi"
    if songs_dir.exists():
        for root, dirs, files in os.walk(songs_dir):
            root_path = Path(root)
            for file in files:
                if not file.endswith(".mid") and not file.endswith(".midi"): continue
                
                src_file = root_path / file
                dst_folder = bgm_midi_target
                dst_file = dst_folder / file
                
                if not dry_run:
                    dst_folder.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src_file, dst_file)
                copied_midi += 1
    else:
         print(f"Warning: {songs_dir} does not exist.")

    verb = "Would copy" if dry_run else "Successfully copied"
    print(f"{verb} {copied_cries} Pokemon Cries, {copied_sfx} Sound Effects, and {copied_midi} MIDI tracks.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Port audio (WAVs and MIDIs) from pokeemerald decompilation.")
    
    current_file_path = Path(__file__).resolve()
    primal_harmony_tools = current_file_path.parent
    primal_harmony_root = primal_harmony_tools.parent
    projects_root = primal_harmony_root.parent.parent
    
    default_emerald = projects_root / "pokeemerald"
    default_target = primal_harmony_root / "assets" / "audio"
    
    parser.add_argument("--emerald", type=Path, default=default_emerald, help="Path to the pokeemerald decompilation root directory")
    parser.add_argument("--target", type=Path, default=default_target, help="Path to primal-harmony/assets/audio directory")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be done without actually making changes")

    args = parser.parse_args()

    port_emerald_audio(args.emerald, args.target, args.dry_run)
