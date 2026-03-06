# Quality Gate Baseline Wiring

## Metadata

- ID: 003-quality-gate-baseline-wiring
- Type: major
- Owner: unassigned
- Status: backlog
- Risk: medium
- Created: 2026-03-06
- Target Window: 2026-03
- Depends On: 002-canonical-dev-command-surface
- Contract Impact: backward_compatible
- Default-Path Impact: optional_only
- Artifact Outputs: source-of-truth updates under `scripts/` and
  `improvements/`; run evidence archived under `improvements/history/`

## Problem

`scripts/dev.py` establishes the canonical command entrypoint, but strict gate
coverage is still baseline. Project-specific checks are not yet fully mapped to
harness gate categories.

Current gaps:

- limited Gate 1/2/3 coverage in default strict flow,
- no explicit mapping from repository checks to harness gate evidence,
- inconsistent risk-tier expectations for non-trivial merges.

## Proposed Solution

Extend `python scripts/dev.py quality-strict` with project-aligned checks and
explicit gate mapping:

- add deterministic contract/static/correctness checks for touched surfaces,
- define required-vs-optional check tiers by risk level,
- standardize evidence output format for item/PR records,
- keep expensive or environment-sensitive checks under explicit optional flags.

## Files Affected

- scripts/dev.py
- improvements/ROADMAP.md
- improvements/majors/003-quality-gate-baseline-wiring.md
- improvements/history/* (validation evidence artifacts, if generated)

## Non-Goals

- Rewriting gameplay systems to satisfy checks.
- Enforcing CI provider-specific workflows in this item.

## Acceptance Criteria

- [ ] `quality-strict` includes explicit Gate 1/2/3 check mapping for this
      repo.
- [ ] Risk-tier policy for optional/deeper checks is documented and enforced by
      command options.
- [ ] Evidence output is reusable in item execution logs and PR evidence docs.
- [ ] Required checks run without producing unbounded generated artifacts in
      source-of-truth paths.

## Validation Commands

- `python scripts/dev.py quality-strict --json`
- `python scripts/dev.py harness list`
- `git status --short`

## Pruning Prevention Controls

- Authoritative path for touched behavior: `scripts/dev.py` and
  `improvements/` quality policy docs.
- Parallel path introduced: none.
- Optional/harness behavior on default path: no.
- Generated artifacts + archive target: optional run artifacts under
  `improvements/history/`.
- Flag lifecycle (if applicable): none.

## Risks and Rollback

Risks:

- Overly aggressive strict defaults may block normal delivery.
- Weak defaults may still permit regressions.

Rollback:

- Revert specific strict-check wiring commits and restore prior command set.
- Keep risky checks behind opt-in flags until stabilized.

## Execution Log

- 2026-03-06: Item drafted from roadmap queue; status `backlog`.

## Follow-up Candidates

- m002-work-item-linting
- m003-rollup-evidence-template
