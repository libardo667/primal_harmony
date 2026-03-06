# Canonical Dev Command Surface

## Metadata

- ID: 002-canonical-dev-command-surface
- Type: major
- Owner: codex
- Status: done
- Risk: medium
- Created: 2026-03-06
- Target Window: 2026-03-06
- Depends On: 001-harness-improvements-architecture
- Contract Impact: backward_compatible
- Default-Path Impact: optional_only
- Artifact Outputs: source-of-truth files under `scripts/` and `improvements/`;
  optional run artifacts under `improvements/history/`

## Problem

`AGENTS.md` and harness policy declare `python scripts/dev.py ...` as the
canonical command surface, but `scripts/dev.py` does not exist. As a result:

- required gate command `python scripts/dev.py quality-strict` is unavailable,
- non-trivial items cannot satisfy strict validation policy,
- CLI workflow expectations are ambiguous across contributors.

## Proposed Solution

Implement a repository-local `scripts/dev.py` CLI with:

- `quality-strict` command for baseline strict checks,
- `harness <workflow>` namespace for optional workflows,
- machine-readable output support for quality results,
- clear, deterministic exit codes for CI/local use.

Keep initial strict baseline focused on checks that are deterministic and
available in this repo now; defer broader gate expansion to major 003.

## Files Affected

- scripts/dev.py
- improvements/ROADMAP.md
- improvements/README.md
- improvements/majors/002-canonical-dev-command-surface.md
- improvements/majors/003-quality-gate-baseline-wiring.md
- improvements/minors/m001-improvements-index-polish.md
- improvements/minors/m002-work-item-linting.md
- improvements/minors/m003-rollup-evidence-template.md
- improvements/majors/001-harness-improvements-architecture.md

## Non-Goals

- Full quality gate expansion for all runtime/performance checks (tracked in
  003-quality-gate-baseline-wiring).
- Refactoring existing tool scripts beyond invocation integration.

## Acceptance Criteria

- [x] `python scripts/dev.py quality-strict` executes and returns non-zero on
      failed checks.
- [x] `python scripts/dev.py quality-strict --json` returns machine-readable
      summary output.
- [x] `python scripts/dev.py harness <workflow>` namespace exists with at least
      one workflow entrypoint.
- [x] Command behavior, scope, and risks are documented in this item evidence.
- [x] Item 001 unblocks and moves from `verify` to `done` if strict gate runs.

## Validation Commands

- `python scripts/dev.py quality-strict`
- `python scripts/dev.py quality-strict --json`
- `python scripts/dev.py quality-strict --with-scene-audit`
- `python scripts/dev.py harness scene-audit --help`
- `git status --short`

## Pruning Prevention Controls

- Authoritative path for touched behavior: `scripts/dev.py` for dev command
  orchestration.
- Parallel path introduced: none.
- Optional/harness behavior on default path: no (`harness` namespace remains
  explicit opt-in).
- Generated artifacts + archive target: no generated artifact required by
  default commands; archive any optional run outputs under `improvements/history/`.
- Flag lifecycle (if applicable): none.

## Risks and Rollback

Risks:

- Command surface may be perceived as complete while only baseline gates are
  wired.
- Strict baseline might miss repo-specific checks until 003 is completed.

Rollback:

- Revert commit(s) touching `scripts/dev.py` and related roadmap/item docs.
- No runtime data migrations or persistent state changes.

## Execution Log

- 2026-03-06: Item created and moved to `in_progress`.
- 2026-03-06: Added `scripts/dev.py` with canonical commands:
  - `quality-strict`
  - `harness list`
  - `harness scene-audit`
- 2026-03-06: `quality-strict` baseline checks wired:
  - required anchor docs presence,
  - Python syntax compile check for `scripts/` and `tools/`,
  - JSON parse validation for `data/**/*.json`.
- 2026-03-06: Validation results:
  - `python scripts/dev.py quality-strict` -> pass
  - `python scripts/dev.py quality-strict --json` -> pass
  - `python scripts/dev.py quality-strict --with-scene-audit` -> fail (exit 1,
    expected; verifies non-zero on failed checks and reports existing map audit
    issue)
  - `python scripts/dev.py harness scene-audit --help` -> pass
  - `git status --short` -> pass
- 2026-03-06: Hardened subprocess output decoding for `scene-audit` check on
  Windows shells to avoid nondeterministic decode exceptions.
- 2026-03-06: Roadmap-planned spec docs drafted on user request:
  - major `003-quality-gate-baseline-wiring`
  - minors `m001`, `m002`, `m003`
- 2026-03-06: Item completed and moved to `done`.

## Follow-up Candidates

- 003-quality-gate-baseline-wiring
- m002-work-item-linting
