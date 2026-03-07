# 008 - Rehabilitation Log and Terminal Logic

## Metadata

- ID: 008-rehabilitation-log-and-terminal-logic
- Type: major
- Owner: Antigravity
- Status: backlog
- Risk: medium
- Created: 2026-03-06
- Target Window: Milestone 1
- Depends On: 006-ehi-core-systems
- Contract Impact: backward_compatible
- Default-Path Impact: core_path
- Artifact Outputs: `systems/rehab/RehabilitationLog.gd`, `systems/rehab/RelocationTerminal.gd`

## Problem

The high-level progression loop in Primal Harmony relies on a catch/rehabilitate/release cycle tracked via the "Rehabilitation Log" (`docs/scaffolding_v0_3.md`). There is currently no persistent data structure to record these events, nor is there a logic layer for the "Relocation Terminals" at Pokemon Centers to manage the release flow and its impact on EHI.

## Proposed Solution

Implement the core rehabilitation and relocation logic:
1.  Create the `RehabilitationLog` resource to store release history (species, origin, date, outcome).
2.  Implement the `RelocationTerminal` service to handle the UI and logic for releasing Pokemon via Nurse Joy.
3.  Connect the `RelocationTerminal` to the `EHIManager` to ensure releases correctly boost local EHI.
4.  Implement the "Triage Catch" record-keeping (tracking whether a catch was a rescue in Phase One).

## Files Affected

- `systems/rehabilitation/RehabilitationLog.gd` [NEW]
- `systems/rehabilitation/RelocationTerminal.gd` [NEW]
- `data/rehabilitation/rewards_milestones.json` [NEW]
- `ui/rehab/RehabLogView.tscn` [NEW]

## Non-Goals

- Implementing the full UI for the Rehabilitation Log (this is a logic/backend-focused major).
- Implementing faction-specific relocation rewards (handled later).

## Acceptance Criteria

- [ ] Every release event is correctly recorded in the `RehabilitationLog`.
- [ ] Relocation Terminal correctly filters available Pokemon based on "rehab status".
- [ ] Terminal releases successfully trigger EHI updates via the `EHIManager`.
- [ ] Save system correctly persists the entire rehabilitation history.

## Validation Commands

- `python scripts/dev.py quality-strict`
- `python scripts/dev.py harness test rehab-logic`

## Pruning Prevention Controls

- Authoritative path for touched behavior: `systems/rehabilitation/`
- Parallel path introduced: none
- Optional/harness behavior on default path: no
- Generated artifacts + archive target: none

## Risks and Rollback

Risks:
- Data corruption in the log could leading to lost progression history.
- Performance issues with large logs if not properly paged or indexed.

Rollback:
- Revert `SaveSystem.gd` changes and disable terminal interaction scripts.

## Execution Log

- [2026-03-06] Item drafted based on `docs/scaffolding_v0_3.md` and `docs/characters_v0_1.md`.

## Follow-up Candidates

- `m008-triage-catch-refactor`
- `m009-nurse-joy-relocation-flows`
