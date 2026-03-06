# Roadmap

## Current State

- Product status: core gameplay systems and world content are present, with
  ongoing stabilization and integration work.
- Architecture status: runtime systems are established, but the
  `improvements/` planning structure is only partially installed.
- Top risks:
  - Missing canonical quality command surface (`python scripts/dev.py ...`).
  - Inconsistent item tracking/evidence for agent-executed changes.
  - Future pruning debt if parallel workflow paths accumulate.

## Guardrails

1. Extend existing authoritative paths; avoid unbounded parallel runtime paths.
2. Keep optional and harness workflows off default runtime/validation path.
3. Require explicit rollback notes and validation evidence for non-trivial
   changes.

## Major Queue

1. `001-harness-improvements-architecture` (done): establish full
   `improvements/` anchors, schemas, and item taxonomy layout.
2. `002-canonical-dev-command-surface` (done): implement `scripts/dev.py`
   with stable quality and harness subcommands.
3. `003-quality-gate-baseline-wiring` (backlog): map project checks to harness
   gates and enforce baseline evidence capture.

## Minor Queue

1. `m001-improvements-index-polish` (backlog): add cross-links and quick
   navigation for item queues and archive conventions.
2. `m002-work-item-linting` (backlog): add a lightweight validator for
   required schema sections.
3. `m003-rollup-evidence-template` (backlog): add reusable end-of-item
   evidence snippets for common command outcomes.

## Recommended Execution Order

1. Execute `003-quality-gate-baseline-wiring`.
2. Execute `m001-improvements-index-polish`.
3. Execute `m002-work-item-linting`.

## Notes

- `CLAUDE.md` is compatibility-only; `AGENTS.md` + harness docs are the active
  process authority.
- `improvements/history/` is the default archive path for generated evidence.
