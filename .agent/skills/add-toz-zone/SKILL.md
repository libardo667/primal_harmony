# Skill: add-toz-zone

**When to use this skill:** When implementing a Type Overload Zone — creating its data, map, encounter system, and visual state.

**Primary agents:** The Keeper (data), The Shaper (map), The Mechanic (encounter integration), The Weaver (NPC events), The Artisan (zone tileset)

---

## Zone Implementation Checklist

All 10 zones are documented in `docs/TOZ_field_atlas_v0.2.md`. Use that document as the source of truth for every field below.

---

## Phase 1 — Data Layer (The Keeper does this first)

### 1a. Create Zone JSON

Create `data/zones/[zone_id].json` using the schema:

```json
{
  "zone_id": "ashen_glacier",
  "zone_name": "The Ashen Glacier",
  "zone_number": 1,
  "dominant_type": "Ice",
  "location_description": "Route 113 / Fallarbor Town",
  "ehi_local": 0.0,
  "ehi_restoration_impact": "Thaws ash, reopens Fallarbor flower shop",
  "encounter_table": {
    "infested": [],
    "partial": [],
    "restored": []
  },
  "native_species": ["spinda", "skarmory", "swablu", "zangoose", "seviper"],
  "corrupted_variants": ["frostinda", "glaciory", "ashviper"],
  "quell_types": ["Fire", "Fighting", "Rock", "Steel"],
  "traversal_hazards": [
    "Slip-and-slide physics on frozen surfaces",
    "Cleats item or Ice-type lead required for certain paths",
    "Periodic frozen ash whiteout conditions"
  ],
  "required_items": ["cleats"],
  "narrative_gate": null
}
```

Log: `python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Keeper" "Zone data complete — [zone_name]. JSON at data/zones/[zone_id].json."`

### 1b. Populate Encounter Tables

For each EHI state, list 6–10 Pokémon IDs:
- **Infested:** Mostly non-native invaders + corrupted variants (80% non-native, 20% corrupted variants)
- **Partial:** Mixed — transitional species, some natives returning (50/50)
- **Restored:** Mostly native Hoenn species, rare spawns accessible (80% native, 20% invader remnants)

---

## Phase 2 — Visual/Map Layer (The Artisan then The Shaper)

### 2a. Artisan — Zone Tileset

Create or source a tileset that reflects the zone's visual distortion:
- Zone name and type as folder: `assets/tilesets/[zone_id]/`
- Three variants: `infested.tres`, `partial.tres`, `restored.tres` (or a single tileset with EHI-driven overlay)
- Log path and tile size to comms log before handing to Shaper

### 2b. Shaper — Zone Map Scene

Create the map scene with full structure (see `wake-shaper.md` for scene template).

Key zone-specific requirements:
- `EncounterZones` tagged with `zone_id` matching the JSON
- `ZoneOverlay` node present and connected to EHI signal
- `WarpPoints` connecting to adjacent city/route scenes
- `NPCSpawnPoints` at distress positions (for The Weaver)
- Document visual state logic in scene comments

Run `python3 tools/audit_tscn.py .` before handing off. Zero errors required.

---

## Phase 3 — Systems Integration (The Mechanic)

### 3a. Verify EncounterManager reads zone

Confirm `EncounterManager.gd` will correctly load `data/zones/[zone_id].json` and filter by local EHI. No code changes needed if the system is generic — just confirm the zone_id is correct.

### 3b. EHI zone registration

Confirm EHI system has the zone registered. Add to initial zone dictionary if needed:
```gdscript
var zone_ehi: Dictionary = {
    "ashen_glacier": 0.0,
    # ... other zones
}
```

---

## Phase 4 — Narrative Layer (The Weaver)

### 4a. Zone entry NPC events

- Distress NPC at zone border (infested state dialogue)
- Restoration NPC for post-quell state (check EHI signal)
- Any zone-specific story beats from TOZ atlas

### 4b. Quell event trigger

Script the relocation terminal event for this zone's quell types. The terminal is in the nearest Pokémon Center.

---

## Completion Log Template

```bash
python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Keeper" "Zone data complete — [zone_name]. JSON at data/zones/[zone_id].json. Encounter tables populated for all 3 states. Ready for The Artisan to begin tileset."

python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Artisan" "Tileset complete — [zone_id]. Path: res://assets/tilesets/[zone_id]/. Tile size: 16x16. Ready for The Shaper to build map."

python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Shaper" "Map complete — [map_scene_name].tscn. [X] EncounterZones, [Y] WarpPoints, [Z] NPCSpawnPoints. Ready for The Mechanic to verify encounter integration and The Weaver for NPC scripts."
```
