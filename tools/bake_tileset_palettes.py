import os
from pathlib import Path
from PIL import Image

def parse_pal(pal_path: Path):
    """Parses a JASC-PAL file and returns a list of (R, G, B) tuples."""
    colors = []
    if not pal_path.exists():
        # Fallback to magenta if missing
        return [(255, 0, 255)] * 16
        
    with open(pal_path, 'r') as f:
        lines = f.read().splitlines()
        
    # Skip JASC-PAL, 0100, and 16 lines
    for line in lines[3:]:
        if not line.strip(): continue
        parts = line.split()
        if len(parts) == 3:
            r, g, b = map(int, parts)
            colors.append((r, g, b))
            
    # Pad to 16 just in case
    while len(colors) < 16:
        colors.append((255, 0, 255))
        
    return colors[:16]

def main():
    root_dir = Path("c:/Users/levib/pokemon_projects/primal_harmony/primal-harmony")
    tilesets_dir = root_dir / "assets" / "tilesets"
    palettes_dir = tilesets_dir / "palettes"
    
    if not tilesets_dir.exists():
        print("Tilesets directory not found.")
        return
        
    for file in tilesets_dir.iterdir():
        if not file.is_file() or not file.name.endswith(".png"):
            continue
            
        tileset_name = file.stem
        pal_folder = palettes_dir / tileset_name
        
        if not pal_folder.exists():
            continue
            
        print(f"Baking palettes into {tileset_name}.png...")
        
        # Load the 16 palettes
        palettes = []
        for i in range(16):
            pal_path = pal_folder / f"{i:02d}.pal"
            colors = parse_pal(pal_path)
            palettes.append(colors)
            
        # Open the source PNG (16-color indexed P mode usually)
        try:
            with Image.open(file) as src_img:
                src_img = src_img.convert("P") # Ensure we are reading indices
                width, height = src_img.size
                
                # We need to unroll 16 copies vertically
                out_img = Image.new("RGBA", (width, height * 16))
                out_pixels = out_img.load()
                
                # Get raw pixel indices
                # We can't just iterate normally if we want speed, but it's small enough
                for y in range(height):
                    for x in range(width):
                        idx = src_img.getpixel((x, y))
                        
                        # Apply this pixel for all 16 palettes
                        for p in range(16):
                            out_y = y + (p * height)
                            if idx == 0:
                                # GBA background color is always index 0
                                out_pixels[x, out_y] = (0, 0, 0, 0)
                            else:
                                r, g, b = palettes[p][idx]
                                out_pixels[x, out_y] = (r, g, b, 255)
                                
                # Overwrite original .png with the expanded true-color one
                out_img.save(file, "PNG")
                print(f"  -> Saved expanded {width}x{height*16} texture.")
        except Exception as e:
            print(f"  -> Error processing {file.name}: {e}")

if __name__ == "__main__":
    main()
