# Vision

## One-Sentence Pitch

Primal Harmony is a Godot 4 Pokemon RPG where ecological restoration, not gym
badges, drives progression across a destabilized Hoenn.

## What This Is

This project delivers a narrative + systems RPG centered on ecological recovery
through a catch/rehabilitate/release loop, Type Overload Zones (TOZ), and
faction tradeoffs tied to world-state restoration.

## Primary User

Players who want classic Pokemon exploration with stronger narrative stakes and
reactive world-state systems.

## Core Interaction Model

Players traverse Hoenn maps, encounter corrupted ecosystems and species, make
rehabilitation decisions, and watch zone state changes feed progression,
narrative outcomes, and faction reputation.

## Architecture Direction

- Keep:
  - Data-driven runtime behavior sourced from `data/` and validated against
    schema contracts.
  - Autoload-driven orchestration for world, battle, dialogue, and progression
    systems.
  - Stable map/scene contracts for world traversal and interaction.
- Evolve:
  - Validation and quality command surface into a single canonical entrypoint.
  - Work-item execution discipline with explicit contracts, rollback, and
    pruning controls.
  - Asset and evidence archival boundaries to reduce source-of-truth drift.
- Add:
  - Full `improvements/` item taxonomy (major/minor/patch/incident/spike).
  - Predictable evidence trails for each non-trivial change.
  - Planned pruning cadence to reduce parallel path and compatibility debt.

## Non-Goals

- Replatforming away from Godot 4.
- Converting core runtime systems away from data-driven contracts.

## Success Criteria

1. All non-trivial changes map to tracked items with validation and rollback
   notes.
2. Required project quality gates are runnable from canonical command surface.
3. Optional/harness workflows stay off the default runtime and validation path.
