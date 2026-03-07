# m008 - Triage Catch Refactor

## Metadata

- ID: m008-triage-catch-refactor
- Type: minor
- Owner: Antigravity
- Status: backlog
- Risk: medium
- Created: 2026-03-06
- Contract Impact: backward_compatible
- Default-Path Impact: core_path
- Artifact Outputs: none

## Problem

The narrative opening in Phase One introduces the "Triage Catch"—a gentle capture method for frightened, non-hostile Pokemon (`docs/scaffolding_v0_3.md`). Currently, the core battle and catch system likely assume a standard, competitive catch-probability model. There is no mechanism to toggle this specialized narrative catch mode.

## Proposed Solution

Refactor the core `CatchSystem` to support a "Triage Mode" flag:
1.  Extend the `CatchProbability` calculator to return a 100% success rate when `triage_mode` is active.
2.  Add a `is_triage_target` property to the `BattleState` or `EncounterParams`.
3.  Inject specialized dialogue hooks for when a Pokeball is successfully "handed" or "tossed gently" rather than "thrown".

## Files Affected

- `systems/battle/CatchSystem.gd` [MODIFY]
- `systems/battle/BattleState.gd` [MODIFY]
- `data/battle/enums.gd` [MODIFY]

## Acceptance Criteria

- [ ] `triage_mode` correctly forces capture success without traditional HP/State checks.
- [ ] Battles correctly identify "Triage" targets based on encounter metadata.
- [ ] Existing standard capture logic remains unaffected.

## Validation Commands

- `python scripts/dev.py quality-strict`
- `python scripts/dev.py harness test capture-logic`

## Pruning Prevention Controls

- Authoritative path: `systems/battle/`
- Parallel path introduced: none
- Artifact output target: none
- Default-path impact: core_path

## Risks and Rollback

- Risk: Unintentional leakage of triage-success into standard wild battles.
- Rollback: Revert boolean flag logic in `CatchSystem.gd`.

## Execution Log

- [2026-03-06] Item drafted based on `docs/scaffolding_v0_3.md`.
