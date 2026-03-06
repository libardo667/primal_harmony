# Improvements Workspace

This directory is the project planning and execution workspace defined by
`AGENTS.md` and the harness under `improvements/harness/`.

## Quick Links

- [Vision](VISION.md)
- [Roadmap](ROADMAP.md)
- [Major Queue](majors/README.md)
- [Minor Queue](minors/README.md)
- [Major Schema](MAJOR_SCHEMA.md)
- [Minor Schema](MINOR_SCHEMA.md)
- [Harness Index](harness/README.md)
- [History Archive Guide](history/README.md)

## Structure

- `VISION.md`: product and architecture intent anchor.
- `ROADMAP.md`: prioritized execution queue and guardrails.
- `MAJOR_SCHEMA.md`: authoritative schema for major work items in this repo.
- `MINOR_SCHEMA.md`: authoritative schema for minor work items in this repo.
- `majors/`: active and archived major items.
- `minors/`: active and archived minor items.
- `patches/`: urgent regression patch items.
- `incidents/`: incident records and prevention follow-ups.
- `spikes/`: time-boxed research items.
- `history/`: archived run outputs, evidence artifacts, and retrospectives.
- `harness/`: reusable operating kit and templates.

## Workflow Entry

1. Read `AGENTS.md`.
2. Read active item in `majors/` or `minors/`.
3. Read `VISION.md`, `ROADMAP.md`, and required harness policy docs.
4. Execute bounded changes and capture validation evidence.

## Command Surface

The canonical developer command surface is `python scripts/dev.py ...` as
defined in `AGENTS.md`. If a required command is unavailable, record a blocked
result and provide substitute evidence without marking the item done.

Current command groups:

- `python scripts/dev.py quality-strict`
- `python scripts/dev.py harness list`
- `python scripts/dev.py harness scene-audit .`
- `python scripts/dev.py harness item-lint`

## Test Prereqs

- `python scripts/dev.py quality-strict`: does not require the Godot editor to
  be open.
- `python scripts/dev.py harness scene-audit .`: does not require the Godot
  editor to be open.
- Godot editor is required for editor-only workflows (for example
  `tools/build_anim_tilesets.gd` as an EditorScript).

## Artifact Boundary

Runtime source-of-truth files stay in canonical project paths. Generated run
outputs and evidence artifacts are archived under `improvements/history/`.

Archive examples:

- quality gate summaries and command transcripts,
- retrospective notes and decision snapshots,
- optional audit outputs generated during investigations.
