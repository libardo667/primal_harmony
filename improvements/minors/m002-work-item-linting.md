# Work Item Linting

## Metadata

- ID: m002-work-item-linting
- Type: minor
- Owner: unassigned
- Status: backlog
- Risk: medium
- Created: 2026-03-06
- Contract Impact: backward_compatible
- Default-Path Impact: optional_only
- Artifact Outputs: source-of-truth scripts under `scripts/`; optional reports
  under `improvements/history/`

## Problem

Work item docs can drift from required schema sections over time, which creates
review ambiguity and inconsistent execution evidence.

## Proposed Solution

Add a lightweight lint command that validates item docs against local schema
requirements:

- verify required sections exist in majors/minors,
- verify required metadata fields are present,
- return non-zero for missing required schema elements.

## Files Affected

- scripts/dev.py
- improvements/MAJOR_SCHEMA.md
- improvements/MINOR_SCHEMA.md
- improvements/minors/m002-work-item-linting.md

## Acceptance Criteria

- [ ] A command validates major/minor item docs against local required
      sections/metadata.
- [ ] Lint output clearly identifies file path and missing requirement.
- [ ] Command can be used in strict or optional validation flow without
      generating large artifacts.

## Validation Commands

- `python scripts/dev.py quality-strict`
- `python scripts/dev.py harness list`
- `git status --short`

## Pruning Prevention Controls

- Authoritative path: `scripts/dev.py` command surface and local schema docs.
- Parallel path introduced: none.
- Artifact output target: source-of-truth scripts/docs; optional reports in
  `improvements/history/`.
- Default-path impact: optional_only.

## Risks and Rollback

- Risk: linter false positives could block legitimate item formatting.
- Rollback: disable lint command wiring and revert lint-specific commit.

## Execution Log

- 2026-03-06: Item drafted from roadmap queue; status `backlog`.
