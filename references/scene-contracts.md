# Scene Composition Contracts

## What This Document Covers

In multi-agent Godot projects, different agents build different scenes. A root
controller scene loads map scenes as children and expects them to have specific
node structures. This document defines those contracts — what nodes must exist,
where they must be, and what metadata they must carry.

## The Player Spawn Contract

### Who spawns the Player?

In most architectures, the Player is NOT a child of any map scene. Instead, a
root game controller (e.g., `MainGame.gd`) instantiates `Player.tscn` and adds
it as a sibling of the current map.

**Implication:** Running a map scene standalone (F6) will show the map but no player.
This is by design, but it's confusing for agents testing their maps in isolation.

### Solutions for standalone testing

**Option A: Debug auto-spawner script**

Attach a script to the map root that checks if a Player already exists in the tree.
If not (meaning we're running standalone), spawn one:

```gdscript
# debug_map_runner.gd — attach to map root during development
extends Node2D

const PLAYER_SCENE := preload("res://actors/player/Player.tscn")

func _ready() -> void:
    # Only spawn player if no MainGame controller is present
    if not get_tree().root.has_node("MainGame"):
        var player = PLAYER_SCENE.instantiate()
        add_child(player)
        # Position at first warp point or center of map
        var wp = find_child("WarpPoints", true, false)
        if wp and wp.get_child_count() > 0:
            player.global_position = (wp.get_child(0) as Node2D).global_position
        else:
            var dims = get_meta("map_dimensions_px", Vector2i(640, 400))
            player.global_position = Vector2(dims.x / 2.0, dims.y / 2.0)
        print("[DebugSpawner] Player auto-spawned (standalone mode)")
```

**Option B: Test scene wrapper**

Create a minimal test scene that instances the map and spawns a player, like
`test_player.tscn` does. This keeps map scenes clean but requires one wrapper per map.

**Option C: Editor run configuration**

Always run the project from the main scene (F5, not F6). Use debug keybinds (F1/F2/etc.)
in MainGame.gd to warp to specific maps during development.

## Map Scene Node Contract

Every map scene loaded by the root controller MUST contain these nodes for the
integration to work:

### Required: WarpPoints container

```
MapRoot (Node2D)
└── WarpPoints (Node2D)
    ├── warp_to_[destination]_[direction] (Area2D)
    │   ├── CollisionShape2D
    │   └── (optional) ColorRect for debug visibility
    └── ... more warp Area2Ds
```

**Contract details for each warp Area2D:**

| Property | Required | Value | Consumed by |
|----------|----------|-------|-------------|
| `collision_layer` | YES | Must match Player.WarpDetector.collision_mask | Player.gd `_on_warp_area_entered` |
| `collision_mask` | Recommended | 0 (warps don't detect anything) | — |
| `metadata/destination_scene` | YES | Full `res://` path to target scene | Player.gd reads this, emits via signal |
| `metadata/destination_warp_id` | YES | Name of the WarpPoints child in target scene | MainGame.gd `_find_warp_position` |
| `metadata/transition_type` | Optional | `horizontal_slide`, `vertical_slide`, `door_enter`, `door_exit` | Transition system |
| Child CollisionShape2D | YES | Appropriately sized | Godot physics |

**Critical:** The `destination_warp_id` metadata must exactly match the `name` property
of a child node under `WarpPoints` in the destination scene. Case-sensitive.

### Required: EncounterZones container (for routes/wilderness)

```
MapRoot (Node2D)
└── EncounterZones (Node2D)
    ├── EncounterZone_[name] (Area2D)
    │   ├── CollisionShape2D
    │   └── (optional) ColorRect for debug visibility
    └── ... more encounter Area2Ds
```

| Property | Required | Value | Consumed by |
|----------|----------|-------|-------------|
| `collision_layer` | YES | Must match Player.EncounterDetector.collision_mask | Player.gd `_on_encounter_area_entered` |
| `collision_mask` | Recommended | 0 | — |
| `metadata/zone_id` | YES | Key into encounter table data | EncounterManager.try_encounter() |
| `metadata/sub_zone` | Optional | For encounter rate variation | EncounterManager |

### Required: Map root metadata

The root Node2D of every map should carry metadata consumed by systems:

| Key | Example | Consumed by |
|-----|---------|-------------|
| `metadata/zone_id` | `"ashen_glacier"` | EHI system, EncounterManager |
| `metadata/tile_size` | `Vector2i(16, 16)` | Debug tools, pathfinding |
| `metadata/map_dimensions_px` | `Vector2i(640, 400)` | Camera bounds, spawn fallback |

### Optional: NPCSpawnPoints container

```
MapRoot (Node2D)
└── NPCSpawnPoints (Node2D)
    ├── [npc_id] (Area2D or Node2D)
    │   ├── Sprite2D
    │   └── CollisionShape2D (if Area2D)
    └── ...
```

NPC nodes vary between `Node2D` (position-only spawn marker) and `Area2D`
(interactive NPC with collision). Be consistent within a project.

### Optional: ZoneOverlay

Visual overlay driven by EHI or other world-state systems:

```
MapRoot (Node2D)
└── ZoneOverlay (Node2D)
    ├── script: zone_overlay.gd
    └── OverlayCanvas (CanvasLayer)
        └── DistortionRect (ColorRect)
```

## Interior Scene Contract

Interior scenes (buildings, caves, etc.) follow the same contract as map scenes
but typically:

- Have no EncounterZones
- Have smaller map dimensions
- Have a single exit warp back to the exterior
- Need the exit warp's `destination_warp_id` to match the door warp on the exterior map

## Warp Reciprocity Contract

Every warp connection is bidirectional. If Scene A has:

```
warp_to_B_east:
  destination_scene = "res://maps/scene_b.tscn"
  destination_warp_id = "warp_to_A_west"
```

Then Scene B MUST have:

```
WarpPoints/warp_to_A_west  ← node exists (player lands here)
```

And Scene B SHOULD have a corresponding warp back:

```
warp_to_A_west:
  destination_scene = "res://maps/scene_a.tscn"
  destination_warp_id = "warp_to_B_east"
```

The audit script checks for both the node existence and the reciprocal warp.

## Validation Requirements for Map-Touching Work

Any work item that touches map scenes (`.tscn` files under `maps/`) MUST run
the medium-risk quality profile (or stricter) before marking done:

```bash
# Required for map-touching items (Gates 0-4, includes scene-audit)
python scripts/dev.py quality-strict --risk medium

# Explicit harness-only scene-audit run (use for targeted triage)
python scripts/dev.py harness scene-audit .

# JSON output for structured evidence capture
python scripts/dev.py harness scene-audit . --json
```

Gate 4 (`runtime-behavior`, `scene-audit`) must be green — zero errors — before
any map-touching item can be moved to `done`. Warnings and info items should be
reviewed and either resolved or explicitly noted in the execution log.

**Evidence snippet pattern for item/PR logs:**

```
- `python scripts/dev.py quality-strict --risk medium --emit-evidence`
  [Gate 4 runtime-behavior] `scene-audit` -> pass (`scene audit passed`)
  OR
  [Gate 4 runtime-behavior] `scene-audit` -> fail (`RESULTS: N errors, N warnings, N info`)
```

See `improvements/harness/templates/PR_EVIDENCE_TEMPLATE.md` for the full
map-contract evidence block.

## Checklist for New Map Scenes

When any agent creates a new map scene, verify:

- [ ] Root Node2D has zone metadata (`zone_id`, `tile_size`, `map_dimensions_px`)
- [ ] `WarpPoints` container exists with at least one warp
- [ ] Every warp Area2D has `collision_layer` set explicitly (not defaulting to 1)
- [ ] Every warp Area2D has `destination_scene` and `destination_warp_id` metadata
- [ ] Every `destination_scene` path points to a file that exists
- [ ] Every `destination_warp_id` matches a node name in the target scene's WarpPoints
- [ ] `EncounterZones` container exists (even if empty for towns)
- [ ] Encounter Area2Ds have `collision_layer` matching the player's encounter mask
- [ ] Encounter Area2Ds have `zone_id` metadata
- [ ] The scene can be loaded by the root controller without errors
- [ ] NPC Area2Ds have appropriate collision_layer (not conflicting with warps/encounters)
