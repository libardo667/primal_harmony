# Phase Orchestrator Test Scene

## Metadata

- ID: m010-phase-orchestrator-test-scene
- Type: minor
- Owner: unassigned
- Status: backlog
- Risk: low
- Created: 2026-03-06
- Contract Impact: none
- Default-Path Impact: none
- Artifact Outputs: source-of-truth test files under `systems/narrative/`

## Problem

`PhaseOrchestrator` has no test scene, unlike every other system in the project
(`systems/ehi/test_ehi.tscn`, `systems/faction/test_faction.tscn`,
`systems/rehabilitation/test_rehab.tscn`, etc.). This means:

1. The `harness test narrative-phases` validation command listed in 005's item
   doc was blocked with no substitute.
2. Phase state restoration from QuestManager flags, the `advance_phase()` signal
   chain, and `set_phase_direct()` have no automated verification path.
3. Future contributors have no reference for exercising the system in isolation.

## Proposed Solution

Add `systems/narrative/test_phase_orchestrator.tscn` and
`systems/narrative/test_phase_orchestrator.gd` following the existing test scene
pattern:

- Boot → assert `current_phase == 1` and `phase_1_started` flag set.
- Call `set_phase_direct(2)` → assert `current_phase == 2`, `phase_2_started` flag set,
  `phase_changed` signal emitted with `(0, 2)` or `(1, 2)`.
- Call `set_phase_direct(1)` to reset, then `advance_phase()` without a screen →
  assert `phase_changed` emitted with `(1, 2)` after the process_frame fallback.
- Assert `is_transitioning()` is false after completion.
- Assert `get_phase_data(2).transition_card == "Six years later."`.
- Assert `advance_phase()` is a no-op when `current_phase == 3`.

Output pass/fail summary to stdout consistent with other test scenes.

## Files Affected

- `systems/narrative/test_phase_orchestrator.tscn` [NEW]
- `systems/narrative/test_phase_orchestrator.gd` [NEW]

## Acceptance Criteria

- [ ] Test scene runs headless (F6 substitute: `godot --headless --script`) and
      prints pass/fail for each assertion.
- [ ] All six assertion groups above pass.
- [ ] Test is consistent in structure with `systems/ehi/test_ehi.tscn` / `.gd`.
- [ ] No changes to runtime autoload path or default validation path.

## Validation Commands

- `python scripts/dev.py quality-strict --risk low`
- Manual: run `systems/narrative/test_phase_orchestrator.tscn` from editor or headless

## Pruning Prevention Controls

- Authoritative path: `systems/narrative/` (test alongside its subject, same
  pattern as all other system tests).
- Parallel path introduced: none — test exercises the same PhaseOrchestrator
  singleton, not a parallel implementation.
- Optional/harness behavior on default path: test scene is not registered as an
  autoload and not on any default runtime path.
- Generated artifacts: none.

## Risks and Rollback

Risks:
- Test relies on QuestManager being in a known clean state; test must call
  `QuestManager.clear_all()` in setup.

Rollback:
- Delete `systems/narrative/test_phase_orchestrator.*` — no runtime impact.

## Execution Log

- 2026-03-06: Item drafted as follow-up from 005 blocked validation command and
  test coverage gap.
