# Skill: validate-data-schema

**When to use this skill:** Before logging any data file as complete, or when The Elder asks for a schema audit. Also use when encountering a "key not found" error from DataManager.

**Primary agents:** The Keeper, The Elder

---

## Why This Matters

GDScript will not crash loudly when loading a JSON key that doesn't exist — it will return `null` and the bug surfaces later, far from the source. Validating schemas before handing off to The Mechanic prevents this class of error entirely.

---

## Validation Checklist

### For Every Pokémon JSON (`data/pokemon/[id].json`)

- [ ] `id` — matches filename (no spaces, lowercase, underscores)
- [ ] `name` — display name, properly capitalized
- [ ] `types` — array, 1 or 2 entries, valid type strings
- [ ] `base_stats` — object with exactly: `hp`, `atk`, `def`, `spa`, `spd`, `spe`
- [ ] `abilities` — array, at least 1 entry
- [ ] `hidden_ability` — string or `null`
- [ ] `learnset` — array (can be empty `[]` but must exist)
- [ ] `evolution` — object with `method`, `level`/`item`, `into` — or `null`
- [ ] `dex_entry` — string (can be empty but must exist)
- [ ] `is_corrupted` — boolean
- [ ] `corruption_zone` — string or `null`
- [ ] `sprites` — object with `front`, `back`, `icon` (all `res://` paths)

### For Every Zone JSON (`data/zones/[zone_id].json`)

- [ ] `zone_id` — matches filename
- [ ] `zone_name` — display name
- [ ] `zone_number` — integer 1–10
- [ ] `dominant_type` — valid type string
- [ ] `ehi_local` — float 0.0
- [ ] `encounter_table` — object with exactly: `infested`, `partial`, `restored` (each an array)
- [ ] `native_species` — array of valid species IDs (cross-check `data/pokemon/`)
- [ ] `corrupted_variants` — array of valid corrupted IDs (cross-check `data/pokemon/`)
- [ ] `quell_types` — array of valid type strings
- [ ] `required_items` — array (can be empty)
- [ ] `narrative_gate` — string or `null`

### For Every Starter Form JSON (`data/starters/[form_id].json`)

- [ ] All standard Pokémon fields (see above)
- [ ] `is_starter_form` — boolean `true`
- [ ] `base_species` — valid base starter ID
- [ ] `path` — one of: `"corrupted"`, `"partial"`, `"restored"`
- [ ] `stage` — integer 1 or 2
- [ ] `cleanse_branches_to` — form ID string or `null`

---

## Cross-Reference Checks

After validating individual files, run these cross-checks:

1. **Zone ↔ Pokémon:** Every ID in `zone.native_species` and `zone.corrupted_variants` must have a corresponding file in `data/pokemon/`.

2. **Corrupted variant ↔ zone:** Every `data/pokemon/[id].json` where `is_corrupted: true` must have its `corruption_zone` registered in `data/zones/[zone_id].json.corrupted_variants`.

3. **Starter form ↔ branching:** Every form ID in a base starter's `cleanse_branches` must have a corresponding file in `data/starters/`.

4. **Sprite paths exist:** Every `sprites.front/back/icon` path must point to an existing file (placeholder or final).

---

## How to Log a Schema Audit

```bash
python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Keeper" "Schema audit complete for [scope]. Files: [list]. Issues: [none/details]."
```

If issues are found, fix them before logging completion. Do not pass broken schemas forward.
