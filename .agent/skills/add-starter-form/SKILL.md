# Skill: add-starter-form

**When to use this skill:** When implementing one of the 18 starter evolution forms — corrupted, partial, or restored path.

**Primary agents:** The Keeper (data), The Artisan (sprites)

Reference: `docs/TOZ_field_atlas_v0.2.md` — "Corrupted Starter Evolution Paths" section

---

## The 18 Forms at a Glance

Each of the 3 starters has 6 possible forms across 3 paths:

| Path | Stage 1 (L16) | Stage 2 (L36) | Trigger |
|---|---|---|---|
| Fully Corrupted | Form A1 | Form A2 | No healing items used |
| Partial Healing | Form B1 | Form B2 | One cleanse at L16 branch |
| Full Restoration | Form C1 | Form C2 | Two cleanses (L16 + L36) |

**Treecko corruption:** Bug / Rock → see atlas for all 6 form names and typings
**Torchic corruption:** Fighting / Steel → see atlas
**Mudkip corruption:** Ghost / Fairy → see atlas

---

## Step 1 — Confirm Form Identity

Before touching any file, confirm from the atlas:
- [ ] Base starter (treecko / torchic / mudkip)
- [ ] Path (corrupted / partial / restored)
- [ ] Stage (1 = L16, 2 = L36)
- [ ] Form name (e.g., `scleecko`)
- [ ] Form ID (lowercase, underscores: `scleecko`)
- [ ] Typing (e.g., `Bug / Rock`)

---

## Step 2 — Create Form JSON (The Keeper)

Create `data/starters/[form_id].json`:

```json
{
  "id": "scleecko",
  "name": "Scleecko",
  "base_species": "treecko",
  "path": "corrupted",
  "stage": 1,
  "types": ["Bug", "Rock"],
  "base_stats": {
    "hp": 45,
    "atk": 55,
    "def": 55,
    "spa": 45,
    "spd": 45,
    "spe": 65
  },
  "abilities": ["Sturdy"],
  "hidden_ability": "Sand Rush",
  "learnset": [],
  "evolution": {
    "method": "level",
    "level": 36,
    "into": "carapecko",
    "path_requirement": "corrupted"
  },
  "dex_entry": "Its skin has hardened into chitinous plates, its green entirely faded to grey-brown. The adhesive pads on its feet have become rock-boring hooks.",
  "is_starter_form": true,
  "cleanse_branches_to": null,
  "sprites": {
    "front": "res://assets/sprites/pokemon/scleecko/front.png",
    "back": "res://assets/sprites/pokemon/scleecko/back.png",
    "icon": "res://assets/sprites/pokemon/scleecko/icon.png"
  }
}
```

**Stat guidance by path:**
- Corrupted path: skew toward Attack / Defense
- Partial healing path: balanced, slight Speed / Sp. Atk lean
- Full restoration path: skew toward Speed / Sp. Atk

BST should be comparable to standard Pokémon at the same evolutionary stage. Check Treecko (240), Grovyle (270), Sceptile (530) as reference points.

---

## Step 3 — Register Cleanse Branching (The Keeper)

The cleanse branching logic lives in the starter's base entry. Update `data/starters/[base_starter].json` to register the branch:

```json
{
  "id": "treecko_corrupted",
  "cleanse_branches": {
    "stage_1_no_cleanse": "scleecko",
    "stage_1_one_cleanse": "mossecko",
    "stage_1_two_cleanses": "leafecko"
  }
}
```

---

## Step 4 — Create Sprite Placeholder (The Artisan)

```
assets/sprites/pokemon/[form_id]/
├── front_placeholder.png
├── back_placeholder.png
└── icon_placeholder.png
```

Each placeholder: solid color rectangle (use a color that reflects the form's typing — blue-grey for corrupted Treecko, green-tinged for restored) with the form name as text.

Log: `[PLACEHOLDER] [form_id] sprites — final art pending`

---

## Step 5 — Log Completion

```bash
python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Keeper" "Starter form complete — [FormName]. Path: [path], Stage [N]. JSON at data/starters/[id].json."
```

---

## All 18 Form IDs for Reference

**Treecko line:**
- Corrupted: `scleecko` (L16), `carapecko` (L36)
- Partial: `mossecko` (L16), `silkvine` (L36)
- Restored: `leafecko` (L16), `verdacko` (L36)

**Torchic line:**
- Corrupted: `clenchic` (L16), `forgechic` (L36)
- Partial: `embrawl` (L16), `scorcombat` (L36)
- Restored: `kindlic` (L16), `blazeborn` (L36)

**Mudkip line:**
- Corrupted: `phantokip` (L16), `wraithdew` (L36)
- Partial: `murkip` (L16), `tidemere` (L36)
- Restored: `clearkip` (L16), `marshborn` (L36)
