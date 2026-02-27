extends Node

# ---------------------------------------------------------------------------
# DEBUG FLAG — set to false in production builds to silence keyboard shortcuts
# ---------------------------------------------------------------------------
const DEBUG := true

@onready var dialogue_manager = get_node("/root/DialogueManager")
@onready var quest_manager = get_node("/root/QuestManager")
@onready var ehi_manager = get_node("/root/EHI")

# ---------------------------------------------------------------------------
# NPC node-name → trigger function map
# ---------------------------------------------------------------------------
var _npc_triggers := {
	"devon_researcher_woods_01": trigger_researcher_woods_01,
	"bug_catcher_woods_01": trigger_bug_catcher_woods_01,
	"team_aqua_grunt_woods_01": trigger_team_aqua_grunt_woods_01,
}

# ---------------------------------------------------------------------------
# _ready — wire Area2D.body_entered signals from NPCSpawnPoints in the map.
# Convention (set by The Shaper): NPC detector Area2Ds live on collision
# layer 8 under a parent named NPCSpawnPoints.
# ---------------------------------------------------------------------------
func _ready() -> void:
	# Trigger the zone entry atmospheric event on every map load.
	# Commented out for Phase 5 verifiable movement testing:
	# trigger_zone_entry_event()
	var spawn_root := _find_npc_spawn_root()
	if spawn_root == null:
		if DEBUG:
			push_warning("[petalburg_woods_events] No NPCSpawnPoints node found. Proximity triggers inactive.")
		return

	for child in spawn_root.get_children():
		if child is Area2D and _npc_triggers.has(child.name):
			var trigger_fn: Callable = _npc_triggers[child.name]
			if not child.body_entered.is_connected(_on_npc_body_entered.bind(trigger_fn)):
				child.body_entered.connect(_on_npc_body_entered.bind(trigger_fn))
			if DEBUG:
				print("[petalburg_woods_events] Connected body_entered on: ", child.name)

# Walk up from this node to the map root, then search for NPCSpawnPoints.
func _find_npc_spawn_root() -> Node:
	var node := get_parent()
	while node != null:
		var found := node.find_child("NPCSpawnPoints", true, false)
		if found:
			return found
		node = node.get_parent()
	return null

# Called when any CharacterBody2D enters an NPC's Area2D.
func _on_npc_body_entered(body: Node2D, trigger_fn: Callable) -> void:
	if body is CharacterBody2D:
		trigger_fn.call()

# ---------------------------------------------------------------------------
# DEBUG keyboard shortcuts — only active when DEBUG = true
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not DEBUG:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				print("[Events] DEBUG KEY_1 — Researcher")
				trigger_researcher_woods_01()
			KEY_2:
				print("[Events] DEBUG KEY_2 — Bug Catcher")
				trigger_bug_catcher_woods_01()
			KEY_3:
				print("[Events] DEBUG KEY_3 — Aqua Grunt")
				trigger_team_aqua_grunt_woods_01()
			KEY_4:
				print("[Events] DEBUG KEY_4 — Zone Entry")
				trigger_zone_entry_event()

# ---------------------------------------------------------------------------
# NPC trigger functions
# ---------------------------------------------------------------------------

func trigger_researcher_woods_01() -> void:
	if quest_manager.get_flag("ZONE06_RESEARCHER_TALKED"):
		dialogue_manager.play_dialogue([
			"Remember, a Pokémon's [color=yellow]Ability[/color] can completely change how they handle this environment.",
			"Keep that Gas Mask on, and keep an eye on your team's condition!"
		], "Devon Researcher")
		return

	quest_manager.set_flag("ZONE06_RESEARCHER_TALKED", true)

	# Give the Gas Mask (simulated via narrative for now)
	dialogue_manager.play_dialogue([
		"Halt! You can't go deeper into the woods without protection!",
		"The miasma here is thick. It's a [color=purple]Poison-type[/color] Type Overload Zone.",
		"Here, take this [color=yellow]Gas Mask[/color]. It'll protect you from the ambient toxins.",
		"(Received the Gas Mask!)",
		"You also need to be careful with your Pokémon. Have you noticed how the wildlife here is acting?",
		"Prolonged exposure to the Overload Zone has mutated the local Shroomish and Slakoth...",
		"Their very [color=yellow]Abilities[/color] have changed to adapt to the toxins.",
		"A Pokémon's Ability is a passive trait that affects battles or the overworld.",
		"For example, you might see Pokémon here with Abilities that spread poison just by being touched!",
		"As a Rehabilitator, you need to be aware of these mutated Abilities.",
		"When we restore the EHI in this zone, some of those Abilities might heal, while others could become permanent adaptations.",
		"Stay safe in there!"
	], "Devon Researcher")

func trigger_bug_catcher_woods_01() -> void:
	var ehi_state: float = ehi_manager.get_global_ehi()
	if ehi_state < 33.0:
		dialogue_manager.play_dialogue([
			"D-don't go near the Shroomish! They're not normal!",
			"They're called 'Venomish' now. Their spores are violently toxic!",
			"And I saw a Slakoth earlier... it was oozing purple slime.",
			"My Pokedex registered it as 'Toxloth'. It didn't even look like it cared that it was poisoned.",
			"This forest is completely wrong..."
		], "Bug Catcher")
	elif ehi_state < 66.0:
		dialogue_manager.play_dialogue([
			"The air is getting a little clearer, isn't it?",
			"Some of the Venomish are starting to look like regular Shroomish again.",
			"Maybe we really can fix this."
		], "Bug Catcher")
	else:
		dialogue_manager.play_dialogue([
			"Petalburg Woods is finally safe again!",
			"The regular bug Pokémon are coming back out to play.",
			"Thanks to the relocation efforts, the forest feels alive again."
		], "Bug Catcher")

func trigger_team_aqua_grunt_woods_01() -> void:
	if quest_manager.get_flag("AQUA_MURK_ENCOUNTER_SEEN"):
		dialogue_manager.play_dialogue([
			"The ocean is suffering because of this runoff.",
			"Stop bothering me, I have samples to collect."
		], "Team Aqua Grunt")
		return

	quest_manager.set_flag("AQUA_MURK_ENCOUNTER_SEEN", true)
	dialogue_manager.play_dialogue([
		"Ugh, this stench is unbearable.",
		"Hey! Are you the one causing this mess?!",
		"...No? You're a Rehabilitator?",
		"Well, whatever. Team Aqua is investigating the toxic runoff from this forest.",
		"All this poison is leaking into the water table and flowing straight into the ocean!",
		"If you want to help, then start catching those invasive Poison-types and clear this place out.",
		"Otherwise, stay out of our way!"
	], "Team Aqua Grunt")

# Auto-triggered on first entry to the map (called from _ready).
func trigger_zone_entry_event() -> void:
	if quest_manager.get_flag("ZONE06_INTRO_SEEN"):
		return

	quest_manager.set_flag("ZONE06_INTRO_SEEN", true)
	dialogue_manager.play_dialogue([
		"(The air here is thick and sweet-smelling... but it burns your throat.)",
		"(Bioluminescent spores drift through the canopy, glowing a sickly purple.)",
		"(This must be The Murk—the Poison Type Overload Zone.)"
	], "")
