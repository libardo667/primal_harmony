# m007 - TOZ 02 Static Sprawl Data

## Metadata

- ID: m007-toz-02-static-sprawl-data
- Type: minor
- Owner: Antigravity
- Status: backlog
- Risk: low
- Created: 2026-03-06
- Contract Impact: none
- Default-Path Impact: core_path
- Artifact Outputs: `data/ecology/zones/02_static_sprawl.json`

## Problem

Zone 02 (The Static Sprawl) is a critical early-game milestone (`docs/TOZ_field_atlas_v0.2.md`). Its data and the associated rewards (fast-travel network) are currently undocumented in the code.

## Proposed Solution

Codify the Static Sprawl zone data into a JSON resource:
1.  Define the `native_species` list for New Mauville/Route 110.
2.  Define corrupted variants (Staticorb, Galvantrike, Fulgrite).
3.  Define the `quell_requirements` (Ground-type releases + Discharge Rod interaction).
4.  Define the `restoration_effects` (Mauville power grid / Fast-travel unlock).

## Files Affected

- `data/ecology/zones/02_static_sprawl.json` [NEW]
- `data/ecology/toz_registry.json` [MODIFY]

## Acceptance Criteria

- [ ] Zone 02 data is correctly registered.
- [ ] Fast-travel unlock logic is correctly hooked to the zone's restoration state.
- [ ] Variant typing and lore match the field atlas precisely.

## Validation Commands

- `python scripts/dev.py quality-strict`
- `python scripts/dev.py harness lint zone-data`

## Pruning Prevention Controls

- Authoritative path: `data/ecology/zones/`
- Parallel path introduced: none
- Artifact output target: `data/ecology/zones/`
- Default-path impact: core_path

## Risks and Rollback

- Risk: Complexity in the Discharge Rod interaction logic could lead to soft-locks if not handled gracefully.
- Rollback: Revert JSON changes.

## Execution Log

- [2026-03-06] Item drafted based on `docs/TOZ_field_atlas_v0.2.md`.
