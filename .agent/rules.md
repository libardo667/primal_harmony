# Primal Harmony — Workspace Rules

You are an agent working on **Pokémon Emerald: Primal Harmony**, a fan game built in **Godot 4** using **GDScript**, developed via Google Antigravity's agentic workflow.

---

## What This Project Is

A Pokémon fan game set in a future Hoenn destabilized by invasive Pokémon from every region. The player is a Pokémon Rehabilitator working with Team Aqua, Team Magma, Kyogre, Groudon, and Rayquaza to restore ecological balance.

> Core theme: *"Balance is not a destination. It is a relationship that must be earned."*

Key systems: Ecological Harmony Index (EHI), 10 Type Overload Zones, Corrupted Regional Variants, Catch/Rehabilitate/Release loop, Rayquaza Bond Mechanic, dual faction reputation meters.

---

## You Are Part of The Circle

This project is developed by a team of six specialized agents called **The Circle**. Each agent owns a specific domain. You are one of them. Your role will be defined when you are activated.

**Before doing anything else in a new conversation, read:**
1. `agents/AGENT_OVERVIEW.md` — full Circle roster, project structure, Godot conventions
2. Run `python3 agents/scripts/comms.py agents/COMMS_LOG.csv status` — current project state
3. Your task queue: `agents/tasks/[yourname]_tasks.md`

---

## Project Structure (Reference)

```
primal_harmony/
├── .agent/           ← Antigravity config (rules, workflows, skills)
├── actors/           ← Player, Pokémon, NPC scenes
├── battle/           ← Battle engine — core logic, UI, effects
├── data/             ← JSON/tres resources — stats, moves, items, zones
├── maps/             ← TileMap scenes — Hoenn regions, interiors
├── systems/          ← Autoloaded systems — EHI, faction, rehab, encounter
├── ui/               ← HUD, menus, Pokédex, relocation terminal
├── assets/           ← Sprites, audio, fonts, tilesets
├── agents/           ← Circle coordination files
│   ├── scripts/      ← Coordination tools (e.g. comms.py)
│   └── COMMS_LOG.csv ← Source of truth for agent progress
├── tools/            ← General dev tools (audit_tscn.py, debug spawners)
└── docs/             ← Design documents
```

---

## Non-Negotiable Rules

- **Check status before acting.** Run `python3 agents/scripts/comms.py agents/COMMS_LOG.csv status`. Never assume the current project state.
- **Log everything.** Start of task, end of task, blocks, design decisions. Use the script: `python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The <Role>" "Message"`
- **Stay in your domain.** Cross-domain edits require a comms log notice first.
- **Collision Layer Contracts:** Maps must strictly follow layer assignments (terrain=1, warps=2, encounters=4, player=128, npcs=256).
- **Audit Tool Requirement:** Always run `python3 tools/audit_tscn.py .` before delivering a scene to The Elder.
- **Use static typing in GDScript.** Better agent IntelliSense, fewer silent failures.
- **Never hardcode stats or move data.** All game data lives in `data/` as JSON or `.tres`.
- **New Autoloads must be flagged to The Elder.** Do not modify `project.godot` directly.
- **Signals over direct calls** for cross-system communication.

---

## Design Documents — Source of Truth

All agents must treat these documents as canonical. If code or dialogue conflicts with a doc, flag it to The Elder before proceeding.

### Mechanics & World
- `docs/scaffolding_v0_3.md` — **[CURRENT]** mechanics, EHI, factions, starter system, phase structure, resolved design questions
- `docs/TOZ_field_atlas_v0_2.md` — all 10 zones, 30+ corrupted variants, 18 starter forms
- `docs/world_state_v0_1.md` — **[NEW]** Hoenn geography, what exists/changed/is gone, location-by-location

### Narrative & Characters
- `docs/narrative_bible_v0_1.md` — **[NEW]** full story beats for all 3 phases, Team Obsidian reveal, three resolution paths, epilogue. The Weaver's primary reference.
- `docs/characters_v0_1.md` — **[NEW]** player character, grandparents, Maxie, Archie, key NPCs — with voice notes for writers

> **Note:** `docs/scaffolding_v0_2.md` is superseded by v0.3. Do not reference it for new work.
