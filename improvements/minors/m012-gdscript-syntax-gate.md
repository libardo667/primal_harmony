# GDScript Syntax Gate

## Metadata

- ID: m012-gdscript-syntax-gate
- Type: minor
- Owner: unassigned
- Status: backlog
- Risk: low
- Created: 2026-03-06
- Contract Impact: backward_compatible
- Default-Path Impact: optional_only
- Artifact Outputs: source-of-truth changes under `scripts/dev.py`

## Problem

Gate 3 (`build-static-health`) in `scripts/dev.py` currently syntax-checks only
Python files under `scripts/` and `tools/`. The project has ~21 GDScript (`.gd`)
files in `systems/`, `battle/`, `ui/`, `actors/`, and the root — none of which
are covered by any static check in the quality gate suite.

A GDScript syntax error will silently pass all quality gates and only surface when
Godot loads the file. For a project using an agent-assisted workflow, this is a
real detection gap: agents can introduce GDScript parse errors that pass
`quality-strict` and are only caught at editor open time.

This gap was identified during the 003 execution audit.

## Proposed Solution

Add an optional `gdscript-syntax` check to Gate 3, using `gdtoolkit`
(`pip install gdtoolkit`) if available, or Godot headless `--check-only` as an
alternative:

1. Check if `gdlint` or `gdtoolkit` is available on PATH.
2. If available: run `gdlint` on all `.gd` files under the project root
   (excluding `.godot/`, `addons/`), report failures by file.
3. If not available: skip with a documented `"gdtoolkit not installed"` detail
   (pass with warning, not fail — tooling availability varies).
4. Expose as `--with-gdscript-lint` flag on `quality-strict`, keeping it off the
   default low-risk path (optional_only).

## Files Affected

- `scripts/dev.py` [MODIFY]

## Acceptance Criteria

- [ ] `python scripts/dev.py quality-strict --with-gdscript-lint` runs without
      error when gdtoolkit is installed.
- [ ] When gdtoolkit is not installed, check reports `"gdtoolkit not installed —
      skipped"` and returns pass (not fail).
- [ ] A deliberately broken `.gd` file triggers a fail when gdtoolkit is present.
- [ ] Default `quality-strict` (no flag) is unaffected — Gate 3 result unchanged.
- [ ] `cli-contract` (Gate 1) passes after adding `--with-gdscript-lint` to
      `quality-strict`.

## Validation Commands

- `python scripts/dev.py quality-strict --risk low`
- `python scripts/dev.py quality-strict --with-gdscript-lint`
- `python scripts/dev.py harness item-lint`

## Pruning Prevention Controls

- Authoritative path: `scripts/dev.py` Gate 3 check suite (extended, not replaced).
- Parallel path introduced: none — adds a new optional check, does not duplicate
  the existing `python-syntax` check.
- Optional/harness behavior on default path: `--with-gdscript-lint` flag is opt-in;
  not included in any risk profile's default gate set.
- Generated artifacts: none.

## Risks and Rollback

- Risk: gdtoolkit parses GDScript 4 with varying fidelity; false positives possible.
- Risk: gdtoolkit version pinning may be needed if parser lags Godot 4.x updates.
- Rollback: remove `--with-gdscript-lint` flag and `check_gdscript_syntax` function
  from `scripts/dev.py`; revert Gate 1 contract check if updated.

## Execution Log

- 2026-03-06: Item drafted from 003-quality-gate-baseline-wiring execution audit —
  GDScript syntax coverage gap in Gate 3.
