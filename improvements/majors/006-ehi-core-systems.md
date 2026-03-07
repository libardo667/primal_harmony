# 006 - EHI Core Systems

## Metadata

- ID: 006-ehi-core-systems
- Type: major
- Owner: Antigravity
- Status: backlog
- Risk: high
- Created: 2026-03-06
- Target Window: Milestone 1
- Depends On: none
- Contract Impact: backward_compatible
- Default-Path Impact: core_path
- Artifact Outputs: `systems/ecology/EHIManager.gd`, `data/ecology/biomes.json`

## Problem

The Ecological Harmony Index (EHI) is the central progression and feedback system of Primal Harmony (`docs/world_state_v0_1.md`, `docs/scaffolding_v0_3.md`). Currently, EHI is only a concept in the documentation and has no technical implementation. Without a core EHI system, it is impossible to drive environmental visual changes, unlock story resolutions, or track restoration progress.

## Proposed Solution

Implement the `EHIManager` system to:
1.  Manage a global EHI score (0-100).
2.  Manage per-biome/zone EHI scores.
3.  Provide a subscription-based API for environmental systems (shaders, encounter tables) to respond to EHI changes.
4.  Calculate story resolution gates based on EHI thresholds at key narrative beats.
5.  Persist EHI data in the save system.

## Files Affected

- `systems/singletons/EHIManager.gd` [NEW]
- `data/ecology/biomes.json` [NEW]
- `systems/ecology/EHIObserver.gd` [NEW] (Base class for EHI-reactive objects)
- `systems/core/SaveSystem.gd` [MODIFY]

## Non-Goals

- Implementing specific shader effects for "Infested" or "Restored" states (handled in 007).
- Implementing the Rehabilitation Log (handled in 008).

## Acceptance Criteria

- [ ] Global EHI is correctly calculated as an aggregate of regional EHI.
- [ ] Biome EHI updates correctly in response to "release" events.
- [ ] Systems can register as 'EHI observers' and receive signals when thresholds are crossed.
- [ ] EHI thresholds correctly affect resolution gating as specified in `docs/narrative_bible_v0_1.md`.

## Validation Commands

- `python scripts/dev.py quality-strict`
- `python scripts/dev.py harness test ehi-core`

## Pruning Prevention Controls

- Authoritative path for touched behavior: `systems/ecology/`
- Parallel path introduced: none
- Optional/harness behavior on default path: no
- Generated artifacts + archive target: none

## Risks and Rollback

Risks:
- High complexity in aggregate calculation could lead to performance issues if not optimized.
- Synchronization issues between local and global EHI states.

Rollback:
- Disable the EHI Autoload and revert `SaveSystem.gd` modifications.

## Execution Log

- [2026-03-06] Item drafted based on `docs/world_state_v0_1.md` and `docs/scaffolding_v0_3.md`.

## Follow-up Candidates

- `007-toz-framework-and-visual-states`
- `008-rehabilitation-log-and-terminal-logic`
