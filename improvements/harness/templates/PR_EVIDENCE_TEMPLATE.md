# PR Evidence

## Change Summary

- Item ID(s): <id list>
- PR Scope: <one paragraph>
- Risk Level: <low|medium|high>

## Behavior Impact

- User-visible changes:
  - <change>
- Non-user-visible changes:
  - <change>
- Explicit non-goals:
  - <non-goal>

## Validation Results

- `<command>` -> <pass|fail|blocked> (<notes>)
- `<command>` -> <pass|fail|blocked> (<notes>)
- `<command>` -> <pass|fail|blocked> (<notes>)

## Validation Snippets (Reusable)

Use these short patterns when writing item logs or PR evidence:

- `pass`: `<command>` -> pass (`<key output or summary>`)
- `fail`: `<command>` -> fail (`<failure summary>`, follow-up: `<item id or fix>`)
- `blocked`: `<command>` -> blocked (`<reason>`, substitute: `<nearest evidence command>`)

Authoritative references:

- `AGENTS.md` (quality/evidence requirements)
- `improvements/harness/03-AGENT_EXECUTION_PROTOCOL.md` (validation handling)
- `improvements/harness/04-QUALITY_GATES.md` (gate expectations)

## Contract and Compatibility

- Contract/API changes: <none or describe>
- Migration/state changes: <none or describe>
- Backward compatibility: <statement>
- CLI command surface compatibility: <none or describe + migration note>

## Map Contract Evidence (for map-touching items)

Include this block when any `.tscn` files under `maps/` were changed. Required
gate: medium-risk or stricter (`--risk medium` minimum).

```
- `python scripts/dev.py quality-strict --risk medium --emit-evidence`
  [Gate 4 runtime-behavior] `scene-audit` -> pass (`scene audit passed`)
- `python scripts/dev.py harness scene-audit .`
  -> pass (RESULTS: 0 errors, 0 warnings, 0 info)
```

Failure pattern (if Gate 4 is red — do not mark done until resolved):

```
- `python scripts/dev.py harness scene-audit .`
  -> fail (RESULTS: N errors, N warnings, N info)
  follow-up: <item id or inline fix>
```

See `references/scene-contracts.md` for the full validation requirement and
per-warp checklist.

## Pruning Prevention Evidence

- Authoritative path extended: <path/module>
- Parallel path introduced: <no or details + expiry/removal plan>
- Optional/harness feature stayed off default path: <yes/no + note>
- Generated artifacts location: <archive/source-of-truth path summary>
- New/changed feature flags: <none or lifecycle details>

## Metrics (if applicable)

- Baseline:
  - <metric>: <value>
- After:
  - <metric>: <value>

## Risks

- <risk 1>
- <risk 2>

## Rollback Plan

- Fast disable path: <flag/config/revert>
- Full revert path: <commit or step list>

## Follow-up Work

- <new item id or title>
- <new item id or title>
