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

def print_extracted_tile(src_img, x, y, palette):
    px = x * 8
    py = y * 8
    print(f"Extraction at {x},{y} (px={px}, py={py})")
    for ty in range(8):
        row = []
        for tx in range(8):
            idx = src_img.getpixel((px + tx, py + ty))
            if idx > 0 and idx < 16:
                row.append(f"{idx:2d}")
            else:
                row.append(" 0")
        print(" ".join(row))

x = 508 % 16
y = 508 // 16
print_extracted_tile(src_img, x, y, palettes[2])
