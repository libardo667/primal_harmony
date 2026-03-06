# Establish Improvements Folder Architecture

## Metadata

- ID: 001-harness-improvements-architecture
- Type: major
- Owner: codex
- Status: done
- Risk: low
- Created: 2026-03-06
- Target Window: 2026-03-06
- Depends On: none
- Contract Impact: none
- Default-Path Impact: none
- Artifact Outputs: source-of-truth docs under `improvements/`; validation
  evidence and generated run outputs under `improvements/history/`

## Problem

The repository has `improvements/harness/` installed but is missing the rest of
the expected planning architecture:

- no `improvements/VISION.md`,
- no `improvements/ROADMAP.md`,
- no repo-local major/minor schema authority files,
- no item taxonomy directories for tracked execution.

This creates process ambiguity and blocks full harness adoption.

## Proposed Solution

Scaffold the missing `improvements/` architecture with bounded, docs-only
changes:

- create anchor docs (`VISION.md`, `ROADMAP.md`),
- define local authoritative schemas (`MAJOR_SCHEMA.md`, `MINOR_SCHEMA.md`),
- add item taxonomy directories (`majors/`, `minors/`, `patches/`,
  `incidents/`, `spikes/`, `history/`),
- create this active major item and directory index readmes.

No runtime gameplay code or data contracts are changed.

## Files Affected

- improvements/README.md
- improvements/VISION.md
- improvements/ROADMAP.md
- improvements/MAJOR_SCHEMA.md
- improvements/MINOR_SCHEMA.md
- improvements/majors/001-harness-improvements-architecture.md
- improvements/majors/README.md
- improvements/minors/README.md
- improvements/patches/README.md
- improvements/incidents/README.md
- improvements/spikes/README.md
- improvements/history/README.md

## Non-Goals

- Implementing full `scripts/dev.py` command surface in this item.
- Changing runtime game behavior, assets, or player-facing systems.

## Acceptance Criteria

- [x] Required anchor docs exist and are populated for this repo.
- [x] Repo-local major and minor schema docs exist with required sections.
- [x] Item taxonomy directories exist with usage notes.
- [x] `ROADMAP.md` reflects current architecture gap and sequenced follow-ups.
- [x] Validation evidence and blocked-gate notes are captured in this item.

## Validation Commands

- `python scripts/dev.py quality-strict`
- `git status --short`
- `Get-ChildItem -Recurse improvements | Select-Object FullName`

## Pruning Prevention Controls

- Authoritative path for touched behavior: `improvements/` planning surface.
- Parallel path introduced: none.
- Optional/harness behavior on default path: no.
- Generated artifacts + archive target: any generated evidence routed to
  `improvements/history/`.
- Flag lifecycle (if applicable): none.

## Risks and Rollback

Risks:

- Process docs may drift from actual command surface if follow-up item 002 is
  delayed.
- Teams may treat scaffold as complete adoption without running strict gates.

Rollback:

- Revert this major item commit to restore previous `improvements/` state.
- No data migration or runtime rollback actions required.

## Execution Log

- 2026-03-06: Item created and moved to `in_progress`.
- 2026-03-06: Added `improvements/` anchors (`VISION.md`, `ROADMAP.md`,
  `README.md`).
- 2026-03-06: Added repo-local schema authority files
  (`MAJOR_SCHEMA.md`, `MINOR_SCHEMA.md`).
- 2026-03-06: Added taxonomy directories and usage docs for majors, minors,
  patches, incidents, spikes, and history.
- 2026-03-06: Ran `python scripts/dev.py quality-strict` -> blocked (missing
  `scripts/dev.py` command surface).
- 2026-03-06: Ran `git status --short` -> pass (only scoped `improvements/`
  additions).
- 2026-03-06: Ran `Get-ChildItem -Recurse improvements | Select-Object
  FullName` -> pass (scaffold present).
- 2026-03-06: Item moved to `verify` pending follow-up major
  `002-canonical-dev-command-surface` for strict gate availability.
- 2026-03-06: Re-ran strict gate after `002`:
  - `python scripts/dev.py quality-strict` -> pass
- 2026-03-06: Item moved from `verify` to `done`.

## Follow-up Candidates

- 002-canonical-dev-command-surface
- 003-quality-gate-baseline-wiring
