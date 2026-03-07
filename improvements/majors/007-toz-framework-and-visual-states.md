# 007 - TOZ Framework and Visual States

## Metadata

- ID: 007-toz-framework-and-visual-states
- Type: major
- Owner: Antigravity
- Status: backlog
- Risk: high
- Created: 2026-03-06
- Target Window: Milestone 2
- Depends On: 006-ehi-core-systems
- Contract Impact: backward_compatible
- Default-Path Impact: core_path
- Artifact Outputs: `systems/ecology/TOZZone.gd`, `assets/shaders/TOZDistortion.gdshader`

## Problem

Type Overload Zones (TOZ) are the primary environmental challenge in Primal Harmony (`docs/TOZ_field_atlas_v0.2.md`). Currently, they are only described in a field atlas. There is no technical framework to define zone boundaries, apply type-based visual distortions, or drive the three visual states (Infested/Partial/Restored) in Godot.

## Proposed Solution

Implement the TOZ technical framework by:
1.  Creating the `TOZZone` node class (extending `Area2D` or similar) to define geographic boundaries.
2.  Implementing the `VisualStateDriver` to interpolate between Infested (0-33 EHI), Partial (34-66 EHI), and Restored (67-100 EHI) visual states.
3.  Developing a `TOZDistortion` shader that handles type-tinting (e.g., Ice-blue for Ashen Glacier, Electric-yellow for Static Sprawl).
4.  Adding support for "traversal hazards" (frictionless ice, shocking grates) tied to the zone state.

## Files Affected

- `systems/ecology/TOZZone.gd` [NEW]
- `assets/shaders/TOZDistortion.gdshader` [NEW]
- `systems/ecology/TOZVisualStateDriver.gd` [NEW]
- `data/ecology/toz_registry.json` [NEW]

## Non-Goals

- Implementing actual zone data for all 10 zones (handled in minors).
- Implementing Corrupted Variant encounter logic (handled as separate major).

## Acceptance Criteria

- [ ] `TOZZone` nodes correctly detect player entry/exit.
- [ ] Visual state driver correctly interpolates shader parameters based on local EHI.
- [ ] Shader correctly applies type-based color tinting and procedural distortion.
- [ ] Multi-state visual transitions match the visual descriptions in `docs/TOZ_field_atlas_v0.2.md`.

## Validation Commands

- `python scripts/dev.py quality-strict`
- `python scripts/dev.py harness test toz-framework`

## Pruning Prevention Controls

- Authoritative path for touched behavior: `systems/ecology/`
- Parallel path introduced: none
- Optional/harness behavior on default path: no
- Generated artifacts + archive target: `improvements/history/toz_visual_benchmarks/`

## Risks and Rollback

Risks:
- Excessive shader complexity could impact performance on lower-end devices.
- Visual artifacts at zone boundaries if transitions are not handled smoothly.

Rollback:
- Revert additions to the ecology system and disable TOZ shaders in the main environment.

## Execution Log

- [2026-03-06] Item drafted based on `docs/TOZ_field_atlas_v0.2.md`.

## Follow-up Candidates

- `m006-toz-01-ashen-glacier-data`
- `m007-toz-02-static-sprawl-data`
