"""fix_sprite_transparency.py

One-shot script that keys out the GBA background colour (palette index 0) from
all player and NPC sprite PNGs already ported into assets/sprites/.

Run from the project root:
    python3 tools/fix_sprite_transparency.py

After running, open Godot (or run --headless --import) so the textures are
re-imported from the updated PNGs.
"""

from pathlib import Path
from PIL import Image


SPRITES_ROOT = Path("assets/sprites")
PNG_DIRS = [
    SPRITES_ROOT / "player",
    SPRITES_ROOT / "npcs",
]


def key_out_background(path: Path) -> bool:
    """Key out the GBA transparent colour and overwrite the PNG.

    Returns True if the file was modified, False if it was already RGBA with
    no opaque background detected or could not be opened.
    """
    try:
        img = Image.open(path)
    except Exception as exc:
        print(f"  SKIP (open error): {path}  — {exc}")
        return False

    if img.mode == "P":
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
        corner = img.getpixel((0, 0))
        if corner[3] == 0:
            # Already fully transparent at corner — likely already fixed.
            return False
        bg_rgb = corner[:3]

    data = list(img.getdata())
    new_data = [(0, 0, 0, 0) if (r, g, b) == bg_rgb else (r, g, b, a)
                for r, g, b, a in data]
    img.putdata(new_data)
    img.save(path, "PNG")
    return True


def main() -> None:
    fixed = 0
    skipped = 0

    for search_dir in PNG_DIRS:
        if not search_dir.exists():
            print(f"Directory not found, skipping: {search_dir}")
            continue

        for png in sorted(search_dir.rglob("*.png")):
            changed = key_out_background(png)
            rel = png.relative_to(SPRITES_ROOT)
            if changed:
                print(f"  fixed  {rel}")
                fixed += 1
            else:
                skipped += 1

    print(f"\nDone. Fixed={fixed}  Skipped={skipped}")
    print("Run 'godot --headless --import' (or open the editor) to re-import textures.")


if __name__ == "__main__":
    main()
