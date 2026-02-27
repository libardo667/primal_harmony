## starter_selection.gd — Handles player interaction with the three starter Pokéballs.
##
## Flow per ball:
##   1. Show lore dialogue (2 lines).
##   2. After dialogue closes → YesNoMenu asks "Rehabilitate this X?".
##   3. Yes → select_starter() → _give_pokemon() → add to party + flag set + confirm dialogue.
##   4. No  → cancel, _pending_species cleared.
extends Node

# =========================================================================
#  Autoload references
# =========================================================================

@onready var dialogue_manager: Node = get_node("/root/DialogueManager")
@onready var quest_manager: Node    = get_node("/root/QuestManager")

# =========================================================================
#  Constants
# =========================================================================

const YES_NO_MENU := preload("res://ui/menus/YesNoMenu.gd")

# =========================================================================
#  State
# =========================================================================

## Species pending confirmation (set when ball interaction starts).
var _pending_species: String = ""


# =========================================================================
#  Ball Interactions
# =========================================================================

func interact_with_treecko_ball() -> void:
	if quest_manager.get_flag("STARTER_CHOSEN"):
		return
	_pending_species = "scleecko"
	dialogue_manager.play_dialogue([
		"This Pokémon resembles a Treecko, but its skin has hardened into chitin.",
		"It's covered in heavy rock plates. It looks exhausted.",
	], "System")
	dialogue_manager.dialogue_finished.connect(_on_intro_done, CONNECT_ONE_SHOT)


func interact_with_torchic_ball() -> void:
	if quest_manager.get_flag("STARTER_CHOSEN"):
		return
	_pending_species = "clenchic"
	dialogue_manager.play_dialogue([
		"This Pokémon resembles a Torchic, but its feathers are interlocking iron plates.",
		"It radiates an intense, rigid heat.",
	], "System")
	dialogue_manager.dialogue_finished.connect(_on_intro_done, CONNECT_ONE_SHOT)


func interact_with_mudkip_ball() -> void:
	if quest_manager.get_flag("STARTER_CHOSEN"):
		return
	_pending_species = "phantokip"
	dialogue_manager.play_dialogue([
		"This Pokémon resembles a Mudkip, but it's partially translucent.",
		"It barely seems tethered to the physical world.",
	], "System")
	dialogue_manager.dialogue_finished.connect(_on_intro_done, CONNECT_ONE_SHOT)


# =========================================================================
#  Async Confirmation Flow
# =========================================================================

func _on_intro_done() -> void:
	if _pending_species.is_empty():
		return
	var display_name: String = DataManager.get_pokemon_display_name(_pending_species)
	var menu: Node = YES_NO_MENU.new()
	get_tree().root.add_child(menu)
	menu.confirmed.connect(_on_confirmed, CONNECT_ONE_SHOT)
	menu.cancelled.connect(_on_cancelled, CONNECT_ONE_SHOT)
	menu.show_prompt("Rehabilitate this %s?" % display_name)


func _on_confirmed() -> void:
	select_starter(_pending_species)


func _on_cancelled() -> void:
	_pending_species = ""


# =========================================================================
#  Starter Delivery
# =========================================================================

## Called by _on_confirmed (or directly for scripted events).
func select_starter(choice: String) -> void:
	match choice:
		"scleecko":
			_give_pokemon("scleecko")
			dialogue_manager.play_dialogue([
				"You gently pick up the rocky Scleecko.",
				"It feels cold and heavy, but it leans into your hand.",
				"Your journey as a Rehabilitator begins.",
			], "System")
		"clenchic":
			_give_pokemon("clenchic")
			dialogue_manager.play_dialogue([
				"You carefully lift the iron-plated Clenchic.",
				"It's rigid and guarded, but its internal heat dims slightly in a sign of trust.",
				"Your journey as a Rehabilitator begins.",
			], "System")
		"phantokip":
			_give_pokemon("phantokip")
			dialogue_manager.play_dialogue([
				"You reach for the translucent Phantokip.",
				"Your hand passes through it slightly before it solidifies enough to hold.",
				"Your journey as a Rehabilitator begins.",
			], "System")


func _give_pokemon(species_id: String) -> void:
	quest_manager.set_flag("STARTER_CHOSEN", true)
	_pending_species = ""
	PlayerParty.add_to_party(species_id, 5)
