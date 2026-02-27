# Primal Harmony — Updated File Tree

**Legend:**
- 🆕 `NEW` — Create this file (doesn't exist yet)
- ✏️ `UPDATED` — File exists, needs specific edits (see change notes below)
- ✅ `KEEP` — No changes needed
- 🗑️ `DELETE` — Remove this file
- 💤 `CRUFT` — Godot auto-generated, harmless, ignore

---

## The Tree

```
primal-harmony/
│
├── antigravity/.agent/                          ← Antigravity IDE config layer
│   │
│   ├── rules.md                                 ✏️ UPDATED
│   │
│   ├── workflows/
│   │   ├── wake-elder.md                        ✏️ UPDATED
│   │   ├── wake-mechanic.md                     ✏️ UPDATED
│   │   ├── wake-keeper.md                       ✏️ UPDATED
│   │   ├── wake-artisan.md                      ✏️ UPDATED
│   │   ├── wake-shaper.md                       ✏️ UPDATED
│   │   └── wake-weaver.md                       ✏️ UPDATED
│   │
│   └── skills/
│       ├── add-corrupted-variant/SKILL.md       ✏️ UPDATED
│       ├── add-starter-form/SKILL.md            ✏️ UPDATED
│       ├── add-toz-zone/SKILL.md                ✏️ UPDATED
│       ├── check-queue/SKILL.md                 ✏️ UPDATED (significant rewrite)
│       ├── validate-data-schema/SKILL.md        ✏️ UPDATED (minor)
│       │
│       ├── comms-log-tool/                      🆕 NEW SKILL
│       │   └── SKILL.md
│       │
│       └── godot-integration-doctor/            🆕 NEW SKILL
│           └── SKILL.md
│
├── agents/                                      ← In-project coordination layer
│   ├── AGENT_OVERVIEW.md                        ✏️ UPDATED
│   ├── COMMS_LOG.csv                            ✅ KEEP
│   ├── QUEST_FLAGS.md                           ✅ KEEP
│   ├── COMMS_LOG.csv.import                     💤 CRUFT (Godot auto-gen)
│   ├── COMMS_LOG.Message.translation            💤 CRUFT (Godot auto-gen)
│   ├── COMMS_LOG.Role.translation               💤 CRUFT (Godot auto-gen)
│   │
│   ├── scripts/                                 🆕 NEW DIRECTORY
│   │   └── comms.py                             🆕 NEW (comms log CLI tool)
│   │
│   └── tasks/
│       ├── elder_tasks.md                       ✏️ UPDATED
│       ├── mechanic_tasks.md                    ✏️ UPDATED
│       ├── shaper_tasks.md                      ✏️ UPDATED
│       ├── keeper_tasks.md                      ✅ KEEP
│       ├── artisan_tasks.md                     ✅ KEEP
│       └── weaver_tasks.md                      ✅ KEEP
│
├── tools/                                       ← (directory may already exist)
│   ├── audit_tscn.py                            🆕 NEW (scene integration linter)
│   ├── generate_debug_spawner.py                🆕 NEW (standalone map test harness)
│   └── generate_phase4_assets.py                ✅ KEEP (existed before)
│
├── _archive/
│   └── COMMS_LOG.md                             ✅ KEEP (old format, archived)
│
├── docs/
│   ├── scaffolding_v0.2.md                      ✅ KEEP
│   └── TOZ_field_atlas_v0.2.md                  ✅ KEEP
│
└── (all other game directories: actors/, battle/, data/, maps/, systems/, ui/, assets/)
                                                 ✅ KEEP — no changes
```

---

## Change Notes Per File

### antigravity/.agent/rules.md

**What changed:**
1. Activation sequence: replaced "Read agents/COMMS_LOG.md" with comms.py commands
2. Non-Negotiable Rules: added collision layer contracts, audit tool requirement
3. Project structure diagram: added agents/scripts/comms.py, tools/, COMMS_LOG.csv

**Key lines to find-and-replace:**

| Find | Replace with |
|------|-------------|
| `agents/COMMS_LOG.md` (in activation sequence) | `python3 agents/scripts/comms.py agents/COMMS_LOG.csv status` |
| `agents/role_[yourname].md` (step 3) | Remove — these files never existed |
| Non-negotiable rules section | Add: collision layers (warps=2, encounters=4), audit tool |
| Project structure `.agent/` diagram | Add `agents/scripts/`, `tools/`, fix `COMMS_LOG.csv` |

---

### antigravity/.agent/workflows/wake-elder.md

**What changed:**
1. Activation Sequence: comms.py status + recent 10 instead of reading COMMS_LOG.md
2. Step 3 (Integrate): added "Run python3 tools/audit_tscn.py ." before declaring success

**Find → Replace:**

| Find | Replace with |
|------|-------------|
| `Read agents/COMMS_LOG.md (last 20 entries minimum)` | Two steps: `Run: python3 agents/scripts/comms.py agents/COMMS_LOG.csv status` and `Run: python3 agents/scripts/comms.py agents/COMMS_LOG.csv recent 10` |
| `Log your activation and current assessment` | `Log activation: python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Elder" "Activated. [assessment]"` |
| `review files, register Autoloads, verify scene structure, check signal connections. Run the project.` | Same but insert `Run python3 tools/audit_tscn.py . to check all scenes for integration errors.` before "Run the project." |

---

### antigravity/.agent/workflows/wake-mechanic.md

**What changed:**
1. Activation Sequence: comms.py instead of COMMS_LOG.md
2. Line 22: fix stale reference "log its full signature to agents/COMMS_LOG.md"

**Find → Replace:**

| Find | Replace with |
|------|-------------|
| `Read agents/COMMS_LOG.md — check what The Keeper has completed` | `Run: python3 agents/scripts/comms.py agents/COMMS_LOG.csv status` |
| `log its full signature to agents/COMMS_LOG.md immediately` | `log its full signature using: python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Mechanic" "[signal signature]"` |
| `Log activation. Verify Keeper prerequisites` | `Log activation: python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Mechanic" "Activated. [status]"` + `Verify Keeper prerequisites` |

---

### antigravity/.agent/workflows/wake-keeper.md

**What changed:** Activation sequence only.

| Find | Replace with |
|------|-------------|
| `Read agents/COMMS_LOG.md (last 20 entries minimum)` | `Run: python3 agents/scripts/comms.py agents/COMMS_LOG.csv status` + `Run: python3 agents/scripts/comms.py agents/COMMS_LOG.csv recent 10` |
| `Log activation. Check for highest-priority` | `Log activation: python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Keeper" "Activated. [status]"` + `Check for highest-priority tasks.` |

---

### antigravity/.agent/workflows/wake-artisan.md

**What changed:** Activation sequence only.

| Find | Replace with |
|------|-------------|
| `Read agents/COMMS_LOG.md — check what Keeper has confirmed` | `Run: python3 agents/scripts/comms.py agents/COMMS_LOG.csv status` + `Run: python3 agents/scripts/comms.py agents/COMMS_LOG.csv recent 10` |
| `Log activation and any immediate coordination needs.` | `Log activation: python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Artisan" "Activated. [status]"` |

---

### antigravity/.agent/workflows/wake-shaper.md

**What changed:**
1. Activation Sequence: comms.py + collision_layer search
2. Required Scene Structure: added collision_layer values to every node type
3. NEW subsection: "CRITICAL: Collision Layers" table
4. NEW subsection: "Pre-Delivery Verification" with audit_tscn.py

**Find → Replace:**

| Find | Replace with |
|------|-------------|
| `Read agents/COMMS_LOG.md` (step 2) | `Run: python3 agents/scripts/comms.py agents/COMMS_LOG.csv status` + new step: `Run: python3 agents/scripts/comms.py agents/COMMS_LOG.csv search "collision_layer"` |
| Scene structure diagram (WarpPoints line) | `├── WarpPoints (Area2D nodes, collision_layer=2, metadata: destination_scene, destination_warp_id)` |
| Scene structure diagram (EncounterZones line) | `├── EncounterZones (Area2D nodes, collision_layer=4, metadata: zone_id)` |
| After scene structure diagram | Insert collision layer table and audit verification section |

---

### antigravity/.agent/workflows/wake-weaver.md

**What changed:** Activation sequence + collision layer note for NPCs.

| Find | Replace with |
|------|-------------|
| `Read agents/COMMS_LOG.md — especially signal definitions` | `Run: python3 agents/scripts/comms.py agents/COMMS_LOG.csv status` + `Run: python3 agents/scripts/comms.py agents/COMMS_LOG.csv search "signal"` |
| Step 1 AGENT_OVERVIEW note | Add: `especially Collision Layer Contracts (NPC interaction uses collision_layer = 256)` |

---

### antigravity/.agent/skills/check-queue/SKILL.md

**Significant rewrite.** This is the skill agents use most and it has the most stale references.

| Find | Replace with |
|------|-------------|
| Step 1 item 2: `agents/COMMS_LOG.md — last 20 entries minimum` | `Run: python3 agents/scripts/comms.py agents/COMMS_LOG.csv status` |
| Step 1 item 3: `Your role file: agents/role_[yourname].md` | Remove — these files never existed |
| Step 3 item 1: `Search agents/COMMS_LOG.md for completion confirmation` | `Run: python3 agents/scripts/comms.py agents/COMMS_LOG.csv search "[dependency keyword]"` |
| Step 5 item 2: `Log to agents/COMMS_LOG.md:` + old format block | `Log: python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The [Role]" "Completed [Task]. [details]. Ready for The [Next Agent]."` |
| Step 6 idle log format | Same comms.py add format |

---

### antigravity/.agent/skills/add-corrupted-variant/SKILL.md

**Minor.** Two log references to fix.

| Find | Replace with |
|------|-------------|
| `Log the identity to agents/COMMS_LOG.md before proceeding.` | `Log: python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Keeper" "[identity details]"` |
| Step 5 log format examples | Update to use comms.py add command |

---

### antigravity/.agent/skills/add-starter-form/SKILL.md

**Minor.** Log format examples in Step 5 use old `[Date] **The Keeper**:` format.

| Find | Replace with |
|------|-------------|
| Step 5 log format block | `python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Keeper" "Starter form complete — [FormName]. Path: [path], Stage [N]. JSON at data/starters/[id].json."` |

---

### antigravity/.agent/skills/add-toz-zone/SKILL.md

**Minor.** Two log references.

| Find | Replace with |
|------|-------------|
| `Log the completed schema to agents/COMMS_LOG.md.` | `Log: python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Keeper" "Zone data complete — [zone_name]. JSON at data/zones/[zone_id].json."` |
| Phase 2b (Shaper map section) | Add: `Run python3 tools/audit_tscn.py . before handing off. Zero errors required.` |
| Completion Log Template | Update all entries to use comms.py add command |

---

### antigravity/.agent/skills/validate-data-schema/SKILL.md

**Minor.** Log format example at bottom.

| Find | Replace with |
|------|-------------|
| `[Date] **The Keeper**: Schema audit complete` block | `python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Keeper" "Schema audit complete for [scope]. Files: [list]. Issues: [none/details]."` |

---

### 🆕 antigravity/.agent/skills/comms-log-tool/SKILL.md

**New file.** Short skill pointer that tells agents the tool exists and where it is.

Content: Trigger description + quick reference for all 10 commands + activation protocol.
(Full content already generated — see comms-log-tool/SKILL.md from earlier in this session.)

---

### 🆕 antigravity/.agent/skills/godot-integration-doctor/SKILL.md

**New file.** Short skill pointer for the integration audit workflow.

Content: Trigger description + 6-step diagnostic methodology + common failure table.
(Full content already generated — see godot-integration-doctor/SKILL.md from earlier.)

---

### agents/AGENT_OVERVIEW.md

**What changed:**
1. Communication Protocol section: replaced old "log to COMMS_LOG.md" with comms.py activation protocol
2. Project Structure: updated tree to show scripts/, tools/, correct filenames
3. Godot-Specific Conventions: added Collision Layer Contracts table, Map Scene Delivery Checklist, Integration Audit section

---

### agents/tasks/elder_tasks.md

**What changed:**
1. Phase 5 integration pass: added audit_tscn.py step
2. NEW section: "Elder's Synthesis Toolkit" — 3-command sequence for every integration pass

---

### agents/tasks/mechanic_tasks.md

**What changed:**
1. NEW section at top: "Interface Contracts" — Player detection layers, signals, warp/encounter metadata contracts
2. Phase 5.5: fixed collision_layer values (was "2 and 8", now correctly "2 and 4"), added specific scene list, added audit verification step

---

### agents/tasks/shaper_tasks.md

**What changed:**
1. NEW section at top: "Map Delivery Checklist (EVERY map, EVERY time)" — 10-item preflight with audit_tscn.py as final step

---

### 🆕 agents/scripts/comms.py

**New file.** The comms log CLI tool. 10 commands: recent, full, status, role, search, since, add, count, phases, validate.

---

### 🆕 tools/audit_tscn.py

**New file.** Scans all .tscn files for: missing collision layers, wrong layer values, broken warp metadata, nonexistent destination scenes, unmatched warp IDs, missing CollisionShape2D children.

---

### 🆕 tools/generate_debug_spawner.py

**New file.** Generates a GDScript that auto-spawns a Player when running a map scene standalone (F6). Detects whether the map root already has a script and generates the appropriate variant.

---

## Summary of All Changes

| Category | Files | New | Updated | Kept | Deleted |
|----------|-------|-----|---------|------|---------|
| antigravity/.agent/ | 14 | 2 | 12 | 0 | 0 |
| agents/ | 12 | 1 | 4 | 7 | 0 |
| tools/ | 3 | 2 | 0 | 1 | 0 |
| **Total** | **29** | **5** | **16** | **8** | **0** |

Nothing gets deleted. 5 new files. 16 files get targeted edits. 8 stay as-is.

The single unifying change across all 16 updated files: every reference to
`agents/COMMS_LOG.md` becomes a `python3 agents/scripts/comms.py` command,
and every map-touching workflow gains collision layer contracts and audit verification.
