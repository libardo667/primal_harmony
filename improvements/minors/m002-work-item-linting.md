# Work Item Linting

## Metadata

- ID: m002-work-item-linting
- Type: minor
- Owner: codex
- Status: done
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
- improvements/minors/m002-work-item-linting.md

## Acceptance Criteria

- [x] A command validates major/minor item docs against local required
      sections/metadata.
- [x] Lint output clearly identifies file path and missing requirement.
- [x] Command can be used in strict or optional validation flow without
      generating large artifacts.

## Validation Commands

- `python scripts/dev.py quality-strict`
- `python scripts/dev.py harness item-lint`
- `python scripts/dev.py quality-strict --with-item-lint`
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
- 2026-03-06: Item moved to `in_progress`.
- 2026-03-06: Added schema-aware item linter to `scripts/dev.py`:
  - `python scripts/dev.py harness item-lint`
  - `python scripts/dev.py quality-strict --with-item-lint`
- 2026-03-06: Linter output now reports file-path + missing requirement detail
  for missing section/metadata cases.
- 2026-03-06: Validation:
  - `python scripts/dev.py quality-strict` -> pass
  - `python scripts/dev.py harness item-lint` -> pass
  - `python scripts/dev.py quality-strict --with-item-lint` -> pass
  - `git status --short` -> pass
- 2026-03-06: Negative-path validation:
  - added temporary `improvements/minors/_lint_tmp.md` with missing sections
    and metadata
  - `python scripts/dev.py harness item-lint` -> fail with explicit file path +
    missing requirement lines
  - removed temporary file and re-ran lint -> pass
- 2026-03-06: Item moved to `done`.
