"""
port_sprites_from_master.py

Copies Pokémon sprites from sprites-master into the game's assets directory.

All sprites use the main sprites-master style (sprites/pokemon/{dex}.png).

Sources:
  front       → sprites/pokemon/{dex}.png
  back        → sprites/pokemon/back/{dex}.png
  front_shiny → sprites/pokemon/shiny/{dex}.png
  back_shiny  → sprites/pokemon/back/shiny/{dex}.png

Usage:
  python3 tools/port_sprites_from_master.py           # dry-run (prints actions only)
  python3 tools/port_sprites_from_master.py --apply   # actually copies files
"""

import csv
import shutil
import sys
import unicodedata
from pathlib import Path

SPRITES_MASTER   = Path("C:/Users/levib/pokemon_projects/primal_harmony/sprites-master/sprites/pokemon")
ASSETS_DIR       = Path("c:/Users/levib/pokemon_projects/primal_harmony/primal-harmony/assets/sprites/pokemon")
CSV_PATH         = Path("c:/Users/levib/pokemon_projects/primal_harmony/primal-harmony/all_pokemon.csv")

BACK_DIR       = SPRITES_MASTER / "back"
SHINY_DIR      = SPRITES_MASTER / "shiny"
BACK_SHINY_DIR = SPRITES_MASTER / "back" / "shiny"


def slugify(name: str) -> str:
    """Convert a Pokémon name to the game's asset folder slug convention."""
    # Handle multiline CSV cells (e.g. "Venusaur\nMega Venusaur") — take first line.
    name = name.strip().split("\n")[0]
    # Normalize unicode (accented chars → base ASCII where possible).
    name = unicodedata.normalize("NFKD", name)
    result: list[str] = []
    for ch in name:
        if ch.isascii() and ch.isalpha():
            result.append(ch.lower())
        elif ch in ("'", ".", "-", " ", ":", "_"):
            result.append("_")
        elif ch == "\u2640":   # ♀  — Nidoran♀ → "nidoran" (same folder as ♂)
            pass
        elif ch == "\u2642":   # ♂
            pass
        # All other non-ASCII, non-alphanumeric chars are dropped.
    slug = "_".join(p for p in "".join(result).split("_") if p)
    return slug


def build_dex_to_slug() -> dict[int, str]:
    """
    Parse all_pokemon.csv.  Returns {dex_int: slug} taking the FIRST row
    per dex number (so base forms win over Mega/variant rows that share a dex).
    """
    mapping: dict[int, str] = {}
    with open(CSV_PATH, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            raw = row.get("#", "").strip()
            if not raw.isdigit():
                continue
            dex = int(raw)
            if dex not in mapping:
                mapping[dex] = slugify(row["Name"])
    return mapping


def copy_sprite(src: Path, dst: Path, dry_run: bool) -> bool:
    """Copy src → dst if src exists.  Returns True on success."""
    if not src.exists():
        return False
    if not dry_run:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    return True


def main() -> None:
    dry_run = "--apply" not in sys.argv
    if dry_run:
        print("DRY-RUN mode — pass --apply to actually copy files.\n")
    else:
        print("APPLY mode — files will be overwritten.\n")

    dex_to_slug = build_dex_to_slug()

    # Build set of existing asset folder names for matching feedback.
    existing_folders = {p.name for p in ASSETS_DIR.iterdir() if p.is_dir()} if ASSETS_DIR.exists() else set()

    stats = {"copied": 0, "no_source": 0, "no_folder": 0, "skipped_dex": 0}
    slug_seen: set[str] = set()   # track first-dex-wins per slug

    for dex in sorted(dex_to_slug):
        slug = dex_to_slug[dex]
        if slug in slug_seen:
            stats["skipped_dex"] += 1
            continue
        slug_seen.add(slug)

        if slug not in existing_folders:
            stats["no_folder"] += 1
            print(f"  [NO FOLDER] #{dex:04d} → '{slug}' (no matching assets dir)")
            continue

        out_dir = ASSETS_DIR / slug

        # ── front ────────────────────────────────────────────────────────────
        front_src = SPRITES_MASTER / f"{dex}.png"

        if copy_sprite(front_src, out_dir / "front.png", dry_run):
            print(f"  [front]  #{dex:04d} {slug}")
            stats["copied"] += 1
        else:
            print(f"  [MISSING] #{dex:04d} {slug} — no front source in sprites-master")
            stats["no_source"] += 1
            continue

        # ── back ─────────────────────────────────────────────────────────────
        copy_sprite(BACK_DIR / f"{dex}.png",       out_dir / "back.png",        dry_run)

        # ── shiny variants ───────────────────────────────────────────────────
        copy_sprite(SHINY_DIR / f"{dex}.png",      out_dir / "front_shiny.png", dry_run)
        copy_sprite(BACK_SHINY_DIR / f"{dex}.png", out_dir / "back_shiny.png",  dry_run)

    print(f"\nSummary:")
    print(f"  Processed  : {stats['copied']}")
    print(f"  No source  : {stats['no_source']}  (not in sprites-master)")
    print(f"  No folder  : {stats['no_folder']}  (no matching assets/sprites/pokemon/ dir)")
    print(f"  Slug dupes : {stats['skipped_dex']}  (later dex sharing a slug — skipped)")
    if dry_run:
        print("\nRe-run with --apply to execute.")


if __name__ == "__main__":
    main()
