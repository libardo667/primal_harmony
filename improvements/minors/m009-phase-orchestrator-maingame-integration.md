# Phase Orchestrator MainGame Integration

## Metadata

- ID: m009-phase-orchestrator-maingame-integration
- Type: minor
- Owner: unassigned
- Status: backlog
- Risk: low
- Created: 2026-03-06
- Contract Impact: backward_compatible
- Default-Path Impact: core_path
- Artifact Outputs: source-of-truth changes under `MainGame.gd`

## Problem

`005-narrative-phase-orchestrator` created `PhaseOrchestrator` and
`PhaseTransitionScreen` but left a concrete integration gap: `MainGame._ready()`
does not instantiate `PhaseTransitionScreen.tscn`. Without this,
`PhaseTransitionScreen._ready()` never runs, `PhaseOrchestrator.register_transition_screen()`
is never called, and all phase transitions silently fall back to the bare
`await get_tree().process_frame` path instead of playing the text-card sequence.

Additionally, there is no way to manually trigger `advance_phase()` during
development, making it impossible to verify the transition flow without a fully
wired story beat.

## Proposed Solution

1. Add `PhaseTransitionScreen.tscn` instantiation to `MainGame._ready()` using
   the same pattern as `BattleScene` (line 73).
2. Add a debug hotkey (F8) to `MainGame._unhandled_key_input()` that calls
   `PhaseOrchestrator.advance_phase()` — gates behind `OS.is_debug_build()`.
3. Verify the full signal chain: `advance_phase()` → `transition_started` →
   screen plays card → `transition_completed` → `phase_changed`.

## Files Affected

- `MainGame.gd` [MODIFY]

## Acceptance Criteria

- [ ] `PhaseTransitionScreen` is instantiated as a child of the main scene tree
      in `MainGame._ready()`, consistent with the `BattleScene` pattern.
- [ ] `PhaseOrchestrator.register_transition_screen()` is confirmed called (via
      log or signal) when the game boots.
- [ ] Pressing F8 in a debug build calls `PhaseOrchestrator.advance_phase()` and
      the "Six years later." text card plays end-to-end.
- [ ] No regression on Gate 4 scene-audit after MainGame.gd changes.

## Validation Commands

- `python scripts/dev.py quality-strict --risk medium`
- `python scripts/dev.py harness scene-audit .`

## Pruning Prevention Controls

- Authoritative path: `MainGame.gd` (existing game controller, extended not replaced).
- Parallel path introduced: none.
- Optional/harness behavior on default path: debug hotkey gated behind
  `OS.is_debug_build()` — not present in release builds.
- Generated artifacts: none.

## Risks and Rollback

Risks:
- Incorrect instantiation order could cause PhaseOrchestrator._ready() to run
  before QuestManager is ready — mitigated by autoload ordering in project.godot
  (QuestManager listed before PhaseOrchestrator).

Rollback:
- Remove the two added lines from `MainGame._ready()` and the F8 debug hotkey.

## Execution Log

- 2026-03-06: Item drafted as follow-up from 005 execution gap.
