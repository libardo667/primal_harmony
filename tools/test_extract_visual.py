import os
from pathlib import Path
from PIL import Image

def parse_pal(pal_path: Path):
    colors = []
    if not pal_path.exists():
        return [(255, 0, 255)] * 16
    with open(pal_path, 'r') as f:
        lines = f.read().splitlines()
    for line in lines[3:]:
        if not line.strip(): continue
        parts = line.split()
        if len(parts) == 3:
            r, g, b = map(int, parts)
            colors.append((r, g, b))
    while len(colors) < 16:
        colors.append((255, 0, 255))
    return colors[:16]

pokeemerald_dir = Path("C:/Users/levib/pokemon_projects/pokeemerald")
palettes = []
pal_dir = pokeemerald_dir / "data/tilesets/primary/general/palettes"
for i in range(16):
    pal_path = pal_dir / f"{i:02d}.pal"
    palettes.append(parse_pal(pal_path))

src_img = Image.open(pokeemerald_dir / "data/tilesets/primary/general/tiles.png").convert("P")
# Apply patch to src_img
anim_img = Image.open(pokeemerald_dir / "data/tilesets/primary/general/anim/flower/0.png").convert("P")
tiles_per_row = 16
vdest = 508
dest_tx = (vdest % tiles_per_row) * 8
dest_ty = (vdest // tiles_per_row) * 8
src_img.paste(anim_img.crop((0,0,8,8)), (dest_tx, dest_ty))

# To extract this with the palette applied, we can use the same logic build_godot_tilesets uses
def extract_gba_tile(src_img, x, y, palette):
    tile = Image.new("RGBA", (8, 8), (0,0,0,0))
    pixels = tile.load()
    px = x * 8
    py = y * 8
    
    for ty in range(8):
        for tx in range(8):
            src_x = px + tx
            src_y = py + ty
            idx = src_img.getpixel((src_x, src_y))
            if idx > 0 and idx < 16:
                r, g, b = palette[idx]
                pixels[tx, ty] = (r, g, b, 255)
    return tile

# Visual extract
x = 508 % 16
y = 508 // 16
tile_img = extract_gba_tile(src_img, x, y, palettes[2])
# Give them a 64x64 scaled version so they can see it
tile_img_large = tile_img.resize((64, 64), Image.NEAREST)
tile_img_large.save("c:/Users/levib/pokemon_projects/primal_harmony/primal-harmony/extracted_flower.png")
print("Saved extracted_flower.png for visual review.")

# Also show them the raw tiles.png patch area directly, applied with palettes[2]
# Cropping a 16x16 area around the tile
canvas = Image.new("RGBA", (16, 16), (255,0,255,255)) # magic pink background 
for yy in range(2):
    for xx in range(2):
        if x + xx < 16 and y + yy < 32:
            sub_tile = extract_gba_tile(src_img, x + xx, y + yy, palettes[2])
            canvas.paste(sub_tile, (xx * 8, yy * 8), sub_tile)

canvas_large = canvas.resize((128, 128), Image.NEAREST)
canvas_large.save("c:/Users/levib/pokemon_projects/primal_harmony/primal-harmony/extracted_flower_context.png")
print("Saved extracted_flower_context.png for visual review.")
