import re
import os
from pathlib import Path

# Paths (Adjust to match user's environment)
POKEEMERALD_DIR = Path("C:/Users/levib/pokemon_projects/pokeemerald")
SOURCE_FILE = POKEEMERALD_DIR / "src" / "tileset_anims.c"
OUTPUT_FILE = Path(__file__).parent / "tileset_anims_cleaned.c"

# Macro definitions common to tileset_anims.c
MACROS = {
    r"TILE_OFFSET_4BPP\(([^)]+)\)": r"((\1) * 32)",
    r"TILE_SIZE_4BPP": "32",
    r"BG_VRAM": "0x06000000",
    r"NUM_TILES_IN_PRIMARY": "512",
    r"ARRAY_COUNT\(([^)]+)\)": r"(sizeof(\1) / sizeof((\1)[0]))",
    r"NULL": "0",
}

def clean_source():
    if not SOURCE_FILE.exists():
        print(f"Error: Could not find source file at {SOURCE_FILE}")
        return

    print(f"Cleaning {SOURCE_FILE}...")
    content = SOURCE_FILE.read_text(encoding='utf-8', errors='replace')

    # 1. Remove comments
    content = re.sub(r'//.*', '', content)
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)

    # 2. Expand macros
    for pattern, replacement in MACROS.items():
        content = re.sub(pattern, replacement, content)

    # 3. Handle simple math expansions (e.g. 4 * 32)
    # This helps the downstream parser which might not want to do eval()
    def eval_math(match):
        try:
            return str(eval(match.group(0)))
        except:
            return match.group(0)
            
    # Look for patterns like (512 + 96) * 32 or 4 * 32
    # This is a bit risky but we'll try to keep it safe for specific call sites
    # content = re.sub(r'\(\d+\s*[\+\-\*\/]\s*\d+\)\s*[\+\-\*\/]\s*\d+', eval_math, content)

    # 4. Save to output
    OUTPUT_FILE.write_text(content, encoding='utf-8')
    print(f"Done. Cleaned source saved to {OUTPUT_FILE}")

if __name__ == "__main__":
    clean_source()
