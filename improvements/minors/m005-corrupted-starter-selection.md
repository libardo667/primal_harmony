# m005 - Corrupted Starter Selection

## Metadata

- ID: m005-corrupted-starter-selection
- Type: minor
- Owner: Antigravity
- Status: backlog
- Risk: low
- Created: 2026-03-06
- Contract Impact: none
- Default-Path Impact: core_path
- Artifact Outputs: `data/starters/corrupted_starters.json`

## Problem

The narrative requires the player to find their first partner in Phase Three in a corrupted state (`docs/scaffolding_v0_3.md`). There is currently no data definition for these initial states or the logic to present them during the Phase Three opening.

## Proposed Solution

Define the initial corrupted starters in a data-driven format:
1.  Create `data/starters/corrupted_starters.json` with entries for Treecko (Bug/Rock), Torchic (Fighting/Steel), and Mudkip (Ghost/Fairy).
2.  Define their specific "found" coordinates on Routes 116, Rustboro drainage, and Route 122 respectively.
3.  Implement the flag-based logic to trigger the starter discovery event during the Phase Three opening call.

## Files Affected

- `data/starters/corrupted_starters.json` [NEW]
- `data/narrative/threshold_opening.json` [NEW]
- `systems/core/StarterManager.gd` [NEW]

## Acceptance Criteria

- [ ] Corrupted starter data correctly loads from JSON.
- [ ] Phase Three opening logic identifies which starter the player selects.
- [ ] The selected starter is correctly injected into the player's party with the documented corruption types and lore.

## Validation Commands

- `python scripts/dev.py quality-strict`
- `python scripts/dev.py harness test starter-discovery`

## Pruning Prevention Controls

- Authoritative path: `data/starters/`
- Parallel path introduced: none
- Artifact output target: `data/starters/`
- Default-path impact: core_path

## Risks and Rollback

- Risk: Incorrect typing or move-set on discovery could break early gameplay.
- Rollback: Revert JSON modifications and return to standard starter logic placeholders.

## Execution Log

- [2026-03-06] Item drafted based on `docs/scaffolding_v0_3.md`.
