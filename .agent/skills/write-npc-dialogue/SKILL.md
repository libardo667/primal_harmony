---
name: write-npc-dialogue
description: >
  Use this skill when writing dialogue for any NPC in Primal Harmony — including
  named characters (grandparents, Maxie, Archie, Nurse Joy, Coordinator Yemi),
  generic town residents, Gym Leaders as ecological stewards, Team Obsidian members,
  or any NPC whose lines should reflect the current EHI state of their location.
  Also use for EHI-reactive dialogue (lines that change as zones restore), Pokémon
  Center relocation terminal scripts, and faction reputation-gated dialogue branches.
  Always read docs/world_state_v0_1.md for the NPC's location context first.
---

# Skill: write-npc-dialogue

**Primary agent:** The Weaver

---

## Before You Begin

1. Check `docs/world_state_v0_1.md` for the NPC's location — know what that place has been through
2. Check `docs/characters_v0_1.md` if the NPC is named
3. Check `docs/narrative_bible_v0_1.md` for any story beats this NPC participates in
4. Check comms log for current EHI signal interface: `python3 agents/scripts/comms.py agents/COMMS_LOG.csv search "ehi_changed"`

---

## NPC Script Structure

Every interactive NPC uses a standard structure:

```gdscript
extends CharacterBody2D
class_name NPC[Name]

# [Name] — [Location] — [Role description]
# EHI-reactive: [yes/no]
# Faction-gated: [none / aqua / magma / both]

@export var npc_id: String = "[unique_id]"
@export var location_zone_id: String = "[zone_id_or_none]"

@onready var dialogue_manager = get_node("/root/DialogueManager")
@onready var ehi_system = get_node("/root/EHISystem")

func interact() -> void:
    var dialogue_key: String = _get_dialogue_key()
    await dialogue_manager.show_dialogue(npc_id, dialogue_key)

func _get_dialogue_key() -> String:
    # Priority: story flags > faction rep > EHI state > default
    if QuestFlags.get_flag("OBSIDIAN_REVEALED"):
        return _post_reveal_dialogue()
    if location_zone_id != "":
        return _ehi_dialogue()
    return "default"

func _ehi_dialogue() -> String:
    var ehi: float = ehi_system.get_local_ehi(location_zone_id)
    if ehi < 0.33:
        return "infested"
    elif ehi < 0.67:
        return "partial"
    else:
        return "restored"
```

---

## Writing EHI-Reactive Dialogue

Every NPC in or adjacent to a Type Overload Zone needs three dialogue states. Write all three before marking the NPC complete.

### Template: Town Resident Near Active Zone

```
[infested]
"I haven't slept properly in weeks. You can hear it from here, you know.
 Something wrong in the air."

[partial]
"It's... different today. Still strange, but — I don't know.
 Something feels like it's trying to come back."

[restored]
"I almost forgot what it smelled like before. You don't realize
 what normal is until it comes back."
```

### Template: Ranger or Official

```
[infested]
"Zone's at critical. We're recommending civilians stay west of the
 marker until further notice. You're Rehabilitation Corps? Good.
 We need the help."

[partial]
"Numbers are improving. I've started to see a few native species
 pushing back into the edge territory. It's slow, but it's real."

[restored]
"Cleared. Zone's officially restored as of this morning. My team
 is standing down to monitoring status. Whatever you did out there —
 it worked."
```

---

## Writing Named Characters

### Grandmother — at The Holdfast

Her dialogue should feel like someone who has been paying attention for fifty years. She does not lecture. She observes.

```
[on the Rehabilitation Log, Phase Two]
"Your grandfather started this when we opened. He said someday it
 would matter to have the record. I think someday is now."

[on the player leaving for Phase Three work]
"You know where home is. That's enough."

[on a corrupted starter the player has kept]
"I've seen all kinds come through here. Most of them find their way.
 Some of them find a new way. Both count."
```

### Grandfather — at The Holdfast

Short sentences. Trusts silence. Never explains, demonstrates.

```
[Phase One, morning routine]
"When something gets lost, what do you do?
 ...You help it find its way back. Right."

[Phase Three check-in, mid-game]
"You sound tired."
[pause]
"That's not a criticism."

[Epilogue — ONLY EVER THIS, regardless of resolution path]
"You know, when your grandmother and I started this place, we thought
 we'd mostly be dealing with Pokémon that got hit by cyclists."
"Funny how things go."
[pause — Wingull passes]
"You did good."
```

### Nurse Joy — Relocation Terminal Introduction

This is a key tutorial beat. She explains the release mechanic without condescension and without over-explaining the ecological philosophy. She understands the mechanic intuitively, not theoretically.

```
[first time player approaches terminal]
"Oh, you haven't used one of these before? That's alright.
 It's pretty new — we installed it about six months ago.

 The idea is simple: you put the right thing in the right place,
 and the place starts to remember what it was.

 I won't pretend I understand all the science. But that part
 makes sense to me.

 Which zone are you working on?"
```

### Maxie — Post-Reveal

Contained. Precise. Takes the player seriously. Does not soften for comfort.

```
[reveal scene, primary]
"I understand this is not what you expected.

 We did not cause this. I want to be clear about that — not
 to protect my reputation, which is beyond protection, but
 because the distinction matters for what comes next.

 We built a response. Because we owed Hoenn one.
 That is the most we can offer. I am aware it is not enough.
 I bring it anyway."

[if player's EHI is high — Maxie notices]
"You've been thorough. I notice. It changes the math."

[if player's EHI is low — Maxie does not judge]
"The situation is what it is. We work with what we have."
```

### Archie — Post-Reveal

Weathered. More present. Capable of humor, though it costs him.

```
[reveal scene, follow-up to Maxie]
"What he said. But with more — I don't know.
 I've been going back to the Pacifidlog dive site.
 Three times now. I'm not sure what I'm looking for.

 Maybe just to look at it."
[pause]
"Maxie keeps telling me the slow way is the one that works,
 and the one time I didn't listen to him we both ended up here.

 So."

[if player has a water-type starter — Archie's register warms slightly]
"Good Pokémon. Water's honest. Doesn't pretend to be anything
 it isn't."
```

---

## Team Obsidian — Pre-Reveal NPCs

Before the reveal, Team Obsidian members have no faction colors or insignia the player can identify. They appear at TOZ borders as generic watchers.

**Tone:** Not hostile. Observational. Slightly cryptic without being theatrical about it.

```
[first encounter, TOZ border]
"You're Rehabilitation Corps.
 [beat]
 We've been monitoring this zone for eleven days.
 The surge pattern is consistent with what we saw at Fortree."
[turns back to the zone, not hostile, just done talking]

[second encounter, different zone]
"You again.
 [beat]
 Good rate of progress."
[no further engagement]
```

After the reveal, these same NPCs have post-reveal dialogue that recontextualizes the encounters:
```
[post-reveal, same NPCs]
"I wondered when you'd put it together.
 For what it's worth — we were genuinely glad you were out there.
 Made the math easier."
```

---

## Gym Leaders as Ecological Stewards

Gym Leaders in Primal Harmony are stewards first, combat specialists second. Their pre-badge dialogue should reflect the state of their associated zone. Post-restoration, they shift from crisis management to genuine partnership.

**Template:**
```
[pre-restoration, Gym Leader]
"I've been here for [X] years. I know this place.
 What's happening to it — this isn't weather. This isn't a bad season.
 Something is wrong in a way I don't have words for yet.

 I'm not sure a battle is what you came for. But I'm not going
 anywhere until it's right again. So if you're staying — welcome."

[post-restoration, Gym Leader]
"[Location-specific observation about what's returned]
 [Something they noticed coming back — a sound, a smell, a species]
 [Genuine, not effusive — this person doesn't over-express]"
```

---

## Completion Log Template

```bash
python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The Weaver" "NPC dialogue complete — [npc_id] at [location]. EHI states: [infested/partial/restored written: yes/no]. Faction-gated branches: [none/aqua/magma/both]. Flags checked/registered: [FLAG_IDS]."
```

---

## Common Mistakes

- **Making Maxie warm.** He has not softened. He has clarified. There is a difference.
- **Making Archie comic relief.** He carries real grief about Pacifidlog. He can be dry but he is not light.
- **Writing generic hope for restored zones.** Make it specific — a sound, a species, a smell. Generic relief is less moving than specific detail.
- **Forgetting the third EHI state.** Always write all three. Partial is the hardest and most important — that's where most of the game lives.
- **Having NPCs explain the Rehabilitator philosophy.** Show, don't tell. NPCs react to what the player has done. They do not describe the game's themes.
