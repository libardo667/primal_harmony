## TriageCatch — Non-Battle Invasive Pokémon Capture Flow
##
## Autoload that intercepts EncounterManager.encounter_triggered and decides:
##   - If the species is a corrupted variant in the active TOZ → offer Triage Catch
##   - Otherwise → start a normal wild battle via BattleManager
##
## Triage Catch: two lines of dialogue followed by a keyboard-navigable
## TriageChoiceMenu (Catch / Battle / Flee).  A successful catch adds the
## Pokémon to the rehab box and logs a quell release.
##
## Dependencies: EncounterManager, BattleManager, PlayerParty, RehabLog, DialogueManager
extends Node

const TriageChoiceMenu := preload("res://ui/menus/TriageChoiceMenu.gd")

# =========================================================================
#  Signals
# =========================================================================

## Emitted when the player successfully triage-catches a Pokémon.
signal triage_caught(species_id: String, zone_id: String)

## Emitted when the player declines to catch (chose Battle or Flee).
signal triage_declined(species_id: String, reason: String)

# =========================================================================
#  State
# =========================================================================

## The encounter data being processed (from EncounterManager.encounter_triggered).
var _pending_encounter: Dictionary = {}

## Whether we are currently in a triage prompt (blocks re-entry).
var _prompt_active: bool = false

## Active TriageChoiceMenu node (kept so we can free it after use).
var _active_menu: Node = null


# =========================================================================
#  Lifecycle
# =========================================================================

func _ready() -> void:
	EncounterManager.encounter_triggered.connect(_on_encounter_triggered)
	print("[TriageCatch] System online — intercepts encounter_triggered.")


# =========================================================================
#  Signal Handler
# =========================================================================

func _on_encounter_triggered(pokemon_data: Dictionary) -> void:
	if _prompt_active or BattleManager.is_battle_active():
		return

	var species_id: String = pokemon_data.get("species_id", "")
	var zone_id: String    = pokemon_data.get("zone_id", "")
	var ehi_state: String  = pokemon_data.get("ehi_state", "restored")
	var level: int         = pokemon_data.get("level", 5)

	var is_invasive: bool = _is_invasive_species(species_id, zone_id)

	if is_invasive and ehi_state in ["infested", "partial"]:
		_pending_encounter = pokemon_data
		_show_triage_prompt(species_id, zone_id, level)
	else:
		_start_wild_battle(pokemon_data)


# =========================================================================
#  Triage Catch Flow
# =========================================================================

func _show_triage_prompt(species_id: String, _zone_id: String, level: int) -> void:
	_prompt_active = true
	var display_name: String = species_id.capitalize()

	# Two-line prompt — concise so the choice menu appears quickly.
	DialogueManager.play_dialogue([
		"A weakened %s (Lv.%d) staggers out of the undergrowth." % [display_name, level],
		"It's exhausted — you could catch it without a fight.",
	], "System")

	if not DialogueManager.dialogue_finished.is_connected(_on_prompt_dialogue_finished):
		DialogueManager.dialogue_finished.connect(_on_prompt_dialogue_finished, CONNECT_ONE_SHOT)


func _on_prompt_dialogue_finished() -> void:
	# Dialogue dismissed — show the keyboard-navigable choice menu.
	var menu: Node = TriageChoiceMenu.new()
	_active_menu = menu
	get_tree().root.add_child(menu)
	menu.choice_made.connect(_on_choice_made, CONNECT_ONE_SHOT)
	menu.show_menu()


func _on_choice_made(choice: String) -> void:
	if _active_menu:
		_active_menu.queue_free()
		_active_menu = null

	var species_id: String = _pending_encounter.get("species_id", "")
	var zone_id: String    = _pending_encounter.get("zone_id", "")
	var level: int         = _pending_encounter.get("level", 5)

	match choice:
		"catch":
			PlayerParty.add_to_rehab_box(species_id, level, zone_id)
			RehabLog.record_quell_release(species_id, zone_id)
			triage_caught.emit(species_id, zone_id)
			print("[TriageCatch] Caught %s from %s. Quell: %.0f%%" % [
				species_id, zone_id,
				RehabLog.get_quell_progress(zone_id) * 100.0,
			])
			var display_name: String = species_id.capitalize()
			DialogueManager.play_dialogue([
				"You carefully restrain the %s in a Rehab Capsule." % display_name,
				"It calms almost immediately — relieved to be out of the miasma.",
				"Zone harmony index has improved slightly.",
			], "System")

		"battle":
			triage_declined.emit(species_id, "battle")
			_start_wild_battle(_pending_encounter)

		"flee":
			print("[TriageCatch] Player fled from encounter.")
			triage_declined.emit(species_id, "flee")

	_pending_encounter.clear()
	_prompt_active = false


# =========================================================================
#  Battle Launch
# =========================================================================

func _start_wild_battle(pokemon_data: Dictionary) -> void:
	var species_id: String = pokemon_data.get("species_id", "")
	var level: int         = pokemon_data.get("level", 5)
	var zone_id: String    = pokemon_data.get("zone_id", "")
	var player_state: Dictionary = PlayerParty.get_active()
	var wild_state: Dictionary   = BattleManager.build_pokemon_state(species_id, level)
	if player_state.is_empty() or wild_state.is_empty():
		push_warning("[TriageCatch] Cannot start battle — missing state.")
		return
	BattleManager.start_wild_battle(player_state, wild_state, zone_id)


# =========================================================================
#  Helpers
# =========================================================================

## Returns true if [param species_id] appears in the zone's corrupted_variants list.
func _is_invasive_species(species_id: String, zone_id: String) -> bool:
	var corrupted: Array = EncounterManager.get_zone_corrupted_variants(zone_id)
	return corrupted.has(species_id)
