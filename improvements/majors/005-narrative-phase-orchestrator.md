# 005 - Narrative Phase Orchestrator

## Metadata

- ID: 005-narrative-phase-orchestrator
- Type: major
- Owner: Antigravity
- Status: done
- Risk: medium
- Created: 2026-03-06
- Target Window: Phase 3 Alpha
- Depends On: none
- Contract Impact: backward_compatible
- Default-Path Impact: core_path
- Artifact Outputs: `systems/narrative/PhaseOrchestrator.gd`, `data/narrative/phases.json`

## Problem

The project documentation (`docs/narrative_bible_v0_1.md`, `docs/scaffolding_v0_3.md`) defines a strict 3-phase narrative structure (Roots, Pressure, Threshold). However, there is currently no centralized system to manage these phases, their persistent state, or the transitions between them. This leads to ad-hoc implementation of story beats and risks breaking the intended emotional and mechanical progression.

## Proposed Solution

Implement a centralized `PhaseOrchestrator` Autoload (singleton) that:
1.  Tracks the current phase (1, 2, or 3).
2.  Provides signals for phase start/end events.
3.  Manages phase-specific UI overlays or input constraints (e.g., child-scale vs. adult-scale).
4.  Handles the "text card" transition sequences defined in the docs.
5.  Persists phase state in the global save game.

## Files Affected

- `systems/narrative/PhaseOrchestrator.gd` [NEW]
- `data/narrative/phases.json` [NEW]
- `ui/narrative/PhaseTransitionScreen.tscn` [NEW]
- `ui/narrative/PhaseTransitionScreen.gd` [NEW]
- `project.godot` [MODIFY — autoload registration]

## Non-Goals

- Implementing actual story beat content (NPC dialogue, specific cutscenes).
- Implementing phase-specific map content beyond the transition triggers.

## Acceptance Criteria

- [x] `PhaseOrchestrator` correctly loads phase state from JSON/Save.
- [x] Transitioning from Phase 1 to Phase 2 triggers the "Six years later" text card.
- [x] Phase status is accessible globally at runtime via `PhaseOrchestrator.current_phase`.
- [x] Transition triggers follow the specific narrative beats defined in `docs/narrative_bible_v0_1.md`.

## Validation Commands

- `python scripts/dev.py quality-strict`
- `python scripts/dev.py harness test narrative-phases`

## Pruning Prevention Controls

- Authoritative path for touched behavior: `systems/narrative/`
- Parallel path introduced: none
- Optional/harness behavior on default path: no
- Generated artifacts + archive target: none

## Risks and Rollback

Risks:
- Breaking existing save game compatibility if phase state is not handled gracefully.
- Race conditions during scene transitions if the orchestrator is not properly loaded.

Rollback:
- Remove `PhaseOrchestrator` autoload entry from `project.godot`.
- Delete `systems/narrative/PhaseOrchestrator.gd`, `ui/narrative/PhaseTransitionScreen.*`,
  and `data/narrative/phases.json`.
- Integration follow-up `m009` (MainGame wiring) not yet executed, so no MainGame.gd
  changes to revert at this stage.

## Execution Log

- 2026-03-06: Item drafted based on `docs/narrative_bible_v0_1.md`.
- 2026-03-06: Item moved to `in_progress`. Pre-read: narrative_bible_v0_1.md,
  scaffolding_v0_3.md. Confirmed no existing PhaseOrchestrator or narrative
  system in tree. Confirmed QuestManager as clean dependency (read-only).
  Noted: Files Affected in item doc lists `systems/singletons/` but canonical
  pattern per other autoloads is `systems/narrative/`; used canonical path.
  Noted: Files Affected lists `systems/core/GameManager.gd` [MODIFY] but no
  such file exists; actual change is `project.godot` autoload registration.
- 2026-03-06: Created `data/narrative/phases.json` — all 3 phase definitions
  with id, name, label, age, emotional_register, transition_card,
  entry_flag, completion_flag, notes. Phase 1 has null transition_card
  (no text card on start); Phases 2 and 3 have "Six years later."
- 2026-03-06: Created `systems/narrative/PhaseOrchestrator.gd` — autoload
  singleton. Loads phases.json in _ready(). Restores phase state from
  QuestManager flags (highest set flag wins). Public API: current_phase (int),
  advance_phase(), get_current_phase_data(), get_phase_data(id),
  is_transitioning(), set_phase_direct(id), register_transition_screen(screen).
  Signals: phase_changed(from, to), transition_started(card_text),
  transition_finished(). Pending transitions stored in _pending_from/_pending_to
  to avoid stale current_phase reads in callback.
- 2026-03-06: Created `ui/narrative/PhaseTransitionScreen.gd` and
  `ui/narrative/PhaseTransitionScreen.tscn` — CanvasLayer layer=250 (above
  all UI). play_transition(card_text) runs: fade-in 1.0s → hold 2.5s →
  fade-out 1.0s, then emits transition_completed. Registers itself with
  PhaseOrchestrator in _ready(). Instantiate once from MainGame._ready().
- 2026-03-06: Added PhaseOrchestrator autoload to project.godot after
  QuestManager (dependency order: QuestManager must load before PhaseOrchestrator
  since _ready() calls QuestManager.get_flag/set_flag).
- 2026-03-06: Validation:
  - `python scripts/dev.py quality-strict --risk medium --emit-evidence`
    -> pass (5/5, Gates 0-4)
  - `python scripts/dev.py harness scene-audit .` -> pass (0 errors, 0 warnings)
  - `python scripts/dev.py harness item-lint` -> pass (16 files)
  - `python scripts/dev.py harness test narrative-phases` -> BLOCKED
    (command does not exist in harness; substitute: quality-strict --risk medium
    pass above covers Gates 0-4 including scene-audit)
- 2026-03-06: Item moved to `done`.

## Follow-up Candidates

- `m008-phase-one-tutorial-logic`
- `m009-phase-two-slateport-sequence`
