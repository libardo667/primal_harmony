---
name: write-narrative-scene
description: >
  Use this skill when implementing any scripted story beat, cutscene, or narrative
  sequence in Primal Harmony — including the Phase One breakfast/Pacifidlog scene,
  Phase Two levee and Dewford sequences, Phase Three opening, the Team Obsidian
  reveal, any of the three resolution paths, or the epilogue. Also use for any
  triggered environmental story moment (first TOZ encounter, starter discovery,
  cleanse events). Always read docs/narrative_bible_v0_1.md before beginning.
---

# Skill: write-narrative-scene

**Primary agent:** The Weaver
**Supporting agents:** The Shaper (scene must exist), The Mechanic (cutscene controller signal)

---

## Before You Begin

1. Read `docs/narrative_bible_v0_1.md` — locate the specific beat you are implementing
2. Read `docs/characters_v0_1.md` — load voice for every character in the scene
3. Check comms log for cutscene controller signal: `python3 agents/scripts/comms.py agents/COMMS_LOG.csv search "cutscene"`
4. Confirm The Shaper has delivered the map scene this beat occurs in

---

## Scene Architecture

Every narrative scene in Primal Harmony uses the same structure:

```
[MapScene].tscn
└── NarrativeEvents/           ← Node added by The Weaver
    └── [SceneName]Event.gd    ← Attached script
```

The `NarrativeEvents` node is a plain `Node` added as a child of the map root. The Weaver owns it entirely.

### Event Script Template

```gdscript
extends Node

# [SceneName]Event.gd
# Narrative beat: [brief description]
# Phase: [One / Two / Three]
# Trigger: [how this fires — autostart, flag check, area_entered, signal]

@onready var dialogue_manager = get_node("/root/DialogueManager")
@onready var cutscene_controller = get_node("/root/CutsceneController")

func _ready() -> void:
    # Check prerequisites before firing
    if not _prerequisites_met():
        return
    _begin()

func _prerequisites_met() -> bool:
    # Replace with actual flag checks
    return not QuestFlags.get_flag("THIS_SCENE_COMPLETE")

func _begin() -> void:
    # Emit signal to disable player input
    cutscene_controller.begin_cutscene()
    await _run_sequence()
    cutscene_controller.end_cutscene()
    QuestFlags.set_flag("THIS_SCENE_COMPLETE")

func _run_sequence() -> void:
    # Implement scene beats here
    pass
```

---

## Implementing Dialogue

Use the DialogueManager autoload. Never hardcode dialogue strings in scene files.

```gdscript
# Single line
await dialogue_manager.show_line("character_id", "Dialogue text here.")

# Line with portrait expression
await dialogue_manager.show_line("grandfather", "When something gets lost, what do you do?", "neutral")

# Player choice (returns selected index)
var choice: int = await dialogue_manager.show_choice([
    "Help it find its way back.",
    "I don't know."
])
```

**Character IDs** (must match DialogueManager's portrait registry):
- `grandfather`, `grandmother`, `parent`, `nurse_joy`
- `maxie`, `archie`
- `yemi` (Coordinator Yemi, Slateport)
- `obsidian_grunt` (pre-reveal), `obsidian_maxie`, `obsidian_archie` (post-reveal)
- `npc_generic` (unnamed NPCs)

---

## Camera Control

```gdscript
# Pan to a position (smooth)
cutscene_controller.pan_camera(Vector2(x, y), duration_seconds)
await cutscene_controller.camera_arrived

# Focus on a specific node
cutscene_controller.focus_node(node_reference, duration_seconds)
await cutscene_controller.camera_arrived

# Return to player
cutscene_controller.return_to_player(duration_seconds)
await cutscene_controller.camera_arrived
```

---

## Text Cards (Phase Transitions)

Phase transition cards ("Six years later.") use a dedicated system:

```gdscript
await cutscene_controller.show_text_card("Six years later.", fade_duration=2.0)
```

These are full-screen fades with centered text. Do not use dialogue_manager for these.

---

## Scene-Specific Implementation Notes

### Phase One — The Holdfast Breakfast (Pacifidlog Scene)

**Trigger:** Autostart on map load. Fires only if `PHASE1_PACIFIDLOG_SEEN` is not set.

**Beat sequence:**
1. Player seated at table. Grandfather reading, grandmother at tablet. TV ambient audio on.
2. TV audio shifts tone — use `AudioManager.play_sfx("tv_broadcast_shift")`.
3. Broadcast line plays as dialogue: `npc_generic` with ID `tv_anchor`.
4. Grandfather puts down tea. Pause (0.8s). Grandmother stops typing.
5. Grandfather's line. Pause (1.2s). He stands.
6. Line: move toward door. Say the redirect to morning routine.
7. Set flag `PHASE1_PACIFIDLOG_SEEN`. Cutscene ends. Player regains control.

**Tone note:** The pause after the broadcast is the scene. Do not rush it. Do not add music. The silence is the emotional beat.

### Phase One — The Triage Catch Tutorial

**Trigger:** Father leads player to supply shed. Area2D triggers tutorial sequence.

**Key requirement:** The Pokéball throw mechanic here must use `CatchManager.triage_catch()`, not the standard `CatchManager.battle_catch()`. The Sentret's state is `frightened`, not `weakened_by_battle`. This distinction must be preserved — it is the game's first philosophical statement.

### Phase Two — Levee Sandbag Sequence

**Trigger:** Player arrives at Slateport Harbor volunteer area.

**Beat sequence:**
1. Coordinator Yemi check-in dialogue.
2. Brief work minigame (rhythm-based, handled by The Mechanic — check comms log for signal).
3. Mid-work conversation with Levee Boy (unnamed peer NPC — flag name TBD).
4. Work continues. Scene closes naturally — no dramatic ending.

**Tone note:** This scene should feel mundane and purposeful simultaneously. The Levee Boy's line about his Pacifidlog cousin lands because the scene doesn't frame it as important. Let it be a casual observation that the player carries forward.

### Team Obsidian Reveal

**Trigger:** Story flag gate — fires at designated story beat location (TBD by The Elder).

**Pre-conditions:** Both `AQUA_ALLIANCE_OFFERED` and `MAGMA_ALLIANCE_OFFERED` must be set.

**Beat sequence:**
1. Both Maxie and Archie present in same frame — establish visual that they are together.
2. Maxie speaks first. Archie follows. No interruption.
3. Player receives choice — this does not affect the reveal itself, only faction weighting.
4. Set flag `OBSIDIAN_REVEALED`.
5. EHI system reads current global EHI at this moment — this determines resolution path. **Do not display this to the player.**

**Critical:** The reveal must make clear that Team Obsidian did not cause the crisis. They built a response capacity *after* disasters began. This distinction must be unambiguous. See narrative bible for exact framing.

### The Epilogue

**Trigger:** Fires after resolution sequence completes, regardless of path.

**Beat sequence:**
1. Fade in: The Holdfast back steps, evening light.
2. Grandfather already present, tea in hand.
3. Player sits. No dialogue immediately. Hold 2 seconds.
4. Grandfather's first line. Player response (silent — no choice, just acknowledgment beat).
5. Wingull passes. Sky ambient.
6. Final line: `"You did good."`
7. Fade to black. Credits.

**This scene must be identical across all three resolution paths.** The difference between resolutions lives in what the player carries into it — their Rehabilitation Log, their starter's form, the world's state. The grandfather says the same thing regardless. The player's version of "good" is different each time.

---

## Completion Log Template

```bash
python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Weaver" "Narrative scene complete — [SceneName]. File: [path]. Flags set: [FLAG_IDS]. → The Elder: ready for integration audit."
```

---

## Common Mistakes

- **Writing grief too loudly.** This game earns its emotion through restraint. A grandfather turning off a TV and going to check on Pokémon is more devastating than a monologue. Trust the silence.
- **Explaining the philosophy.** The game shows the Rehabilitator philosophy through mechanics, not speeches. NPCs do not explain that "catching is triage." They just do it.
- **Rushing the Obsidian reveal.** Give Maxie and Archie the full scene. They have earned it. The player needs time with both of them before the final act.
- **Moralizing about corrupted starters.** The game does not judge the player for keeping Forgechic. No NPC should either. If writing a scene where a player's corrupted starter is present, the NPC response should be curiosity and recognition, not concern.
