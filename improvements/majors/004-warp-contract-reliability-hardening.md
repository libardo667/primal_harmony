# Warp Contract Reliability Hardening

## Metadata

- ID: 004-warp-contract-reliability-hardening
- Type: major
- Owner: unassigned
- Status: backlog
- Risk: medium
- Created: 2026-03-06
- Target Window: 2026-03
- Depends On: m004-fallarbor-warp-target-fix
- Contract Impact: backward_compatible
- Default-Path Impact: optional_only
- Artifact Outputs: source-of-truth updates under `scripts/`, `tools/`,
  `references/`, and `maps/`; run evidence archived under
  `improvements/history/`

## Problem

Runtime Gate 4 (`scene-audit`) currently fails on a known Fallarbor warp target
contract violation. While the immediate issue is localized, it exposes broader
map-scene drift risk:

- warp contract violations are discovered late in validation,
- map-touching work does not consistently run medium-risk profile checks,
- gate evidence for map contract health is not yet standardized.

## Proposed Solution

Harden warp contract reliability across map-related workflows:

- remediate the known Fallarbor issue (tracked in dependent minor `m004`),
- extend map-validation guidance to require medium-risk Gate 4 checks for
  map-touching items,
- tighten `scene-audit` and command-surface documentation for faster triage and
  consistent remediation evidence,
- add a concise map-contract evidence pattern for item/PR logs.

## Files Affected

- scripts/dev.py
- improvements/README.md
- improvements/ROADMAP.md
- improvements/majors/004-warp-contract-reliability-hardening.md
- improvements/harness/templates/PR_EVIDENCE_TEMPLATE.md
- references/scene-contracts.md
- tools/audit_tscn.py

## Non-Goals

- Rewriting map runtime traversal architecture.
- Introducing CI-vendor-specific workflow coupling.

## Acceptance Criteria

- [ ] Map-touching workflow guidance explicitly requires `--risk medium` (or
      stricter) validation.
- [ ] Gate 4 evidence format is documented and reusable in item/PR logs.
- [ ] `scene-audit` failure output remains deterministic and actionable.
- [ ] Medium-risk strict profile is green for baseline maps after dependent
      minor remediation.

## Validation Commands

- `python scripts/dev.py quality-strict --risk medium`
- `python scripts/dev.py quality-strict --risk high`
- `python scripts/dev.py harness scene-audit .`
- `python scripts/dev.py harness scene-audit . --json`
- `git status --short`

## Pruning Prevention Controls

- Authoritative path for touched behavior: map contract validation surface in
  `scripts/dev.py` and `tools/audit_tscn.py`.
- Parallel path introduced: none.
- Optional/harness behavior on default path: no.
- Generated artifacts + archive target: optional audit outputs and transcripts
  under `improvements/history/`.
- Flag lifecycle (if applicable): none.

## Risks and Rollback

Risks:

- Stricter map validation may temporarily increase blocked items.
- Incomplete guidance updates may cause inconsistent gate usage.

Rollback:

- Revert strict map-validation wiring/docs commits.
- Keep stronger checks opt-in behind explicit risk profile until stabilized.

## Execution Log

- 2026-03-06: Item drafted from roadmap follow-up queue; status `backlog`.

## Follow-up Candidates

- map-contract-evidence-rollup
- scene-audit-triage-playbook
