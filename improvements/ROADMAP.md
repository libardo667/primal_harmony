# Roadmap

## Current State

- Product status: core gameplay systems and world content are present, with
  ongoing stabilization and integration work.
- Architecture status: `improvements/` planning structure and canonical
  `scripts/dev.py` command surface are installed; deeper gate wiring is queued
  in major 003.
- Top risks:
  - `quality-strict` baseline is intentionally narrow until major 003 expands
    gate wiring.
  - Inconsistent item tracking/evidence for agent-executed changes.
  - Future pruning debt if parallel workflow paths accumulate.

## Guardrails

1. Extend existing authoritative paths; avoid unbounded parallel runtime paths.
2. Keep optional and harness workflows off default runtime/validation path.
3. Require explicit rollback notes and validation evidence for non-trivial
   changes.

## Queue Links

- [Major Items Directory](majors/README.md)
- [Minor Items Directory](minors/README.md)
- [History Archive](history/README.md)
- [Harness Templates](harness/templates/)

## Schema Quick Reference

- [Major Schema](MAJOR_SCHEMA.md)
- [Minor Schema](MINOR_SCHEMA.md)
- [Work Item System Policy](harness/02-WORK_ITEM_SYSTEM.md)
- [Agent Execution Protocol](harness/03-AGENT_EXECUTION_PROTOCOL.md)
- [Quality Gates](harness/04-QUALITY_GATES.md)

## Major Queue

1. [`001-harness-improvements-architecture`](majors/001-harness-improvements-architecture.md) (done): establish full
   `improvements/` anchors, schemas, and item taxonomy layout.
2. [`002-canonical-dev-command-surface`](majors/002-canonical-dev-command-surface.md) (done): implement `scripts/dev.py`
   with stable quality and harness subcommands.
3. [`003-quality-gate-baseline-wiring`](majors/003-quality-gate-baseline-wiring.md) (backlog): map project checks to harness
   gates and enforce baseline evidence capture.

## Minor Queue

1. [`m001-improvements-index-polish`](minors/m001-improvements-index-polish.md) (done): add cross-links and quick
   navigation for item queues and archive conventions.
2. [`m002-work-item-linting`](minors/m002-work-item-linting.md) (done): add a lightweight validator for
   required schema sections.
3. [`m003-rollup-evidence-template`](minors/m003-rollup-evidence-template.md) (done): add reusable end-of-item
   evidence snippets for common command outcomes.

## Recommended Execution Order

1. Execute `003-quality-gate-baseline-wiring`.
2. Run one major and one minor item end-to-end using expanded strict-gate
   evidence once 003 lands.
3. Capture a retrospective under `improvements/history/` and queue next
   minors/majors.

## Notes

- `CLAUDE.md` is compatibility-only; `AGENTS.md` + harness docs are the active
  process authority.
- `improvements/history/` is the default archive path for generated evidence.
