# Minor Item Schema

This file defines the authoritative required structure for minor items in this
repository. Harness templates are fallback only when this schema does not cover
an optional section.

## File Location and Naming

- Path: `improvements/minors/`
- Filename format: `<id>-<slug>.md`
- Example: `m001-improvements-index-polish.md`

## Required Sections

Each minor item must include all sections below in this order.

1. `# <title>`
2. `## Metadata`
3. `## Problem`
4. `## Proposed Solution`
5. `## Files Affected`
6. `## Acceptance Criteria`
7. `## Validation Commands`
8. `## Pruning Prevention Controls`
9. `## Risks and Rollback`
10. `## Execution Log`

## Required Metadata Fields

- `ID`
- `Type` (must be `minor`)
- `Owner`
- `Status` (`backlog|ready|in_progress|blocked|verify|done|archived`)
- `Risk` (`low|medium`)
- `Created`
- `Contract Impact` (`none|backward_compatible|breaking`)
- `Default-Path Impact` (`none|optional_only|core_path`)
- `Artifact Outputs`

## Validation Rules

- Include only commands relevant to the touched surface.
- If any required command is blocked, record blocked reason and nearest
  substitute evidence before closing.

## Closure Requirements

Before setting status to `done`, confirm:

- acceptance criteria are checked,
- validation evidence is recorded,
- rollback note is present,
- pruning-prevention controls are complete.
