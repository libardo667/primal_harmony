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
# Populated in _ready() after connecting Area2D proximity signals.
# ---------------------------------------------------------------------------
var _npc_triggers := {
	"hiker_glacier_01": trigger_hiker_glacier_01,
	"researcher_glacier_01": trigger_researcher_glacier_01,
	"child_glacier_01": trigger_child_glacier_01,
	"team_aqua_grunt_glacier_01": trigger_team_aqua_grunt_glacier_01,
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
	# Walk the scene tree to find NPC Area2Ds and connect proximity signals.
	var spawn_root := _find_npc_spawn_root()
	if spawn_root == null:
		if DEBUG:
			push_warning("[route113_events] No NPCSpawnPoints node found in scene tree. Proximity triggers inactive.")
		return

	for child in spawn_root.get_children():
		if child is Area2D and _npc_triggers.has(child.name):
			var trigger_fn: Callable = _npc_triggers[child.name]
			# Avoid double-connecting if the scene is reloaded
			if not child.body_entered.is_connected(_on_npc_body_entered.bind(trigger_fn)):
				child.body_entered.connect(_on_npc_body_entered.bind(trigger_fn))
			if DEBUG:
				print("[route113_events] Connected body_entered on: ", child.name)

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
				print("[route113_events] DEBUG KEY_1 — Hiker")
				trigger_hiker_glacier_01()
			KEY_2:
				print("[route113_events] DEBUG KEY_2 — Researcher")
				trigger_researcher_glacier_01()
			KEY_3:
				print("[route113_events] DEBUG KEY_3 — Child")
				trigger_child_glacier_01()
			KEY_4:
				print("[route113_events] DEBUG KEY_4 — Aqua Grunt")
				trigger_team_aqua_grunt_glacier_01()
			KEY_5:
				print("[route113_events] DEBUG KEY_5 — Zone Entry")
				trigger_zone_entry_event()

# ---------------------------------------------------------------------------
# NPC trigger functions
# ---------------------------------------------------------------------------

func trigger_hiker_glacier_01() -> void:
	var ehi_state: float = ehi_manager.get_global_ehi()
	if ehi_state < 33.0:
		dialogue_manager.play_dialogue([
			"Careful ahead! The ash is frozen solid.",
			"You'll wipe out if you don't have [color=yellow]Cleats[/color].",
			"This whole route is a slipping hazard these days."
		], "Hiker")
	else:
		dialogue_manager.play_dialogue([
			"The ice is finally starting to break up.",
			"Much easier to hike now, thanks to the relocation efforts!"
		], "Hiker")

func trigger_researcher_glacier_01() -> void:
	dialogue_manager.play_dialogue([
		"Are you a Rehabilitator?",
		"I'm monitoring the [color=blue]EHI[/color] (Ecological Harmony Index) here at Ashen Glacier.",
		"It's currently reading " + str(ehi_manager.get_global_ehi()) + "%.",
		"If you catch any of those invasive Ice-types, please use the Relocation Terminal at the Pokemon Center.",
		"Relocating them helps the environment recover!"
	], "Researcher")

func trigger_child_glacier_01() -> void:
	var ehi_state: float = ehi_manager.get_global_ehi()
	if ehi_state < 66.0:
		dialogue_manager.play_dialogue([
			"Look what I found! It's a Spinda, but... it's all frozen.",
			"My Pokedex calls it a 'Frostinda'. Is it sick?",
			"I hope the warm weather comes back so it can thaw out."
		], "Child")
	else:
		dialogue_manager.play_dialogue([
			"The Frostinda are shedding their ice!",
			"They look so much happier now."
		], "Child")

func trigger_team_aqua_grunt_glacier_01() -> void:
	if quest_manager.get_flag("AQUA_GLACIER_ENCOUNTER_SEEN"):
		dialogue_manager.play_dialogue([
			"Don't get in our way, kid.",
			"We're here to clean up this frozen mess."
		], "Team Aqua Grunt")
		return

	quest_manager.set_flag("AQUA_GLACIER_ENCOUNTER_SEEN", true)
	dialogue_manager.play_dialogue([
		"Hey! You're treading on a sensitive ecosystem!",
		"This unnatural ice is throwing off the ocean currents nearby.",
		"Team Aqua is taking readings to figure out how to melt this place down.",
		"If you're not here to help restore the balance, then get lost!"
	], "Team Aqua Grunt")

# Auto-triggered on first entry to the map (called from _ready).
func trigger_zone_entry_event() -> void:
	if quest_manager.get_flag("ZONE01_INTRO_SEEN"):
		return

	quest_manager.set_flag("ZONE01_INTRO_SEEN", true)
	dialogue_manager.play_dialogue([
		"(The air here is unnaturally cold...)",
		"(The volcanic ash falling from the sky has been frozen into sharp crystals...)",
		"(This must be a Type Overload Zone.)"
	], "")
