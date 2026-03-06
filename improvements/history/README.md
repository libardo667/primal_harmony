# History Archive

Archive generated evidence and run-specific artifacts here.

Examples:

- gate output captures,
- retrospectives,
- temporary audit exports.

Do not move runtime source-of-truth files here.

## Evidence Rollup Snippets

Use concise command-result snippets in item logs and archived evidence:

- `pass`: `<command>` -> pass (`<key output>`)
- `fail`: `<command>` -> fail (`<error summary>`, disposition: `<fix/follow-up>`)
- `blocked`: `<command>` -> blocked (`<why blocked>`, substitute: `<nearest evidence>`)

Reference docs:

- `AGENTS.md`
- `improvements/harness/03-AGENT_EXECUTION_PROTOCOL.md`
- `improvements/harness/04-QUALITY_GATES.md`
