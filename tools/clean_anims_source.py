"""
clean_anims_source.py

Preprocesses pokeemerald's tileset_anims.c using gcc -E (via WSL) to fully
expand all macros, then evaluates constant arithmetic expressions to produce
a cleaned file with flat integer literals.

The output is written to tools/tileset_anims_cleaned.c and consumed by
export_tileset_anim_frames.py.
"""

import os
import re
import subprocess
from pathlib import Path

POKEEMERALD_DIR = Path("C:/Users/levib/pokemon_projects/pokeemerald")
SOURCE_FILE = POKEEMERALD_DIR / "src" / "tileset_anims.c"
OUTPUT_FILE = Path(__file__).parent / "tileset_anims_cleaned.c"

# Minimal stub header for gcc -E: defines only the types and macros that
# tileset_anims.c actually uses, avoiding the full pokeemerald include tree.
STUBS_HEADER = r"""
typedef unsigned short u16;
typedef unsigned char u8;
typedef unsigned int u32;
typedef int s32;
typedef short s16;
typedef char s8;
typedef unsigned int size_t;
typedef _Bool bool;
#define TRUE 1
#define FALSE 0
#define NULL ((void*)0)
#define EWRAM_DATA
/* Variadic to handle Sootopolis stormy water (2-arg INCBIN_U16) */
#define INCBIN(...) INCBIN_PLACEHOLDER(__VA_ARGS__)
#define INCBIN_U16(...) INCBIN(__VA_ARGS__)
#define VRAM 0x06000000
#define BG_VRAM VRAM
#define TILE_WIDTH 8
#define TILE_HEIGHT 8
#define TILE_SIZE(bpp) ((bpp) * TILE_WIDTH * TILE_HEIGHT / 8)
#define TILE_SIZE_4BPP TILE_SIZE(4)
#define TILE_OFFSET_4BPP(n) ((n) * TILE_SIZE_4BPP)
#define NUM_TILES_IN_PRIMARY 512
#define ARRAY_COUNT(a) (sizeof(a)/sizeof((a)[0]))
#define Task void
struct Tileset;
/* Stub out all pokeemerald headers via their include guards */
#define GUARD_GLOBAL_H
#define GUARD_GRAPHICS_H
#define GUARD_PALETTE_H
#define GUARD_UTIL_H
#define GUARD_BATTLE_TRANSITION_H
#define GUARD_TASK_H
#define GUARD_FIELDMAP_H
#define GUARD_GBA_H
"""


def to_wsl_path(win_path: str) -> str:
    p = str(win_path).replace('\\', '/')
    if p[1:3] == ':/':
        p = f"/mnt/{p[0].lower()}{p[2:]}"
    return p


def eval_arith(match):
    """Evaluate a parenthesized arithmetic expression to an integer literal."""
    expr = match.group(0)
    try:
        val = eval(expr)
        if isinstance(val, (int, float)):
            return str(int(val))
    except Exception:
        pass
    return expr


def clean_source():
    if not SOURCE_FILE.exists():
        print(f"Error: Could not find source file at {SOURCE_FILE}")
        return

    # Write stub header to a temp file accessible from WSL
    stubs_path = Path(os.environ.get("TEMP", "/tmp")) / "tileset_anims_stubs.h"
    stubs_path.write_text(STUBS_HEADER, encoding="utf-8")

    wsl_stubs = to_wsl_path(str(stubs_path))
    wsl_source = to_wsl_path(str(SOURCE_FILE))
    wsl_include = to_wsl_path(str(POKEEMERALD_DIR / "include"))
    wsl_root = to_wsl_path(str(POKEEMERALD_DIR))

    cmd = [
        "wsl", "gcc", "-E", "-P",
        f"-include", wsl_stubs,
        f"-I{wsl_include}",
        f"-I{wsl_root}",
        wsl_source,
    ]
    print(f"Running: {' '.join(cmd)}")
    env = os.environ.copy()
    env["MSYS_NO_PATHCONV"] = "1"
    result = subprocess.run(cmd, capture_output=True, text=True, env=env)

    if result.returncode != 0:
        print(f"gcc -E failed: {result.stderr}")
        return

    content = result.stdout

    # Strip # line directives that gcc -P should have removed but sometimes doesn't
    content = re.sub(r'^#\s+\d+\s+"[^"]*".*$', '', content, flags=re.MULTILINE)

    # Evaluate constant arithmetic expressions like ((512 + 288) * ((4) * 8 * 8 / 8))
    # to flat integers like 25600. Process innermost parens first, iteratively.
    for _ in range(10):
        prev = content
        # Match parenthesized groups containing only digits, +, -, *, /, spaces
        content = re.sub(r'\([\d\s\+\-\*/]+\)', eval_arith, content)
        if content == prev:
            break

    # Restore INCBIN_U16 declarations from the placeholder
    content = content.replace('INCBIN_PLACEHOLDER(', 'INCBIN_U16(')

    OUTPUT_FILE.write_text(content, encoding="utf-8")
    print(f"Done. Cleaned source saved to {OUTPUT_FILE}")
    print(f"  Lines: {len(content.splitlines())}")

    # Quick sanity check
    append_count = content.count("AppendTilesetAnimToBuffer")
    incbin_count = content.count("INCBIN_U16")
    print(f"  AppendTilesetAnimToBuffer calls: {append_count}")
    print(f"  INCBIN_U16 declarations: {incbin_count}")


if __name__ == "__main__":
    clean_source()
