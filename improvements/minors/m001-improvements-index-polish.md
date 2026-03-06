# Improvements Index Polish

## Metadata

- ID: m001-improvements-index-polish
- Type: minor
- Owner: codex
- Status: done
- Risk: low
- Created: 2026-03-06
- Contract Impact: none
- Default-Path Impact: none
- Artifact Outputs: source-of-truth docs under `improvements/`

## Problem

The `improvements/` structure exists, but navigation between queue docs, schema
authority, harness policy, and archive conventions can be faster for day-to-day
execution.

## Proposed Solution

Polish index-level docs to reduce navigation cost:

- add direct links between roadmap queues and item directories,
- add schema quick-reference links in queue docs,
- add archive/evidence examples in index docs.

## Files Affected

- improvements/README.md
- improvements/ROADMAP.md
- improvements/minors/m001-improvements-index-polish.md

## Acceptance Criteria

- [x] Primary index docs include direct links to major/minor queues.
- [x] Schema authority docs are linked from navigation entrypoints.
- [x] Archive usage guidance is discoverable from index docs.

## Validation Commands

- `python scripts/dev.py quality-strict`
- `git status --short`

## Pruning Prevention Controls

- Authoritative path: `improvements/` documentation surface.
- Parallel path introduced: none.
- Artifact output target: source-of-truth docs in `improvements/`.
- Default-path impact: none.

## Risks and Rollback

- Risk: navigation changes could create stale links if not maintained.
- Rollback: revert doc-only commit for this minor item.

## Execution Log

- 2026-03-06: Item drafted from roadmap queue; status `backlog`.
- 2026-03-06: Item moved to `in_progress`.
- 2026-03-06: Added queue/schema/archive quick links to
  `improvements/README.md` and `improvements/ROADMAP.md`.
- 2026-03-06: Validation:
  - `python scripts/dev.py quality-strict` -> pass
  - `git status --short` -> pass
- 2026-03-06: Item moved to `done`.
