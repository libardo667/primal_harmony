import os
import subprocess
import shutil
import argparse
from pathlib import Path

# Paths
ROOT_DIR = Path("c:/Users/levib/pokemon_projects/primal_harmony/primal-harmony")
TOOLS_DIR = ROOT_DIR / "tools"
ASSETS_DIR = ROOT_DIR / "assets" / "tilesets"
LAYERS_DIR = ASSETS_DIR / "layers"
GODOT_EXE = Path("C:/Program Files/godot/Godot_v4.6.1-stable_win64.exe")

def run_command(cmd, cwd=ROOT_DIR):
    print(f"Executing: {' '.join(map(str, cmd))}")
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
    else:
        print(result.stdout)
    return result

def strip_magenta(img_path):
    from PIL import Image
    try:
        img = Image.open(img_path).convert("RGBA")
        data = img.getdata()
        new_data = []
        for item in data:
            # Change all opaque magenta pixels to transparent
            if item[0] == 255 and item[1] == 0 and item[2] == 255:
                new_data.append((255, 0, 255, 0))
            else:
                new_data.append(item)
        img.putdata(new_data)
        img.save(img_path)
        print(f"  Stripped magenta from {img_path.name}")
    except Exception as e:
        print(f"  Error stripping magenta from {img_path.name}: {e}")

def process_tileset(ts_name, is_primary, primary_name="general"):
    category = "primary" if is_primary else "secondary"
    full_name = f"{category}_{ts_name}"
    
    print(f"\n=== Processing {full_name} ===")
    
    # 1. Decompile layers using Porytiles (WSL)
    decompile_args = ["python", str(TOOLS_DIR / "reconstruct_layers.py"), "--tileset", ts_name]
    if not is_primary:
        decompile_args += ["--secondary", "--primary", primary_name]
    run_command(decompile_args)
    
    # 2. Copy static layers to assets/tilesets/
    src_layers = LAYERS_DIR / full_name
    for layer in ["bottom", "middle", "top"]:
        src_png = src_layers / f"{layer}.png"
        if src_png.exists():
            dest_png = ASSETS_DIR / f"{full_name}_{layer}.png"
            shutil.copy2(src_png, dest_png)
            strip_magenta(dest_png)
            print(f"  Processed static layer: {dest_png.name}")
    
    # 3. Export animation frames (3-layer)
    # This script processes all tilesets by default, but we'll just run it.
    # It will skip those without Porytile layers (which we just created)
    run_command(["python", str(TOOLS_DIR / "export_tileset_anim_frames.py")])
    
    # 4. Build Godot .tres resources for animations
    run_command([str(GODOT_EXE), "--headless", "--script", "res://tools/build_anim_tilesets.gd"])

def main():
    parser = argparse.ArgumentParser(description="Master script for tileset layer reconstruction.")
    parser.add_argument("--all", action="store_true", help="Process ALL tilesets found in layouts.json")
    parser.add_argument("--tileset", type=str, help="Process a specific tileset")
    parser.add_argument("--secondary", action="store_true", help="Flag if --tileset is a secondary")
    parser.add_argument("--primary", type=str, default="general", help="Primary name for secondary")

    args = parser.parse_args()

    # Ensure directories exist
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)

    if args.all:
        import json
        poke_dir = ROOT_DIR.parent.parent / "pokeemerald"
        layouts_json = poke_dir / "data" / "layouts" / "layouts.json"
        with open(layouts_json, "r") as f:
            data = json.load(f)
        
        # Collect unique tilesets
        # primary -> set of secondaries
        tileset_map = {}
        
        for layout in data["layouts"]:
            prim_g = layout["primary_tileset"]
            sec_g = layout["secondary_tileset"]
            
            # gTileset_General -> general
            def clean_name(g):
                return g.replace("gTileset_", "")[:1].lower() + g.replace("gTileset_", "")[1:]
            
            # camel_to_snake
            def to_snake(s):
                res = ""
                for i, c in enumerate(s):
                    if i > 0 and c.isupper(): res += "_"
                    res += c.lower()
                return res

            prim = to_snake(clean_name(prim_g))
            sec = to_snake(clean_name(sec_g))
            
            if prim not in tileset_map:
                tileset_map[prim] = set()
            tileset_map[prim].add(sec)
        
        # Process primaries first
        for prim in sorted(tileset_map.keys()):
            process_tileset(prim, True)
            # Then their specific secondaries
            for sec in sorted(tileset_map[prim]):
                if sec != "0": # Skip "0" secondary (no tiles)
                    process_tileset(sec, False, prim)
                    
    elif args.tileset:
        process_tileset(args.tileset, not args.secondary, args.primary)
    else:
        print("Please specify --all or --tileset <name>")

if __name__ == "__main__":
    main()
