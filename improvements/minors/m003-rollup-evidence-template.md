# Rollup Evidence Template

## Metadata

- ID: m003-rollup-evidence-template
- Type: minor
- Owner: codex
- Status: done
- Risk: low
- Created: 2026-03-06
- Contract Impact: none
- Default-Path Impact: none
- Artifact Outputs: source-of-truth template docs under `improvements/`

## Problem

Execution evidence is captured inconsistently across items, increasing review
time and making residual risk harder to scan quickly.

## Proposed Solution

Create reusable evidence snippets/templates for common validation outcomes:

- strict gate pass/fail/blocked snippets,
- command output summary snippets,
- residual risk + rollback note snippets.

## Files Affected

- improvements/harness/templates/PR_EVIDENCE_TEMPLATE.md
- improvements/history/README.md
- improvements/minors/m003-rollup-evidence-template.md

## Acceptance Criteria

- [x] Reusable snippets exist for pass/fail/blocked command outcomes.
- [x] Template usage guidance references authoritative source docs.
- [x] Evidence snippets remain concise and compatible with existing item schema.

## Validation Commands

- `python scripts/dev.py quality-strict`
- `git status --short`

## Pruning Prevention Controls

- Authoritative path: `improvements/` evidence documentation.
- Parallel path introduced: none.
- Artifact output target: source-of-truth docs in `improvements/`.
- Default-path impact: none.

## Risks and Rollback

- Risk: template churn may cause inconsistent evidence wording.
- Rollback: revert template-specific doc commit.

## Execution Log

- 2026-03-06: Item drafted from roadmap queue; status `backlog`.
- 2026-03-06: Item moved to `in_progress`.
- 2026-03-06: Added reusable validation snippets (pass/fail/blocked) to
  `improvements/harness/templates/PR_EVIDENCE_TEMPLATE.md`.
- 2026-03-06: Added concise evidence snippet guidance to
  `improvements/history/README.md`.
- 2026-03-06: Added authoritative-reference pointers to `AGENTS.md` and harness
  protocol/gate docs.
- 2026-03-06: Validation:
  - `python scripts/dev.py quality-strict` -> pass
  - `git status --short` -> pass
- 2026-03-06: Item moved to `done`.
