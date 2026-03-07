# Scene Audit Triage Playbook

## Metadata

- ID: m011-scene-audit-triage-playbook
- Type: minor
- Owner: unassigned
- Status: backlog
- Risk: low
- Created: 2026-03-06
- Contract Impact: none
- Default-Path Impact: none
- Artifact Outputs: source-of-truth doc under `references/`

## Problem

`tools/audit_tscn.py` emits inline fix hints for individual issues, but there is
no consolidated reference doc for diagnosing and remediating recurring Gate 4
failure patterns. When a map-touching item triggers `warp_target_no_warppoints`,
`warp_missing_collision_layer`, or `encounter_missing_collision_layer`, the
developer must re-derive the fix from first principles or hunt through the audit
script source.

This was listed as a follow-up candidate in `004-warp-contract-reliability-hardening`.

## Proposed Solution

Add `references/scene-audit-triage.md` covering the 8 check codes emitted by
`audit_tscn.py`:

- `warp_missing_collision_layer` / `warp_collision_layer_mismatch`
- `warp_missing_destination_scene` / `warp_destination_scene_missing`
- `warp_target_no_warppoints` / `warp_target_id_missing`
- `warp_missing_destination_warp_id` / `warp_no_return`
- `encounter_missing_collision_layer` / `encounter_collision_layer_mismatch`
- `encounter_missing_zone_id`
- `area2d_no_collision_shape`
- `empty_warp_container`

For each check: severity (ERROR/WARNING/INFO), root cause in one sentence,
canonical fix with minimal `.tscn` snippet, and reference to `references/scene-contracts.md`.

## Files Affected

- `references/scene-audit-triage.md` [NEW]

## Acceptance Criteria

- [ ] All 8 check codes emitted by `audit_tscn.py` have an entry in the triage doc.
- [ ] Each entry includes severity, root cause, and canonical fix snippet.
- [ ] Doc links back to `references/scene-contracts.md` for the full contract.
- [ ] `python scripts/dev.py quality-strict` passes (docs only, Gate 0 not affected).

## Validation Commands

- `python scripts/dev.py quality-strict`
- `python scripts/dev.py harness item-lint`

## Pruning Prevention Controls

- Authoritative path: `references/` (alongside `scene-contracts.md` and `collision-contracts.md`).
- Parallel path introduced: none.
- Optional/harness behavior on default path: none.
- Generated artifacts: none.

## Risks and Rollback

- Risk: triage doc may drift if audit_tscn.py adds new check codes.
- Rollback: delete `references/scene-audit-triage.md` — no runtime impact.

## Execution Log

- 2026-03-06: Item drafted from 004-warp-contract-reliability-hardening follow-up
  candidate `scene-audit-triage-playbook`.
