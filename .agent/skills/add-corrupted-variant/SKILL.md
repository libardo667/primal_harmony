# Skill: add-corrupted-variant

**When to use this skill:** When adding a new Corrupted Regional Variant — a native Hoenn Pokémon mutated by a Type Overload Zone.

**Primary agents:** The Keeper (data), The Artisan (sprites)

---

## What Is a Corrupted Regional Variant?

A native Hoenn Pokémon whose typing, moveset, and appearance have been warped by prolonged exposure to a Type Overload Zone. They are not invaders — they are victims. The corrupted form is valid and can be kept by the player; healing is a choice, not a requirement.

Reference: `docs/TOZ_field_atlas_v0.2.md` — each zone section contains seeded variant entries.

---

## Step 1 — Establish Identity

Before touching any file, confirm:
- [ ] **Base species** (e.g., Spinda)
- [ ] **Zone** (e.g., `ashen_glacier`)
- [ ] **Corrupted name** (e.g., `frostinda`)
- [ ] **Corrupted typing** (e.g., `Ice / Normal`)
- [ ] **Corrupted species ID** (convention: `[corrupted_name]`, lowercase, underscores) — e.g., `frostinda`
- [ ] **Base species ID** for reference: `spinda`

Log: `python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Keeper" "[identity details]"`

---

## Step 2 — Create the Pokémon JSON (The Keeper)

Create `data/pokemon/[corrupted_id].json`:

```json
{
  "id": "frostinda",
  "name": "Frostinda",
  "types": ["Ice", "Normal"],
  "base_stats": {
    "hp": 60,
    "atk": 45,
    "def": 50,
    "spa": 45,
    "spd": 50,
    "spe": 55
  },
  "abilities": ["Refrigerate"],
  "hidden_ability": "Slush Rush",
  "learnset": [],
  "evolution": null,
  "dex_entry": "Its spots have become frozen patches of crystalline ice. Each spot is a different temperature, causing it to spin erratically on icy terrain.",
  "is_corrupted": true,
  "corruption_zone": "ashen_glacier",
  "corruption_path": "full_corrupted",
  "base_species": "spinda",
  "healable": true,
  "heal_result": "spinda",
  "sprites": {
    "front": "res://assets/sprites/pokemon/frostinda/front.png",
    "back": "res://assets/sprites/pokemon/frostinda/back.png",
    "icon": "res://assets/sprites/pokemon/frostinda/icon.png"
  }
}
```

**Stat guidance:**
- Corrupted variants should feel distinct but balanced — usually shift 20–30 BST points toward the corruption type's strengths
- Check base species stats in `data/pokemon/[base_species].json` for reference

---

## Step 3 — Register in Zone Data (The Keeper)

Open `data/zones/[zone_id].json` and add the corrupted variant's ID to `corrupted_variants`:

```json
{
  "corrupted_variants": ["frostinda", "glaciory", "ashviper"]
}
```

Also add to the appropriate `encounter_table.infested` array so it spawns in the zone.

---

## Step 4 — Create Sprite Placeholder (The Artisan)

If final art doesn't exist, create a placeholder immediately — don't block data progress:

```
assets/sprites/pokemon/frostinda/
├── front_placeholder.png    ← solid color with species name labeled
├── back_placeholder.png
└── icon_placeholder.png
```

Log explicitly: `[PLACEHOLDER] frostinda sprites — awaiting final art`

When final art arrives, replace placeholders and remove the placeholder suffix.

---

## Step 5 — Log Completion

```bash
python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Keeper" "Added corrupted variant Frostinda (frostinda). Zone: ashen_glacier. JSON at data/pokemon/frostinda.json. Zone encounter table updated. Ready for The Artisan to create sprite placeholder."

python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Artisan" "Created sprite placeholders for Frostinda. Paths: res://assets/sprites/pokemon/frostinda/[front/back/icon]_placeholder.png. [PLACEHOLDER] — final art pending."
```

---

## Design Source

All seeded variants are documented in `docs/TOZ_field_atlas_v0.2.md` under each zone's "Seeded Corrupted Regional Variants" section. Use the dex entries and type descriptions from that doc — do not invent lore independently.
