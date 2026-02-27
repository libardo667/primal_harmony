"""extract_npc_lore.py

Reads every pokeemerald data/maps/*/map.json and data/maps/*/scripts.inc,
then produces data/npc_lore.json — a writer's reference for Primal Harmony
NPC dialogue and placement.

This file is NOT loaded at runtime. It is a narrative research tool.
Each NPC entry records:
  - Their position, sprite type, movement pattern
  - ALL dialogue they could say in the original game (all state branches)
  - Whether they are normally hidden by a flag

Run from the project root:
  /c/Users/levib/anaconda3/python.exe tools/extract_npc_lore.py
"""

import json
import os
import re
from pathlib import Path

POKEEMERALD  = Path("C:/Users/levib/pokemon_projects/pokeemerald")
PROJECT_ROOT = Path("c:/Users/levib/pokemon_projects/primal_harmony/primal-harmony")
MAPS_DIR     = POKEEMERALD / "data" / "maps"
OUT_FILE     = PROJECT_ROOT / "data" / "npc_lore.json"

# Sprite subdirectories to search, in priority order
SPRITE_DIRS = [
    "assets/sprites/npcs",
    "assets/sprites/npcs/gym_leaders",
    "assets/sprites/npcs/frontier_brains",
    "assets/sprites/npcs/team_aqua",
    "assets/sprites/npcs/team_magma",
]


# ── Sprite path resolution ─────────────────────────────────────────────────────

def gfx_to_sprite_path(gfx_id: str) -> str:
    """
    'OBJ_EVENT_GFX_FAT_MAN' → 'res://assets/sprites/npcs/fat_man_spriteframes.tres'
    Returns '' if no matching .tres was found in our project.
    """
    prefix = "OBJ_EVENT_GFX_"
    key = gfx_id[len(prefix):].lower() if gfx_id.startswith(prefix) else gfx_id.lower()
    filename = f"{key}_spriteframes.tres"
    for subdir in SPRITE_DIRS:
        disk_path = PROJECT_ROOT / subdir / filename
        if disk_path.exists():
            return f"res://{subdir}/{filename}"
    return ""


# ── scripts.inc parser ─────────────────────────────────────────────────────────

# Format codes used in pokeemerald text (clean for readability)
_FORMAT_SUB = [
    (r"\{PLAYER\}",  "[PLAYER]"),
    (r"\{RIVAL\}",   "[RIVAL]"),
    (r"\{COLOR[^}]*\}", ""),   # color codes
    (r"\{[^}]+\}",   ""),      # any other braces
    (r"\\n",  " "),
    (r"\\l",  " "),
    (r"\\p",  " / "),    # page break becomes " / "
    (r"\\c",  ""),
    (r"\\r",  ""),
    (r"\$",   ""),
]

def _clean(raw: str) -> str:
    s = raw
    for pat, repl in _FORMAT_SUB:
        s = re.sub(pat, repl, s)
    return re.sub(r" {2,}", " ", s).strip()


def parse_scripts_inc(path: Path) -> tuple[dict, dict]:
    """
    Returns:
      text_content  : {label: [page_string, ...]}   — text label → message pages
      script_targets: {label: {"msgboxes": [...], "gotos": [...]}}
    Both single-colon (:) and double-colon (::) labels are captured.
    """
    if not path.exists():
        return {}, {}

    text_content:   dict[str, list[str]] = {}
    script_targets: dict[str, dict]       = {}

    # Regex patterns
    label_re   = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)::?$")
    string_re  = re.compile(r'^\s*\.string\s+"(.*)"')
    msgbox_re  = re.compile(r"^\s*(?:msgbox|message)\s+(\S+)")
    goto_re    = re.compile(r"^\s*(?:goto|call)(?:_if_\S+)?\s+(?:\S+,\s*)?(\S+)")

    current_label: str | None = None
    in_text_block = False
    buf: list[str] = []         # raw string accumulator for text blocks
    msgboxes: list[str] = []
    gotos:    list[str] = []

    def flush():
        nonlocal current_label, in_text_block, buf, msgboxes, gotos
        if current_label is None:
            return
        if in_text_block:
            # Split on $ to get individual messages, strip empties
            raw = "".join(buf)
            pages = [_clean(p) for p in raw.split("$") if p.strip().replace(" ", "")]
            if pages:
                text_content[current_label] = pages
        else:
            if msgboxes or gotos:
                script_targets[current_label] = {
                    "msgboxes": list(msgboxes),
                    "gotos":    list(gotos),
                }
        current_label = None
        in_text_block = False
        buf = []
        msgboxes = []
        gotos = []

    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()

        # Skip blank lines and comments
        if not line or line.startswith("@") or line.startswith("//"):
            continue

        # New label?
        lm = label_re.match(line)
        if lm:
            flush()
            current_label = lm.group(1)
            # A label is a "text block" if its name contains "_Text_" or it
            # immediately starts collecting .string lines (determined lazily).
            in_text_block = "_Text_" in current_label or "_text_" in current_label
            continue

        if current_label is None:
            continue

        # Inside a block — classify lines
        sm = string_re.match(line)
        if sm:
            in_text_block = True          # confirm it's a text block
            buf.append(sm.group(1))
            continue

        mm = msgbox_re.match(line)
        if mm:
            lbl = mm.group(1).rstrip(",")
            if lbl and not lbl.startswith('"'):
                msgboxes.append(lbl)
            continue

        gm = goto_re.match(line)
        if gm:
            lbl = gm.group(1).rstrip(",")
            if lbl and not lbl.startswith('"') and not lbl[0].isdigit():
                gotos.append(lbl)

    flush()
    return text_content, script_targets


# ── Dialogue collection via BFS ────────────────────────────────────────────────

def collect_dialogue(
    entry_script: str,
    text_content: dict,
    script_targets: dict,
    max_depth: int = 6,
) -> dict[str, list[str]]:
    """
    BFS from entry_script through goto/call branches.
    Collects all reachable msgbox text.
    Returns {text_label: [pages]}.
    """
    if not entry_script:
        return {}

    dialogue: dict[str, list[str]] = {}
    visited: set[str] = set()
    queue = [entry_script]
    depth_map = {entry_script: 0}

    while queue:
        label = queue.pop(0)
        if label in visited:
            continue
        visited.add(label)
        depth = depth_map.get(label, 0)
        if depth > max_depth:
            continue

        info = script_targets.get(label, {})

        # Collect msgbox targets
        for tl in info.get("msgboxes", []):
            if tl in text_content and tl not in dialogue:
                dialogue[tl] = text_content[tl]

        # Follow gotos (only within the same map namespace to avoid huge fan-out)
        entry_prefix = entry_script.split("_EventScript_")[0] if "_EventScript_" in entry_script else ""
        for gl in info.get("gotos", []):
            if gl not in visited:
                # Only follow same-map scripts to avoid chasing into common scripts
                if not entry_prefix or gl.startswith(entry_prefix) or gl.startswith("Common_"):
                    depth_map[gl] = depth + 1
                    queue.append(gl)

    # Fallback: if no dialogue found via BFS, try text label by name substitution
    if not dialogue and "_EventScript_" in entry_script:
        text_equiv = entry_script.replace("_EventScript_", "_Text_")
        if text_equiv in text_content:
            dialogue[text_equiv] = text_content[text_equiv]
        # Also look for multi-state variants: _EventScript_Foo → _Text_Foo*
        prefix = text_equiv
        for k, v in text_content.items():
            if k.startswith(prefix) and k not in dialogue:
                dialogue[k] = v

    return dialogue


# ── Movement type → readable label ────────────────────────────────────────────

_MOVEMENT_LABELS = {
    "MOVEMENT_TYPE_NONE":                    "static",
    "MOVEMENT_TYPE_LOOK_AROUND":             "look_around",
    "MOVEMENT_TYPE_WANDER_AROUND":           "wander",
    "MOVEMENT_TYPE_WANDER_UP_AND_DOWN":      "wander_ud",
    "MOVEMENT_TYPE_WANDER_LEFT_AND_RIGHT":   "wander_lr",
    "MOVEMENT_TYPE_WALK_BACK_AND_FORTH":     "pace",
    "MOVEMENT_TYPE_FACE_DOWN":               "face_down",
    "MOVEMENT_TYPE_FACE_UP":                 "face_up",
    "MOVEMENT_TYPE_FACE_LEFT":              "face_left",
    "MOVEMENT_TYPE_FACE_RIGHT":             "face_right",
    "MOVEMENT_TYPE_PLAYER":                  "player",
    "MOVEMENT_TYPE_ROTATE_COUNTERCLOCKWISE": "rotate_ccw",
    "MOVEMENT_TYPE_ROTATE_CLOCKWISE":        "rotate_cw",
    "MOVEMENT_TYPE_WALK_SEQUENCE_DOWN_RIGHT_LEFT_UP":  "walk_sequence",
    "MOVEMENT_TYPE_WALK_SEQUENCE_RIGHT_LEFT_DOWN_UP":  "walk_sequence",
    "MOVEMENT_TYPE_WALK_SEQUENCE_LEFT_RIGHT_UP_DOWN":  "walk_sequence",
    "MOVEMENT_TYPE_WALK_SEQUENCE_UP_DOWN_RIGHT_LEFT":  "walk_sequence",
    "MOVEMENT_TYPE_WALK_SEQUENCE_UP_LEFT_DOWN_RIGHT":  "walk_sequence",
    "MOVEMENT_TYPE_WALK_SEQUENCE_DOWN_LEFT_RIGHT_UP":  "walk_sequence",
    "MOVEMENT_TYPE_WALK_SEQUENCE_UP_RIGHT_DOWN_LEFT":  "walk_sequence",
    "MOVEMENT_TYPE_WALK_SEQUENCE_LEFT_DOWN_UP_RIGHT":  "walk_sequence",
    "MOVEMENT_TYPE_COPY_PLAYER":             "copy_player",
    "MOVEMENT_TYPE_TREE_DISGUISE":           "tree_disguise",
    "MOVEMENT_TYPE_MOUNTAIN_DISGUISE":       "mountain_disguise",
    "MOVEMENT_TYPE_BURIED":                  "buried",
    "MOVEMENT_TYPE_INVISIBLE":               "invisible",
    "MOVEMENT_TYPE_WALK_IN_PLACE_DOWN":      "face_down",
    "MOVEMENT_TYPE_WALK_IN_PLACE_UP":        "face_up",
    "MOVEMENT_TYPE_WALK_IN_PLACE_LEFT":      "face_left",
    "MOVEMENT_TYPE_WALK_IN_PLACE_RIGHT":     "face_right",
}

def movement_label(mt: str) -> str:
    return _MOVEMENT_LABELS.get(mt, mt.replace("MOVEMENT_TYPE_", "").lower())


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    map_dirs = sorted(
        d for d in MAPS_DIR.iterdir()
        if d.is_dir() and (d / "map.json").exists()
    )

    print(f"extract_npc_lore: scanning {len(map_dirs)} map directories...")

    result: dict = {}
    total_npcs        = 0
    npcs_with_text    = 0
    npcs_with_sprites = 0
    maps_with_npcs    = 0

    for map_dir in map_dirs:
        with open(map_dir / "map.json", encoding="utf-8") as f:
            mdata = json.load(f)

        map_id: str     = mdata["id"]
        obj_events: list = mdata.get("object_events") or []

        if not obj_events:
            continue

        # Parse scripts for this map
        text_content, script_targets = parse_scripts_inc(map_dir / "scripts.inc")

        entries = []
        for obj in obj_events:
            gfx_id      = obj.get("graphics_id", "")
            script_name = obj.get("script", "")
            flag        = str(obj.get("flag", "0"))
            trainer_t   = obj.get("trainer_type", "TRAINER_TYPE_NONE")
            mv_type     = obj.get("movement_type", "")

            sprite_path = gfx_to_sprite_path(gfx_id)
            dialogue    = collect_dialogue(script_name, text_content, script_targets)

            entry = {
                "local_id":     obj.get("local_id", ""),
                "script_name":  script_name,
                "sprite_gfx":   gfx_id,
                "sprite_path":  sprite_path,
                "tile_x":       int(obj.get("x", 0)),
                "tile_y":       int(obj.get("y", 0)),
                "movement":     movement_label(mv_type),
                "movement_raw": mv_type,
                "range_x":      int(obj.get("movement_range_x", 0)),
                "range_y":      int(obj.get("movement_range_y", 0)),
                "trainer_type": trainer_t,
                # flag == "0" means always visible; a FLAG_HIDE_* means conditionally shown
                "conditionally_hidden": flag not in ("0", "FLAG_TEMP_2", ""),
                "hide_flag":    flag if flag not in ("0", "") else "",
                # All dialogue this NPC can say across all story states
                "original_dialogue": dialogue,
            }

            entries.append(entry)
            total_npcs += 1
            if dialogue:
                npcs_with_text += 1
            if sprite_path:
                npcs_with_sprites += 1

        if entries:
            result[map_id] = entries
            maps_with_npcs += 1

    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_FILE, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)

    print(f"  {maps_with_npcs} maps with NPCs")
    print(f"  {total_npcs} total NPCs")
    print(f"  {npcs_with_text} with dialogue extracted  ({100*npcs_with_text//max(total_npcs,1)}%)")
    print(f"  {npcs_with_sprites} with matching sprite files ({100*npcs_with_sprites//max(total_npcs,1)}%)")
    print(f"  Written to: {OUT_FILE}")


if __name__ == "__main__":
    main()
