# Major Item Schema

This file defines the authoritative required structure for major items in this
repository. Harness templates are fallback only when this schema does not cover
an optional section.

## File Location and Naming

- Path: `improvements/majors/`
- Filename format: `<id>-<slug>.md`
- Example: `001-harness-improvements-architecture.md`

## Required Sections

Each major item must include all sections below in this order.

1. `# <title>`
2. `## Metadata`
3. `## Problem`
4. `## Proposed Solution`
5. `## Files Affected`
6. `## Non-Goals`
7. `## Acceptance Criteria`
8. `## Validation Commands`
9. `## Pruning Prevention Controls`
10. `## Risks and Rollback`
11. `## Execution Log`
12. `## Follow-up Candidates`

## Required Metadata Fields

- `ID`
- `Type` (must be `major`)
- `Owner`
- `Status` (`backlog|ready|in_progress|blocked|verify|done|archived`)
- `Risk` (`low|medium|high`)
- `Created`
- `Target Window`
- `Depends On`
- `Contract Impact` (`none|backward_compatible|breaking`)
- `Default-Path Impact` (`none|optional_only|core_path`)
- `Artifact Outputs`

## Validation Rules

- Non-trivial items must include `python scripts/dev.py quality-strict`.
- If a required command is blocked, record:
  - why it was blocked,
  - nearest substitute command/evidence,
  - item status as `verify` or `blocked` (not `done`).

## Closure Requirements

Before setting status to `done`, confirm:

- acceptance criteria are checked,
- required validation evidence is recorded,
- rollback path is documented,
- pruning-prevention checks are explicitly answered,
- follow-up debt is captured as new item candidates.
