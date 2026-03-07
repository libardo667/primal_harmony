# m006 - TOZ 01 Ashen Glacier Data

## Metadata

- ID: m006-toz-01-ashen-glacier-data
- Type: minor
- Owner: Antigravity
- Status: backlog
- Risk: low
- Created: 2026-03-06
- Contract Impact: none
- Default-Path Impact: core_path
- Artifact Outputs: `data/ecology/zones/01_ashen_glacier.json`

## Problem

Zone 01 (The Ashen Glacier) is the first TOZ the player encounters (`docs/TOZ_field_atlas_v0.2.md`). Its specific data—affected native species, corrupted variants (Frostinda, Glaciory, Ashviper), and the Fallarbor flower shop unlock condition—exists only in documentation and not in the game's data layer.

## Proposed Solution

Codify the Ashen Glacier zone data into a JSON resource:
1.  Define the `native_species` list for Route 113.
2.  Define the `corrupted_variants` entries with their types and dex descriptors.
3.  Define the `quell_requirements` (Fire, Fighting, Rock, Steel releases).
4.  Define the `restoration_effects` (Fallarbor shop reopening).

## Files Affected

- `data/ecology/zones/01_ashen_glacier.json` [NEW]
- `data/ecology/toz_registry.json` [MODIFY]

## Acceptance Criteria

- [ ] Zone 01 data is correctly registered in the TOZ registry.
- [ ] Variant data matches the specifications in `docs/TOZ_field_atlas_v0.2.md`.
- [ ] Restoration logic correctly flags the Fallarbor flower shop as 'reopened' at 100% EHI.

## Validation Commands

- `python scripts/dev.py quality-strict`
- `python scripts/dev.py harness lint zone-data`

## Pruning Prevention Controls

- Authoritative path: `data/ecology/zones/`
- Parallel path introduced: none
- Artifact output target: `data/ecology/zones/`
- Default-path impact: core_path

## Risks and Rollback

- Risk: Typos in species names could cause runtime errors in the encounter manager.
- Rollback: Revert JSON changes.

## Execution Log

- [2026-03-06] Item drafted based on `docs/TOZ_field_atlas_v0.2.md`.
