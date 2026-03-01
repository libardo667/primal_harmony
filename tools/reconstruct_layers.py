import os
import subprocess
import argparse
from pathlib import Path

# Paths
POKEEMERALD_DIR = Path("C:/Users/levib/pokemon_projects/pokeemerald")
OUTPUT_BASE_DIR = Path("C:/Users/levib/pokemon_projects/primal_harmony/primal-harmony/assets/tilesets/layers")
BEHAVIORS_HEADER = POKEEMERALD_DIR / "include" / "constants" / "metatile_behaviors.h"

def run_wsl_command(cmd_list):
    """Run a command in WSL and return the output."""
    # Convert Windows paths to WSL paths: C:\foo -> /mnt/c/foo
    def to_wsl_path(win_path):
        p = str(win_path).replace('\\', '/')
        if p[1:3] == ':/':
            p = f"/mnt/{p[0].lower()}{p[2:]}"
        return p

    wsl_cmd = ["wsl"] + [to_wsl_path(c) if isinstance(c, Path) or (isinstance(c, str) and (':\\' in c or ':/' in c)) else c for c in cmd_list]
    print(f"Executing: {' '.join(wsl_cmd)}")
    result = subprocess.run(wsl_cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error executing command: {result.stderr}")
    return result

def decompile_tileset(ts_name, is_primary, primary_name="general"):
    category = "primary" if is_primary else "secondary"
    ts_src_dir = POKEEMERALD_DIR / "data" / "tilesets" / category / ts_name
    ts_out_dir = OUTPUT_BASE_DIR / f"{category}_{ts_name}"
    
    if not ts_src_dir.exists():
        print(f"Error: Tileset source dir {ts_src_dir} does not exist.")
        return

    ts_out_dir.mkdir(parents=True, exist_ok=True)
    
    if is_primary:
        # porytiles decompile-primary [OPTIONS] <INPUT-PATH> <BEHAVIORS-HEADER>
        cmd = ["porytiles", "decompile-primary", "-o", ts_out_dir, ts_src_dir, BEHAVIORS_HEADER]
    else:
        # porytiles decompile-secondary [OPTIONS] <INPUT-PATH> <PRIMARY-INPUT-PATH> <BEHAVIORS-HEADER>
        ts_prim_dir = POKEEMERALD_DIR / "data" / "tilesets" / "primary" / primary_name
        cmd = ["porytiles", "decompile-secondary", "-o", ts_out_dir, ts_src_dir, ts_prim_dir, BEHAVIORS_HEADER]
    
    run_wsl_command(cmd)

def main():
    parser = argparse.ArgumentParser(description="Decompile pokeemerald tilesets using Porytiles in WSL.")
    parser.add_argument("--all-primaries", action="store_true", help="Decompile all primary tilesets")
    parser.add_argument("--tileset", type=str, help="Decompile a specific tileset (requires category)")
    parser.add_argument("--secondary", action="store_true", help="Flag if --tileset is a secondary tileset")
    parser.add_argument("--primary", type=str, default="general", help="Primary tileset name for secondary decompilation")

    args = parser.parse_args()

    if args.all_primaries:
        prim_dir = POKEEMERALD_DIR / "data" / "tilesets" / "primary"
        for ts in prim_dir.iterdir():
            if ts.is_dir() and (ts / "tiles.png").exists():
                print(f"Processing primary: {ts.name}")
                decompile_tileset(ts.name, True)
    elif args.tileset:
        decompile_tileset(args.tileset, not args.secondary, args.primary)
    else:
        # Default: just do primary general for testing
        print("No arguments provided. Processing 'general' primary for testing...")
        decompile_tileset("general", True)

if __name__ == "__main__":
    main()
