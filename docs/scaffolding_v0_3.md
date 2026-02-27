# Pokémon Emerald: Primal Harmony
## Game Design Scaffolding Document — v0.3
### Incorporating Narrative, Character, and World State Decisions

*Supersedes v0.2. Changes from v0.2 are marked with [NEW] or [UPDATED].*

---

# Vision & Soul

Primal Harmony is set in a reimagined future Hoenn that has been ecologically destabilized by an influx of Pokémon from every region across the world. The native biomes are in crisis — native species displaced, environments warped, the delicate balance between land and sea thrown into chaos.

The player's journey is one of restoration, not conquest. Banding together with the unlikely alliance of Team Aqua, Team Magma, Kyogre, Groudon, and ultimately Rayquaza, the goal is to heal Hoenn — area by area, biome by biome — and forge a new ecological harmony from the wreckage of the old one.

> **Core Theme:** *Balance is not a destination. It is a relationship that must be earned.*

[NEW] The player is not a stranger arriving in a broken world. They are a member of a family that has been responding to this slow emergency their entire life. The game earns its stakes through lived history, not exposition.

---

# [NEW] Narrative Structure — The Three Phases

The game is divided into three distinct life phases for the player character. The transition between phases is marked by text cards. Each phase has distinct mechanical scope and emotional register.

## Phase One — Roots (~Age 8)
The player is a child at The Holdfast, the family's Pokémon rehabilitation waystation on Route 117. Gameplay is tutorial-scale and guided by the player's father. Core mechanics introduced: the Triage Catch (catching already-weakened Pokémon gently, not through battle), and the PC Release system (routing recovered Pokémon to appropriate biomes).

**Opening beat:** The player wakes up, comes downstairs to breakfast, watches a news broadcast reporting the destruction of Pacifidlog Town. The grandfather turns off the TV. Life continues. The player helps with morning Pokémon care.

**Emotional register:** Safe world with visible cracks. The adults know what to do. The player is absorbing.

## Phase Two — Pressure (~Age 14)
The player participates in coastal volunteer infrastructure work in the Slateport region. Gameplay is town-scale: a sandbag crew sequence, a supply run to New Dewford, a visit to the relocated community. The phase ends at The Holdfast with the grandmother showing the player the Rehabilitation Log and suggesting they pursue certification.

**Emotional register:** The emergency is the background of daily life. The player is contributing but not yet leading.

## Phase Three — Threshold (~Age 20)
The player is a certified Rehabilitator activated for the Kyogre/Groudon awakening crisis. Full game scope begins here. Type Overload Zones appear. The full world is accessible. The EHI system is active.

**Emotional register:** The player is now the one who makes decisions that matter.

---

# [NEW] Player Character Origin

**[UPDATED from v0.2 — Player Role section]**

The player character is the grandchild of the founders of The Holdfast, a Pokémon rehabilitation waystation on Route 117. Their role as a Rehabilitator is not a profession they chose — it is a lineage they were born into and grew into over two decades.

This origin does three things mechanically and narratively:
1. It makes the first Pokéball throw not an act of capture but an act of care — establishing the philosophy of the whole game before any tutorial text explains it.
2. It gives the EHI system personal stakes — restoring Hoenn is not an assignment, it is what this family does.
3. It provides a home base that functions as emotional anchor throughout Phase Three.

**The Holdfast** is the player's home base. It is on Route 117. It has been operational for over two decades. It is one of the ecologically healthiest locations in Hoenn as a result of sustained care. Returning to it should feel different from traversing a TOZ.

---

# Part I — Mechanics Kept & Ported Directly

*(Unchanged from v0.2)*

## Core Battle Engine
Turn structure, priority system, and speed resolution; Type matchup chart (Gen 9 updated version); Stat calculation formulas; PP system and move depletion; Status conditions; Critical hit mechanics; STAB, held item modifiers, ability triggers.

## Progression Systems
EV and IV system; Experience gain and leveling curves; Evolution mechanics; Egg system and breeding; Friendship/happiness tracking.

## Inventory & Interface
Item system; PC storage system (expanded capacity); Standard Pokédex interface (modified skin); Bag organization.

## World Infrastructure
Day/night cycle; Seasonal weather baseline; Trainer battle system.

---

# Part II — Mechanics Modified & Ported

## [UPDATED] Pokédex → Ecological Survey Tool
The Pokédex is reframed as a field research instrument. Functionally identical, but with expanded context.

- Non-native species flagged with an Invasive Species marker
- Corrupted Regional Variants receive unique dex entries describing their mutation history and, where applicable, their path toward or away from restoration
- Survey completion tracked per biome
- **[NEW]** First encounters with Corrupted Variants generate a "First Record" entry that populates with data as the player interacts with that variant across the game. The Pokédex itself is a restoration arc — incomplete entries fill in as zones recover.

## [UPDATED] Wild Encounter System → Ecological Feedback Loop
Encounter tables are dynamic, tied to local EHI.

- Infested zones: heavily weighted toward non-native and Corrupted Variant spawns
- Partially restored zones: mixed, transitional species appearing
- Restored zones: native Hoenn species dominant
- **[NEW]** Route 117 / The Holdfast area maintains above-baseline native encounter rates as a permanent baseline — the player always has a reference point for what "restored" looks like.

## [UPDATED] Team Aqua & Team Magma → Team Obsidian Reveal
**[MAJOR UPDATE from v0.2]**

Both organizations are initially encountered as Team Obsidian — a clandestine coalition operating in the field with no clear affiliation. The player encounters them at TOZ borders; they observe, document, occasionally interfere.

The reveal approximately one-third into Phase Three: Team Obsidian was built by Maxie and Archie over the last decade. Not to orchestrate the crisis — to be ready for it. They knew a second awakening was eventually likely. They knew no government body would trust them to respond. They built something unofficial.

**Key design principle:** Team Obsidian did not cause the crisis. They are atonement infrastructure. This distinction must be unambiguous in the reveal dialogue.

**Faction integration post-reveal:**
- Dual reputation meter still applies (Aqua-aligned vs. Magma-aligned within Obsidian)
- Team Obsidian's network becomes a resource: field contacts, equipment, the Mossdeep and Lilycove operational sites
- Maxie and Archie are available as recurring NPCs with evolving dialogue that tracks EHI progress

## [UPDATED] Weather System → Regional Climate States
*(Functionally unchanged from v0.2 — see World State Document for geographic specifics)*

## [UPDATED] Badge System → Zone Restoration
**[MAJOR UPDATE from v0.2 — No gym badges]**

There are no gym badges in Primal Harmony. Gym Leaders exist as ecological stewards and combat specialists, but the player's progression metric is Zone restoration rather than badge acquisition.

Each Gym Leader has jurisdiction over a biome associated with a TOZ. Engaging a Gym Leader is part of the process of quelling their associated zone — but it is not a gating requirement. Players can approach zones in non-linear order subject to EHI thresholds and story locks.

**Gym Leaders as characters:** They are not obstacles. They are colleagues — sometimes skeptical ones, sometimes ahead of the player, sometimes behind. The post-quell scene with each Gym Leader is a narrative beat about what restoration actually looks like for a specific place and person.

---

# Part III — Brand New Features

## Ecological Harmony Index (EHI)
*(Functionally unchanged from v0.2)*

The EHI is the central feedback system. Global EHI is an aggregate; local EHI drives local conditions. Changes should feel environmental before they feel numerical — birdsong returning, water clearing, grass shifting color.

**[NEW] EHI and Resolution Gating:**
The final act resolution (see Narrative Bible) is determined by EHI at the point of the Team Obsidian reveal. High EHI enables Resolution A (Rayquaza descends without capture). Mid EHI enables Resolution B (coordinated mass release). Low EHI results in Resolution C (the hard way, Obsidian capture proceeds).

This determination should not be announced to the player. It should emerge from the choices they have made.

## Type Overload Zones
*(Functionally unchanged from v0.2 — see Field Atlas for zone-specific details)*

**[NEW] Zone Introduction Pacing:**
Zones do not all appear at the start of Phase Three. They emerge gradually as the Kyogre/Groudon awakening destabilizes the region. The player encounters their first zone (The Ashen Glacier) during their first field assignment. Additional zones appear as the story progresses, with a mechanical clock — zones pulse and expand if unaddressed.

The appearance of a new zone is a narrative event, not just a map update. NPC dialogue, Ranger alerts, and environmental cues precede each zone's appearance by a beat.

## [NEW] The Rehabilitation Log

The Rehabilitation Log is both a game system and a narrative device. It tracks:
- Every Pokémon the player has caught and released
- Origin zone and destination zone for each release
- Date of release (in-game calendar)
- Whether a released Pokémon was a Corrupted Variant, and if so, its healing path

**Mechanical function:** The Log drives milestone rewards — EHI boosts, faction rep, items, Rayquaza Bond progress at key release counts.

**Narrative function:** The Log is a record of the player's actual impact. In Resolution C (low EHI), the Log is the post-credits emotional gut-punch — the player sees what they did and did not reach. In Resolution A, the Log is the quiet proof that it was enough.

The Log's design should feel like the physical ledger the grandmother keeps at The Holdfast. It is not a trophy screen. It is a case file.

## Catch, Rehabilitate & Release System
*(Functionally unchanged from v0.2)*

**[NEW] Phase One Mechanical Framing:**
The player's first experience of the catch mechanic is in Phase One, guided by their father, catching frightened Pokémon that have escaped their enclosures during seismic activity. The Pokéball is thrown at a shaking Sentret under a supply shed. This is not a battle. This is a rescue.

This framing should persist in the player's muscle memory for the entire game. The Triage Catch is taught before the competitive catch. The philosophy precedes the mechanics.

## [UPDATED] Corrupted Starter System
*(Typing and evolution paths unchanged from v0.2)*

**[NEW] Starter Discovery Context:**

Each starter is found in the field during an early Phase Three assignment — not presented in a lab. Their locations are:

- **Treecko (Bug/Rock):** Buried beneath a rockslide on Route 116, colonized by Johto Bug-type invasives. The player's ecological survey tool flags an anomaly. The starter is found in a crevice, unmoving, its green entirely replaced by grey-brown chitin.

- **Torchic (Fighting/Steel):** In an industrial drainage corridor near Rustboro. Found against a wall, its warmth gone, its feathers replaced by interlocking metallic plates. It does not flee. It watches the player with flat, assessing eyes.

- **Mudkip (Ghost/Fairy):** At the edge of the Dread Shore's influence near Route 122. Partially incorporeal — the player's hand passes through it on the first attempt to reach it. Its fin-crest emits soft spectral light. It answers to its name. It is not certain from where.

**[NEW] Corrupted Starter — Moral Framing:**

The game must never penalize a player for keeping a fully corrupted starter. The Team Obsidian reveal provides the affirmation for this path: Forgechic, Carapecko, Wraithdew are not failures of healing. They are evidence that Hoenn is finding new shapes on its own terms. The corrupted path player hears a version of the Obsidian philosophy that specifically names what they have: something new that deserves to exist.

The cleansing moments (for players who choose them) are narrative beats — a short environmental response, a change in ambient sound, a line in the Pokédex entry that shifts. They are not menu actions.

## Dynamic Hoenn Overworld Map
*(Functionally unchanged from v0.2)*

**[NEW] Pacifidlog Ghost Marker:**
The world map includes a ghost indicator at Pacifidlog's former location — a greyed icon beneath a wave symbol. It is not interactable from the map. Players who Dive in Route 131/132/133 can reach the site.

---

# [NEW] Part IV — Phase Transition Design

## Phase One → Phase Two Transition
After the morning routine at The Holdfast following the Pacifidlog news, the game saves and displays a text card: *Six years later.* No additional ceremony. The transition is as quiet as the news broadcast was abrupt.

## Phase Two → Phase Three Transition
After the grandmother shows the player the Rehabilitation Log and suggests certification, the game saves. Text card: *Six years later.* The player wakes up in their own space — not The Holdfast bedroom, but somewhere they've made their own. They receive the activation call on their PokeNav equivalent. Phase Three begins.

## Design Note — Phase Transition Gameplay Scope
Phase One and Phase Two are not optional prologues. They are not skippable. They are short (approximately 20-40 minutes each) but mandatory, because the emotional stakes of Phase Three are entirely dependent on having experienced them. A player who skips them is playing a different, lesser game.

---

# Appendix — [UPDATED] Open Design Questions

Questions marked [RESOLVED] have been addressed in this document or supporting documents. Remaining questions are flagged for further development.

**[RESOLVED]** Player origin: grandchild of The Holdfast founders; certified Rehabilitator
**[RESOLVED]** Gym badges: removed; replaced by Zone restoration progression
**[RESOLVED]** Team Aqua/Magma: become Team Obsidian; reveal approximately one-third into Phase Three
**[RESOLVED]** Rayquaza arc: salvation/rescue rather than companionship; three resolution paths based on EHI
**[RESOLVED]** Corrupted starter moral framing: honored without penalty; Team Obsidian reveal provides specific affirmation
**[RESOLVED]** Pacifidlog: gone, not rebuilt, ghost marker on map, Dive-accessible site

**[OPEN]** Counter-release reward balance: What incentive competes with keeping a useful team member?
**[OPEN]** Rehabilitation Log persistence: Does it persist post-game as a completionist objective?
**[OPEN]** Corrupted Variant naming convention: Unique species names or formal variant designations?
**[OPEN]** Variant healing reversibility: Are any Variants too far gone? What does that mean narratively?
**[OPEN]** Faction tension ceiling: Can both Aqua and Magma rep be fully maxed, or structural conflict?
**[OPEN]** Post-game EHI: Does a true 100% state exist? What does fully restored Hoenn look and feel like?
**[OPEN]** Stat spreads: All 18 corrupted starter forms need full BST and stat distribution
**[OPEN]** Learnsets: Corrupted, hybrid, and restored paths need full learnset documents
**[OPEN]** Corrupted Variant Design Bible: 30 seeded variants documented; full native Hoenn roster needed
**[OPEN]** Player character names: River/Sable are placeholders; final names need confirmation
**[OPEN]** Key NPC names: The boy from the levee, the grandparents — all TBD
**[OPEN]** Hoenn Ecological Recovery Initiative: Formal name TBD; organization structure TBD

---

*— End of Scaffolding v0.3 —*
