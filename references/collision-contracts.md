# Collision Layer & Mask Contracts

## The Core Principle

Godot's collision system uses **layers** (what I am) and **masks** (what I detect).
Two physics objects interact when **A's mask overlaps B's layer, or B's mask overlaps A's layer**.

For Area2D signal detection (`area_entered`, `body_entered`), the overlap check is:
**A.collision_mask & B.collision_layer != 0** (A detects B)

This means both sides of the contract must agree. If the detector sets mask bit 2,
the target MUST set layer bit 2. A default `collision_layer = 1` (the Godot default
when no value is specified in .tscn) will be invisible to a mask that expects bit 2.

## Standard Layer Assignments

These are the layers observed in typical Godot 2D projects. Adapt to the project's
actual conventions — check `project.godot` and the Player scene for ground truth.

| Bit | Layer Value | Purpose | Set by | Detected by |
|-----|-------------|---------|--------|-------------|
| 0 | 1 | World collision (walls, static bodies) | TileMap physics, StaticBody2D | Player.CharacterBody2D (mask bit 0) |
| 1 | 2 | Warp points | Warp Area2Ds | Player.WarpDetector (mask bit 1) |
| 2 | 4 | Encounter zones | Encounter Area2Ds | Player.EncounterDetector (mask bit 2) |
| 3 | 8 | Encounter zones (alt) | Some projects use bit 3 | Check which the project actually uses |
| 7 | 128 | NPC interaction | NPC Area2Ds | Player interact detector |
| 8 | 256 | NPC spawn trigger | NPC Area2Ds | body_entered from player CharacterBody2D |

**WARNING:** `collision_layer = 4` means bit 2, but `collision_layer = 8` means bit 3.
These are NOT the same. This is one of the most common sources of confusion because
the .tscn file stores the bitmask *value*, not the bit *index*.

Bit index to value mapping:
- Bit 0 = value 1
- Bit 1 = value 2
- Bit 2 = value 4
- Bit 3 = value 8
- Bit 4 = value 16
- Bit 7 = 128
- Bit 8 = 256

## Diagnostic Checklist

### 1. Find the Player's detectors

Open `Player.tscn` and list every Area2D child node. For each one, note:
- Node name (e.g., `WarpDetector`)
- `collision_layer` (usually 0 — detectors shouldn't *be* anything)
- `collision_mask` (what it listens for)

Example from a typical player:
```
WarpDetector:       collision_layer = 0, collision_mask = 2  → detects layer bit 1
EncounterDetector:  collision_layer = 0, collision_mask = 4  → detects layer bit 2
```

### 2. For each detector, find all matching targets across all scenes

Search all `.tscn` files for Area2D nodes that should be detected. Verify each one
sets the correct `collision_layer`.

```bash
# Find all warp-related Area2Ds and check their collision_layer
grep -B5 -A2 'destination_scene\|destination_warp' maps/**/*.tscn
```

### 3. Flag any Area2D with no explicit collision_layer

If a `.tscn` node definition doesn't include `collision_layer = ...`, Godot uses
the default value of 1. This is almost never what you want for warp/encounter/interact
zones. Every Area2D that participates in detection should have an explicit layer set.

```bash
# In the audit script, we check for Area2D nodes and whether they set collision_layer
# If the Area2D is a child of WarpPoints but has no collision_layer line → BUG
```

### 4. Check for layer/mask confusion

A common mistake: an agent reads the docs saying "warps use layer 2" and sets
`collision_layer = 2` (correct! bit 1, value 2). Another agent reads "encounters
use layer 4" meaning bit 2 (value 4), but sets `collision_layer = 8` (bit 3, value 8)
because they confused the Godot editor's 1-indexed layer numbering with the bitmask
value in the .tscn format.

The .tscn format uses **bitmask values**, not 1-indexed layer numbers:
- Godot Editor "Layer 1" = .tscn `collision_layer = 1`
- Godot Editor "Layer 2" = .tscn `collision_layer = 2`
- Godot Editor "Layer 3" = .tscn `collision_layer = 4`  ← This is where confusion starts
- Godot Editor "Layer 4" = .tscn `collision_layer = 8`

### 5. Multi-layer nodes

Some nodes need to be on multiple layers. The value is a bitwise OR:
- Layers 1 and 2: `collision_layer = 3` (1 | 2)
- Layers 1 and 3: `collision_layer = 5` (1 | 4)

Same for masks. If the player should detect warps (2) AND encounters (4):
`collision_mask = 6` (2 | 4)

But in a well-structured project, each detector Area2D usually has a single mask bit,
keeping responsibilities clean.

## Common Misconfigurations

### "Default layer" trap
Every CollisionObject2D defaults to `collision_layer = 1, collision_mask = 1`.
If an agent creates an Area2D in the editor and forgets to change the layer,
it sits on layer 1. The player's body is also on layer 1. So `body_entered`
fires — but that's a false positive from world collision, not from the intended
detection layer. Meanwhile, the player's purpose-built detectors (on mask 2 or 4)
see nothing.

### "Works in one scene" trap
Agent A builds Route 113 and carefully sets `collision_layer = 2` on warps.
Agent B copies the structure for Fallarbor but uses the Godot editor's defaults
without realizing Agent A hand-edited the values. Route 113 warps work; Fallarbor
warps don't. The bug is invisible until someone walks into a Fallarbor warp.

### "Encounter layer drift"
The project starts with encounters on layer 4 (bit 2). Six months later, someone
checks the Godot editor and sees "Layer 4" checked in the inspector, which is
actually bit 3 (value 8). They "fix" old scenes to match, breaking them.
Document the bitmask convention clearly and persistently.
