"""
import_sprites_from_master.py

Copies front + back sprites from sprites-master (numbered by national dex) into
the project's assets/sprites/pokemon/{id}/ folders.

Usage (run from project root):
    python3 tools/import_sprites_from_master.py

What it does:
  - Reads every data/pokemon/*.json file that has a national_dex number
  - Copies sprites-master/sprites/pokemon/{dex}.png   → front.png
  - Copies sprites-master/sprites/pokemon/back/{dex}.png → back.png
    (falls back to front.png if back sprite does not exist)
  - Skips fakemons / custom variants (national_dex == null)
  - Only touches files whose destination is a placeholder (< 400 bytes) OR
    pass --force to overwrite everything

After running, re-import in the Godot editor so .import files are refreshed.
"""

import argparse
import json
import os
import shutil

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR     = os.path.join(PROJECT_ROOT, "data", "pokemon")
ASSETS_DIR   = os.path.join(PROJECT_ROOT, "assets", "sprites", "pokemon")

SPRITES_MASTER = r"C:\Users\levib\pokemon_projects\primal_harmony\sprites-master\sprites\pokemon"
FRONT_DIR = SPRITES_MASTER
BACK_DIR  = os.path.join(SPRITES_MASTER, "back")

PLACEHOLDER_MAX_BYTES = 400   # real sprites are always larger than this


def is_placeholder(path: str) -> bool:
    """Return True if the file looks like a tiny checkerboard placeholder."""
    try:
        return os.path.getsize(path) <= PLACEHOLDER_MAX_BYTES
    except FileNotFoundError:
        return True   # missing == treat as placeholder


def copy_sprite(src: str, dst: str, force: bool) -> str:
    """Copy src → dst; returns 'copied', 'skipped', or 'missing_src'."""
    if not os.path.exists(src):
        return "missing_src"
    if not force and not is_placeholder(dst):
        return "skipped"
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    return "copied"


def main() -> None:
    parser = argparse.ArgumentParser(description="Import sprites from sprites-master")
    parser.add_argument("--force", action="store_true",
                        help="Overwrite even non-placeholder sprites")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would be copied without doing it")
    args = parser.parse_args()

    json_files = sorted(f for f in os.listdir(DATA_DIR) if f.endswith(".json"))

    stats = {"copied": 0, "skipped": 0, "missing_src": 0, "no_dex": 0}
    back_fallbacks = []

    for fname in json_files:
        with open(os.path.join(DATA_DIR, fname), encoding="utf-8") as fp:
            data = json.load(fp)

        dex = data.get("national_dex")
        pid = data.get("id", fname[:-5])

        if dex is None:
            stats["no_dex"] += 1
            continue

        front_src = os.path.join(FRONT_DIR, f"{dex}.png")
        back_src  = os.path.join(BACK_DIR,  f"{dex}.png")
        front_dst = os.path.join(ASSETS_DIR, pid, "front.png")
        back_dst  = os.path.join(ASSETS_DIR, pid, "back.png")

        # --- Front ---
        if args.dry_run:
            action = "would copy" if (args.force or is_placeholder(front_dst)) else "would skip"
            src_exists = "Y" if os.path.exists(front_src) else "N"
            print(f"[front] {pid:30s} dex={dex:5d}  src={src_exists}  {action}")
        else:
            result = copy_sprite(front_src, front_dst, args.force)
            stats[result] += 1

        # --- Back (fall back to front if missing) ---
        actual_back_src = back_src if os.path.exists(back_src) else front_src
        if not os.path.exists(back_src):
            back_fallbacks.append(pid)

        if args.dry_run:
            fallback_note = " (FALLBACK to front)" if not os.path.exists(back_src) else ""
            action = "would copy" if (args.force or is_placeholder(back_dst)) else "would skip"
            print(f"[back ] {pid:30s} dex={dex:5d}{fallback_note}  {action}")
        else:
            result = copy_sprite(actual_back_src, back_dst, args.force)
            stats[result] += 1

    if not args.dry_run:
        print("\n=== Done ===")
        print(f"  Copied    : {stats['copied']}")
        print(f"  Skipped   : {stats['skipped']}  (already real, use --force to overwrite)")
        print(f"  Missing src: {stats['missing_src']}")
        print(f"  No dex (fakemons): {stats['no_dex']}")
        if back_fallbacks:
            print(f"\n  Back sprite used front as fallback for {len(back_fallbacks)} Pokémon:")
            for p in back_fallbacks[:20]:
                print(f"    {p}")
            if len(back_fallbacks) > 20:
                print(f"    ... and {len(back_fallbacks) - 20} more")
        print("\nNow re-open the Godot project to trigger .import file refresh.")


if __name__ == "__main__":
    main()
