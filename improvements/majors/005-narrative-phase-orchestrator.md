# 005 - Narrative Phase Orchestrator

## Metadata

- ID: 005-narrative-phase-orchestrator
- Type: major
- Owner: Antigravity
- Status: backlog
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

- `systems/singletons/PhaseOrchestrator.gd` [NEW]
- `data/narrative/phases.json` [NEW]
- `ui/narrative/PhaseTransitionScreen.tscn` [NEW]
- `systems/core/GameManager.gd` [MODIFY]

## Non-Goals

- Implementing actual story beat content (NPC dialogue, specific cutscenes).
- Implementing phase-specific map content beyond the transition triggers.

## Acceptance Criteria

- [ ] `PhaseOrchestrator` correctly loads phase state from JSON/Save.
- [ ] Transitioning from Phase 1 to Phase 2 triggers the "Six years later" text card.
- [ ] Phase status is accessible globally at runtime via `PhaseOrchestrator.current_phase`.
- [ ] Transition triggers follow the specific narrative beats defined in `docs/narrative_bible_v0_1.md`.

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
- Revert additions to `GameManager.gd` and remove the Autoload from project settings.

## Execution Log

- [2026-03-06] Item drafted based on `docs/narrative_bible_v0_1.md`.

## Follow-up Candidates

- `m008-phase-one-tutorial-logic`
- `m009-phase-two-slateport-sequence`
