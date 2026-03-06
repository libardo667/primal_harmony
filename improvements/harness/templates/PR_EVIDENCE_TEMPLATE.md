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
