# Fallarbor Warp Target Contract Fix

## Metadata

- ID: m004-fallarbor-warp-target-fix
- Type: minor
- Owner: unassigned
- Status: backlog
- Risk: low
- Created: 2026-03-06
- Contract Impact: backward_compatible
- Default-Path Impact: core_path
- Artifact Outputs: source-of-truth scene updates under `maps/`; optional audit
  outputs under `improvements/history/`

## Problem

`scene-audit` reports a runtime warp contract error:

- source: `res://maps/interiors/fallarbor_pokemon_center.tscn`
- check: `warp_target_no_warppoints`
- target: `res://maps/hoenn/cities/fallarbor_town.tscn`

The target scene lacks a `WarpPoints` container, causing fallback spawn
behavior and breaking expected warp target contract reliability.

## Proposed Solution

Add/align required warp target structure in Fallarbor map scenes:

- add `WarpPoints` container in `fallarbor_town.tscn`,
- add or align destination warp node metadata (`destination_warp_id`) so the
  interior warp resolves to a concrete target point,
- verify no new scene-contract violations are introduced.

## Files Affected

- maps/hoenn/cities/fallarbor_town.tscn
- maps/interiors/fallarbor_pokemon_center.tscn
- improvements/minors/m004-fallarbor-warp-target-fix.md

## Acceptance Criteria

- [ ] `scene-audit` no longer reports `warp_target_no_warppoints` for the
      Fallarbor Pokemon Center warp.
- [ ] Fallarbor interior-to-exterior warp target resolves to explicit warp
      point metadata, not fallback.
- [ ] Medium-risk strict profile passes Gate 4 for this issue.

## Validation Commands

- `python scripts/dev.py harness scene-audit .`
- `python scripts/dev.py quality-strict --risk medium`
- `git status --short`

## Pruning Prevention Controls

- Authoritative path: map scene contract under `maps/` and `references/scene-contracts.md`.
- Parallel path introduced: none.
- Artifact output target: source-of-truth `.tscn` files in `maps/`; optional
  audit logs in `improvements/history/`.
- Default-path impact: core_path.

## Risks and Rollback

- Risk: incorrect warp metadata could redirect player to wrong spawn point.
- Rollback: revert Fallarbor scene changes and rerun `scene-audit`.

## Execution Log

- 2026-03-06: Item drafted from roadmap follow-up queue; status `backlog`.
