## BattleManager — Turn-Based Battle Engine
##
## Autoload singleton managing all wild and trainer battles.
## Handles turn structure, priority resolution, damage calculation,
## status effects, and battle result dispatching.
##
## Phase 2 delivery. Cooperative battle mode is Phase 3.
##
## Owner: The Mechanic
## Dependencies: DataManager (species/move stats), EHI, FactionManager
extends Node

# =========================================================================
#  Signals
# =========================================================================

## Emitted when a battle begins.
## [param context] Dictionary: { "type": "wild"|"trainer", "zone_id": String,
##   "player_party": Array, "opponent_party": Array }
signal battle_started(context: Dictionary)

## Emitted when a battle ends.
## [param result] Dictionary: { "outcome": "win"|"loss"|"flee",
##   "zone_id": String, "exp_gained": int, "ehi_delta": float }
signal battle_ended(result: Dictionary)

## Emitted at the start of each turn.
## [param turn_number] Current turn count (1-indexed).
signal turn_started(turn_number: int)

## Emitted when a combatant uses a move.
## [param action] Dictionary with full action context.
signal move_used(action: Dictionary)

## Emitted when damage is dealt to a combatant.
## [param damage_event] { "target": String, "damage": int, "type_effectiveness": float,
##   "is_critical": bool }
signal damage_dealt(damage_event: Dictionary)

## Emitted when a status condition is applied.
## [param status_event] { "target": String, "status": String }
signal status_applied(status_event: Dictionary)

## Emitted when a Pokémon faints.
## [param faint_event] { "target": String, "species_id": String }
signal pokemon_fainted(faint_event: Dictionary)

## Emitted when a Pokémon levels up.
## [param level_event] { "species_id": String, "new_level": int }
signal level_up(level_event: Dictionary)

# =========================================================================
#  Constants
# =========================================================================

## Weather / EHI state modifiers on damage (placeholder values).
const EHI_DAMAGE_MOD_INFESTED: float = 1.1 ## Infested zones slightly buff foes.
const EHI_DAMAGE_MOD_RESTORED: float = 0.9 ## Restored zones slightly debuff foes.

## Faction rep bonus: high alliance rep gives minor battle buffs.
const FACTION_BONUS_THRESHOLD: float = 60.0
const FACTION_BONUS_ACCURACY_MOD: float = 1.05

## Base flee chance per level differential.
const BASE_FLEE_CHANCE: float = 0.5
const FLEE_LEVEL_SCALE: float = 0.05

## Critical hit probability (1/16 standard).
const CRITICAL_HIT_CHANCE: float = 0.0625

## EHI reward for winning a battle in a TOZ zone.
const EHI_WIN_BONUS: float = 0.5

## Experience share factor (simplified: 100% to active battler).
const EXP_SHARE_FACTOR: float = 1.0

# =========================================================================
#  Battle State
# =========================================================================

## Current battle context. Empty when no battle is active.
var _context: Dictionary = {}

## Player's current active Pokémon runtime state.
var _player_active: Dictionary = {}

## Opponent's current active Pokémon runtime state.
var _opponent_active: Dictionary = {}

## Turn number counter.
var _turn_number: int = 0

## Whether a battle is currently in progress.
var _battle_active: bool = false

## Queued actions for the current turn (player + opponent).
## Each: { "actor": "player"|"opponent", "type": "move"|"item"|"switch"|"flee",
##         "move_id": String, "target": String }
var _queued_actions: Array[Dictionary] = []


# =========================================================================
#  Lifecycle
# =========================================================================

func _ready() -> void:
	print("[BattleManager] System online.")
	# Connect to EHI and FactionManager signals per Phase 2 spec.
	EHI.global_ehi_changed.connect(_on_global_ehi_changed)
	FactionManager.faction_rep_changed.connect(_on_faction_rep_changed)
	FactionManager.alliance_unlocked.connect(_on_alliance_unlocked)


# =========================================================================
#  Public API — Battle Initiation
# =========================================================================

## Starts a wild battle in the given zone.
## [param player_pokemon_data] Runtime state dict for the player's active Pokémon.
## [param wild_pokemon_data] Runtime state dict for the wild Pokémon.
## [param zone_id] Zone where the battle occurs.
func start_wild_battle(player_pokemon_data: Dictionary,
		wild_pokemon_data: Dictionary, zone_id: String) -> void:
	if _battle_active:
		push_warning("[BattleManager] Battle already active. Ignoring start request.")
		return

	_battle_active = true
	_turn_number = 0
	_player_active = player_pokemon_data.duplicate(true)
	_opponent_active = wild_pokemon_data.duplicate(true)

	_context = {
		"type": "wild",
		"zone_id": zone_id,
		"player_party": [_player_active],
		"opponent_party": [_opponent_active],
	}

	print("[BattleManager] ⚔ Wild battle started! %s vs %s in %s" % [
		_player_active.get("species_id", "?"),
		_opponent_active.get("species_id", "?"),
		zone_id,
	])
	
	_trigger_ability_hook("on_entry", "player")
	_trigger_ability_hook("on_entry", "opponent")
	
	battle_started.emit(_context)
	_start_turn()


## Starts a trainer battle.
## [param player_party] Array of runtime party Dictionaries for the player.
## [param trainer_party] Array of runtime party Dictionaries for the trainer.
## [param zone_id] Zone where the battle occurs.
func start_trainer_battle(player_party: Array, trainer_party: Array,
		zone_id: String) -> void:
	if _battle_active:
		push_warning("[BattleManager] Battle already active. Ignoring start request.")
		return

	_battle_active = true
	_turn_number = 0
	_player_active = player_party[0].duplicate(true) if not player_party.is_empty() else {}
	_opponent_active = trainer_party[0].duplicate(true) if not trainer_party.is_empty() else {}

	_context = {
		"type": "trainer",
		"zone_id": zone_id,
		"player_party": player_party.duplicate(true),
		"opponent_party": trainer_party.duplicate(true),
	}

	print("[BattleManager] ⚔ Trainer battle started in %s" % zone_id)
	
	_trigger_ability_hook("on_entry", "player")
	_trigger_ability_hook("on_entry", "opponent")
	
	battle_started.emit(_context)
	_start_turn()


# =========================================================================
#  Public API — Turn Actions
# =========================================================================

## Queues/executes a move for the player's active Pokémon.
## [param move_id] The move to use (from DataManager).
func player_use_move(move_id: String) -> void:
	if not _battle_active:
		return
	var action: Dictionary = {
		"actor": "player",
		"type": "move",
		"move_id": move_id,
		"target": "opponent",
	}
	_queued_actions.append(action)
	_resolve_turn()


## Queues/executes a flee attempt by the player.
func player_flee() -> void:
	if not _battle_active:
		return
	var action: Dictionary = {"actor": "player", "type": "flee"}
	_queued_actions.append(action)
	_resolve_turn()


# =========================================================================
#  Public API — Queries
# =========================================================================

## Returns [code]true[/code] if a battle is currently active.
func is_battle_active() -> bool:
	return _battle_active


## Returns the current turn number (0 if no battle).
func get_turn_number() -> int:
	return _turn_number


## Returns a snapshot of the current battle context.
func get_context() -> Dictionary:
	return _context.duplicate(true)


## Returns the player's active Pokémon state.
func get_player_active() -> Dictionary:
	return _player_active.duplicate(true)


## Returns the opponent's active Pokémon state.
func get_opponent_active() -> Dictionary:
	return _opponent_active.duplicate(true)


# =========================================================================
#  Internal — Turn Engine
# =========================================================================

func _start_turn() -> void:
	_turn_number += 1
	_queued_actions.clear()
	turn_started.emit(_turn_number)
	print("[BattleManager] Turn %d begins." % _turn_number)

	# Generate opponent AI action.
	_queue_opponent_ai_action()


func _queue_opponent_ai_action() -> void:
	var move_id: String = _pick_opponent_move()
	_queued_actions.append({
		"actor": "opponent",
		"type": "move",
		"move_id": move_id,
		"target": "player",
	})


func _pick_opponent_move() -> String:
	## Simple AI: pick a random move from the opponent's learnset.
	var learnset: Array = _opponent_active.get("learnset", [])
	if learnset.is_empty():
		return "tackle" # Fallback: universal basic move.
	return learnset[randi() % learnset.size()].get("move_id", "tackle")


func _resolve_turn() -> void:
	## Sort actions by priority: priority stat first, then Speed.
	_queued_actions.sort_custom(_compare_action_priority)

	for action: Dictionary in _queued_actions:
		if not _battle_active:
			break # Battle may have ended mid-turn (faint/flee).
		_execute_action(action)

	if _battle_active:
		_apply_end_of_turn_effects()
		_start_turn()


func _compare_action_priority(a: Dictionary, b: Dictionary) -> bool:
	## Returns true if action a should go before action b.
	## Flee always goes last. Moves are sorted by move priority, then speed.
	if a.get("type") == "flee":
		return false
	if b.get("type") == "flee":
		return true

	var a_move: MoveData = DataManager.get_move(a.get("move_id", ""))
	var b_move: MoveData = DataManager.get_move(b.get("move_id", ""))

	var a_priority: int = a_move.priority if a_move else 0
	var b_priority: int = b_move.priority if b_move else 0
	if a_priority != b_priority:
		return a_priority > b_priority

	# Same priority bracket — compare Speed.
	var a_actor: Dictionary = _get_actor_state(a.get("actor", ""))
	var b_actor: Dictionary = _get_actor_state(b.get("actor", ""))
	var a_spd: int = a_actor.get("current_stats", {}).get("spe", 0)
	var b_spd: int = b_actor.get("current_stats", {}).get("spe", 0)
	return a_spd > b_spd


func _execute_action(action: Dictionary) -> void:
	match action.get("type", ""):
		"move":
			_execute_move(action)
		"flee":
			_execute_flee(action)
		"item":
			pass # Phase 3 — item use in battle.
		"switch":
			pass # Phase 3 — party switching.


func _execute_flee(action: Dictionary) -> void:
	if action.get("actor") != "player":
		return # Wild Pokémon flee is handled by AI, not this path.

	var player_spe: int = _player_active.get("current_stats", {}).get("spe", 50)
	var opp_spe: int = _opponent_active.get("current_stats", {}).get("spe", 50)
	var flee_chance: float = BASE_FLEE_CHANCE
	if player_spe >= opp_spe:
		flee_chance = min(1.0, BASE_FLEE_CHANCE + FLEE_LEVEL_SCALE * float(player_spe - opp_spe))

	if randf() <= flee_chance:
		print("[BattleManager] Player fled successfully.")
		_end_battle("flee", 0, 0.0)
	else:
		print("[BattleManager] Flee failed!")


# =========================================================================
#  Internal — Move Execution
# =========================================================================

func _execute_move(action: Dictionary) -> void:
	var attacker_key: String = action.get("actor", "player")
	var target_key: String = action.get("target", "opponent")
	var attacker: Dictionary = _get_actor_state(attacker_key)
	var defender: Dictionary = _get_actor_state(target_key)
	var move_id: String = action.get("move_id", "tackle")

	# Status check: paralysis skip.
	if _check_status_blocks_move(attacker, attacker_key):
		return

	var move_data: MoveData = DataManager.get_move(move_id)
	if move_data == null:
		push_warning("[BattleManager] Unknown move: %s. Skipping." % move_id)
		return

	# Emit move event.
	var move_event: Dictionary = {
		"actor": attacker_key,
		"species_id": attacker.get("species_id", "?"),
		"move_id": move_id,
		"move_name": move_data.name,
	}
	move_used.emit(move_event)
	print("[BattleManager] %s used %s!" % [attacker.get("species_id", "?"), move_data.name])

	# Accuracy check.
	if not _accuracy_check(move_data, attacker):
		print("[BattleManager] %s's attack missed!" % attacker.get("species_id", "?"))
		return

	var category: String = move_data.category
	match category:
		"physical", "special":
			_resolve_damage(move_data, attacker, defender, target_key)
		"status":
			_resolve_status_move(move_data, defender, target_key)


func _accuracy_check(move_data: MoveData, _attacker: Dictionary) -> bool:
	var base_accuracy: Variant = move_data.accuracy
	if base_accuracy == null:
		return true # Never-miss moves.

	var accuracy: float = float(base_accuracy) / 100.0

	# Apply Faction accuracy bonus.
	if _get_faction_accuracy_bonus():
		accuracy *= FACTION_BONUS_ACCURACY_MOD

	return randf() <= accuracy


func _get_faction_accuracy_bonus() -> bool:
	## Returns true if player's leading faction rep is above threshold.
	var aqua: float = FactionManager.get_rep("aqua")
	var magma: float = FactionManager.get_rep("magma")
	return maxf(aqua, magma) >= FACTION_BONUS_THRESHOLD


# =========================================================================
#  Internal — Damage Calculation
# =========================================================================

func _resolve_damage(move_data: MoveData, attacker: Dictionary,
		defender: Dictionary, target_key: String) -> void:
	var attacker_key: String = "player" if target_key == "opponent" else "opponent"
	var damage: int = _calculate_damage(move_data, attacker, defender, attacker_key)

	var is_critical: bool = randf() <= CRITICAL_HIT_CHANCE
	if is_critical:
		damage = int(damage * 1.5)
		print("[BattleManager] Critical hit!")

	## Apply EHI modifier (opponent Pokémon in infested zones fight harder).
	var zone_id: String = _context.get("zone_id", "")
	damage = _apply_ehi_modifier(damage, target_key, zone_id)

	# Clamp to minimum 1.
	damage = maxi(1, damage)

	# Apply damage.
	var current_hp: int = defender.get("current_hp", 1)
	var new_hp: int = maxi(0, current_hp - damage)
	_set_actor_hp(target_key, new_hp)

	var damage_event: Dictionary = {
		"target": target_key,
		"damage": damage,
		"type_effectiveness": _get_type_effectiveness(move_data, defender, target_key),
		"is_critical": is_critical,
	}
	damage_dealt.emit(damage_event)
	print("[BattleManager] %s took %d damage. HP: %d → %d" % [
		defender.get("species_id", "?"), damage, current_hp, new_hp
	])

	# Apply drain / secondary effect if defined.
	var effect: Variant = move_data.effect
	if effect != null:
		var effect_str: String = effect as String
		if effect_str.begins_with("drain_"):
			# "drain_50pct" → restore 50% of damage dealt to attacker.
			var pct_str: String = effect_str.trim_prefix("drain_").trim_suffix("pct")
			var pct: float = float(pct_str) / 100.0
			var heal: int = maxi(1, int(damage * pct))
			var a_hp: int = attacker.get("current_hp", 0)
			var a_max: int = attacker.get("max_hp", 1)
			_set_actor_hp(attacker_key, mini(a_max, a_hp + heal))
			print("[BattleManager] %s restored %d HP!" % [attacker.get("species_id", "?"), heal])
		else:
			_try_apply_secondary_effect(effect_str, defender, target_key)

	var hook_context: Dictionary = {
		"move_data": move_data,
		"is_contact": move_data.flags.has("contact")
	}
	_trigger_ability_hook("on_damage_taken", target_key, hook_context)

	# Check for faint.
	if new_hp <= 0:
		_handle_faint(target_key)


func _calculate_damage(move_data: MoveData, attacker: Dictionary,
		defender: Dictionary, attacker_key: String = "") -> int:
	## Standard Gen 3–style damage formula (simplified):
	## Damage = (((2 * Level / 5 + 2) * Power * A / D) / 50 + 2) * STAB * Type
	var level: int = attacker.get("level", 1)
	var power: Variant = move_data.power
	if power == null or int(power) == 0:
		return 0

	var category: String = move_data.category
	var attacker_stats: Dictionary = attacker.get("current_stats", {})
	var defender_stats: Dictionary = defender.get("current_stats", {})

	var atk_stat: int
	var def_stat: int
	if category == "physical":
		atk_stat = int(attacker_stats.get("atk", 50) * _get_stat_multiplier(attacker.get("stat_stages", {}).get("atk", 0)))
		def_stat = int(defender_stats.get("def", 50) * _get_stat_multiplier(defender.get("stat_stages", {}).get("def", 0)))
	else:
		atk_stat = int(attacker_stats.get("spa", 50) * _get_stat_multiplier(attacker.get("stat_stages", {}).get("spa", 0)))
		def_stat = int(defender_stats.get("spd", 50) * _get_stat_multiplier(defender.get("stat_stages", {}).get("spd", 0)))

	var base: float = (float(2 * level) / 5.0 + 2.0) * float(power) * float(atk_stat) / float(def_stat)
	base = base / 50.0 + 2.0

	# STAB check.
	var move_type: String = move_data.type
	var attacker_types: Array = attacker.get("types", [])
	if attacker_types.has(move_type):
		base *= 1.5

	if attacker_key != "":
		var hook_context: Dictionary = {"move_data": move_data, "damage_multiplier": 1.0}
		_trigger_ability_hook("on_attack", attacker_key, hook_context)
		base *= hook_context.get("damage_multiplier", 1.0)

	# Type effectiveness.
	var target_key: String = "opponent" if attacker_key == "player" else "player"
	base *= _get_type_effectiveness(move_data, defender, target_key)

	# Random factor (85–100%).
	base *= randf_range(0.85, 1.0)

	return int(base)


func _get_type_effectiveness(move_data: MoveData, defender: Dictionary, target_key: String = "") -> float:
	## Returns the type effectiveness multiplier for this move vs. defender.
	## Full chart — generation-accurate for types in this game.
	## 2.0 = super effective, 0.5 = not very effective, 0.0 = immune.
	const CHART: Dictionary = {
		"Normal": {"Rock": 0.5, "Ghost": 0.0, "Steel": 0.5},
		"Fire": {"Fire": 0.5, "Water": 0.5, "Grass": 2.0, "Ice": 2.0, "Bug": 2.0, "Rock": 0.5, "Dragon": 0.5, "Steel": 2.0},
		"Water": {"Fire": 2.0, "Water": 0.5, "Grass": 0.5, "Ground": 2.0, "Rock": 2.0, "Dragon": 0.5},
		"Grass": {"Fire": 0.5, "Water": 2.0, "Grass": 0.5, "Poison": 0.5, "Ground": 2.0, "Flying": 0.5, "Bug": 0.5, "Rock": 2.0, "Dragon": 0.5, "Steel": 0.5},
		"Electric": {"Water": 2.0, "Electric": 0.5, "Grass": 0.5, "Ground": 0.0, "Flying": 2.0, "Dragon": 0.5},
		"Ice": {"Fire": 0.5, "Water": 0.5, "Grass": 2.0, "Ice": 0.5, "Ground": 2.0, "Flying": 2.0, "Dragon": 2.0, "Steel": 0.5},
		"Fighting": {"Normal": 2.0, "Ice": 2.0, "Poison": 0.5, "Flying": 0.5, "Psychic": 0.5, "Bug": 0.5, "Rock": 2.0, "Ghost": 0.0, "Dark": 2.0, "Steel": 2.0, "Fairy": 0.5},
		"Poison": {"Grass": 2.0, "Poison": 0.5, "Ground": 0.5, "Rock": 0.5, "Ghost": 0.5, "Steel": 0.0, "Fairy": 2.0},
		"Ground": {"Fire": 2.0, "Electric": 2.0, "Grass": 0.5, "Poison": 2.0, "Flying": 0.0, "Bug": 0.5, "Rock": 2.0, "Steel": 2.0},
		"Flying": {"Electric": 0.5, "Grass": 2.0, "Fighting": 2.0, "Bug": 2.0, "Rock": 0.5, "Steel": 0.5},
		"Psychic": {"Fighting": 2.0, "Poison": 2.0, "Psychic": 0.5, "Dark": 0.0, "Steel": 0.5},
		"Bug": {"Fire": 0.5, "Grass": 2.0, "Fighting": 0.5, "Flying": 0.5, "Psychic": 2.0, "Ghost": 0.5, "Dark": 2.0, "Steel": 0.5, "Fairy": 0.5},
		"Rock": {"Fire": 2.0, "Ice": 2.0, "Fighting": 0.5, "Ground": 0.5, "Flying": 2.0, "Bug": 2.0, "Steel": 0.5},
		"Ghost": {"Normal": 0.0, "Psychic": 2.0, "Ghost": 2.0, "Dark": 0.5},
		"Dragon": {"Dragon": 2.0, "Steel": 0.5, "Fairy": 0.0},
		"Dark": {"Fighting": 0.5, "Psychic": 2.0, "Ghost": 2.0, "Dark": 0.5, "Fairy": 0.5},
		"Steel": {"Fire": 0.5, "Water": 0.5, "Electric": 0.5, "Ice": 2.0, "Rock": 2.0, "Steel": 0.5, "Fairy": 2.0},
		"Fairy": {"Fire": 0.5, "Fighting": 2.0, "Poison": 0.5, "Dragon": 2.0, "Dark": 2.0, "Steel": 0.5},
	}

	var move_type: String = move_data.type
	
	if target_key != "":
		var hook_context: Dictionary = {"move_data": move_data, "is_immune": false}
		_trigger_ability_hook("passive", target_key, hook_context)
		if hook_context.get("is_immune", false):
			return 0.0

	var defender_types: Array = defender.get("types", ["Normal"])

	var effectiveness: float = 1.0
	if CHART.has(move_type):
		var row: Dictionary = CHART[move_type]
		for def_type: String in defender_types:
			if row.has(def_type):
				effectiveness *= float(row[def_type])

	return effectiveness


func _apply_ehi_modifier(base_damage: int, target_key: String, zone_id: String) -> int:
	## Infested zones buff wild Pokémon (they're in their element).
	## Restored zones debuff them.
	if zone_id.is_empty():
		return base_damage

	var ehi: float = EHI.get_zone_ehi(zone_id)
	if target_key == "player":
		# Wild/opponent dealing damage TO player — EHI infested buffs opponent slightly.
		if ehi <= 35.0:
			return int(base_damage * EHI_DAMAGE_MOD_INFESTED)
		elif ehi >= 70.0:
			return int(base_damage * EHI_DAMAGE_MOD_RESTORED)
	return base_damage


# =========================================================================
#  Internal — Status Effects
# =========================================================================

func _resolve_status_move(move_data: MoveData, target: Dictionary,
		target_key: String) -> void:
	var effect: Variant = move_data.effect
	if effect == null:
		return
	var effect_str: String = effect as String
	if effect_str.begins_with("stat_drop_") or effect_str.begins_with("stat_raise_"):
		_apply_stat_stage_effect(effect_str, target_key)
	else:
		_apply_status(effect_str, target, target_key)


## Applies a stat stage change from effect strings like "stat_drop_def_1" or "stat_raise_atk_2".
func _apply_stat_stage_effect(effect: String, target_key: String) -> void:
	var parts: Array = effect.split("_")
	if parts.size() < 4:
		return
	var direction: String = parts[1]  # "drop" or "raise"
	var stat: String = parts[2]       # "atk", "def", "spa", "spd", "spe"
	var stages: int = int(parts[3])
	if direction == "drop":
		stages = -stages

	var actor: Dictionary = _get_actor_state(target_key)
	var stat_stages: Dictionary = actor.get("stat_stages", {}).duplicate()
	stat_stages[stat] = clampi(stat_stages.get(stat, 0) + stages, -6, 6)
	_set_actor_field(target_key, "stat_stages", stat_stages)

	var direction_text: String = "fell!" if stages < 0 else "rose!"
	print("[BattleManager] %s's %s %s" % [actor.get("species_id", "?"), stat.to_upper(), direction_text])


func _try_apply_secondary_effect(effect: String, target: Dictionary,
		target_key: String) -> void:
	## Secondary effects have a probability encoded in the effect string,
	## e.g. "burn_10" = 10% burn chance, "flinch_30" = 30% flinch.
	var parts: Array = effect.split("_")
	if parts.size() < 2:
		return
	var chance: float = float(parts[parts.size() - 1]) / 100.0
	if randf() <= chance:
		var status_name: String = "_".join(parts.slice(0, parts.size() - 1))
		_apply_status(status_name, target, target_key)


func _apply_status(status: String, _target: Dictionary, target_key: String) -> void:
	## Status IDs: "burn", "freeze", "paralysis", "poison", "sleep", "confusion", "flinch"
	var actor: Dictionary = _get_actor_state(target_key)
	var current_status: String = actor.get("status", "")

	# Can't stack primary statuses; flinch/confusion can coexist.
	const PRIMARY_STATUSES: Array[String] = ["burn", "freeze", "paralysis", "poison", "sleep"]
	if PRIMARY_STATUSES.has(status) and current_status != "" and PRIMARY_STATUSES.has(current_status):
		return

	_set_actor_status(target_key, status)
	var event: Dictionary = {"target": target_key, "status": status}
	status_applied.emit(event)
	print("[BattleManager] %s was inflicted with %s!" % [
		actor.get("species_id", "?"), status
	])


func _check_status_blocks_move(actor: Dictionary, actor_key: String) -> bool:
	var status: String = actor.get("status", "")
	match status:
		"sleep":
			# Decrement sleep counter; wake up at 0.
			var sleep_turns: int = actor.get("sleep_turns", 1)
			sleep_turns -= 1
			_set_actor_field(actor_key, "sleep_turns", sleep_turns)
			if sleep_turns <= 0:
				_set_actor_status(actor_key, "")
				print("[BattleManager] %s woke up!" % actor.get("species_id", "?"))
			else:
				print("[BattleManager] %s is fast asleep!" % actor.get("species_id", "?"))
				return true
		"freeze":
			# 20% chance to thaw each turn.
			if randf() <= 0.2:
				_set_actor_status(actor_key, "")
				print("[BattleManager] %s thawed out!" % actor.get("species_id", "?"))
			else:
				print("[BattleManager] %s is frozen solid!" % actor.get("species_id", "?"))
				return true
		"paralysis":
			# 25% chance to be unable to move.
			if randf() <= 0.25:
				print("[BattleManager] %s is paralyzed! It can't move!" % actor.get("species_id", "?"))
				return true
	return false


func _apply_end_of_turn_effects() -> void:
	for actor_key: String in ["player", "opponent"]:
		var actor: Dictionary = _get_actor_state(actor_key)
		var status: String = actor.get("status", "")
		var max_hp: int = actor.get("max_hp", 1)

		match status:
			"burn":
				## Burn deals 1/8 max HP each turn.
				var burn_damage: int = maxi(1, int(max_hp / 8.0))
				var new_hp: int = maxi(0, actor.get("current_hp", 0) - burn_damage)
				_set_actor_hp(actor_key, new_hp)
				print("[BattleManager] %s is hurt by its burn! (%d damage)" % [
					actor.get("species_id", "?"), burn_damage
				])
				if new_hp <= 0:
					_handle_faint(actor_key)
			"poison":
				## Poison deals 1/8 max HP each turn.
				var poison_damage: int = maxi(1, int(max_hp / 8.0))
				var new_hp2: int = maxi(0, actor.get("current_hp", 0) - poison_damage)
				_set_actor_hp(actor_key, new_hp2)
				print("[BattleManager] %s is hurt by poison! (%d damage)" % [
					actor.get("species_id", "?"), poison_damage
				])
				if new_hp2 <= 0:
					_handle_faint(actor_key)


# =========================================================================
#  Internal — Battle Resolution
# =========================================================================

func _handle_faint(fainted_key: String) -> void:
	var fainted: Dictionary = _get_actor_state(fainted_key)
	var faint_event: Dictionary = {
		"target": fainted_key,
		"species_id": fainted.get("species_id", "?"),
	}
	pokemon_fainted.emit(faint_event)
	print("[BattleManager] %s fainted!" % fainted.get("species_id", "?"))

	if fainted_key == "player":
		_end_battle("loss", 0, 0.0)
	else:
		# Player won.
		var exp_gained: int = _calculate_exp(fainted)
		_apply_exp(_player_active, exp_gained)
		var ehi_delta: float = EHI_WIN_BONUS
		var zone_id: String = _context.get("zone_id", "")
		if not zone_id.is_empty():
			EHI.modify_zone_ehi(zone_id, ehi_delta)
		_end_battle("win", exp_gained, ehi_delta)


func _calculate_exp(defeated: Dictionary) -> int:
	## Simplified: base_exp * level * EXP_SHARE_FACTOR.
	var species_data: PokemonData = DataManager.get_pokemon(defeated.get("species_id", ""))
	if species_data == null:
		return 0
	var base_exp: int = species_data.base_exp
	var level: int = defeated.get("level", 1)
	return int(float(base_exp) * float(level) / 5.0 * EXP_SHARE_FACTOR)


func _apply_exp(pokemon: Dictionary, exp_amount: int) -> void:
	## Simplified: accumulate exp and trigger level-up check.
	var current_exp: int = pokemon.get("exp", 0)
	var new_exp: int = current_exp + exp_amount
	pokemon["exp"] = new_exp
	_player_active["exp"] = new_exp

	## Basic level-up: level up every 100 * level exp (placeholder curve).
	var current_level: int = pokemon.get("level", 1)
	var exp_to_next: int = current_level * 100
	if new_exp >= exp_to_next and current_level < 100:
		_player_active["level"] = current_level + 1
		_player_active["exp"] = new_exp - exp_to_next
		_recalculate_stats(_player_active)
		level_up.emit({"species_id": _player_active.get("species_id", "?"), "new_level": current_level + 1})
		print("[BattleManager] %s leveled up to %d!" % [_player_active.get("species_id", "?"), current_level + 1])

	print("[BattleManager] Gained %d EXP." % exp_amount)


func _recalculate_stats(pokemon: Dictionary) -> void:
	## Recalculates current_stats from base_stats + level.
	## Uses Gen 3 stat formula (simplified — no EVs/IVs for now).
	var species_data: PokemonData = DataManager.get_pokemon(pokemon.get("species_id", ""))
	if species_data == null:
		return
	var base: Dictionary = species_data.base_stats
	var level: int = pokemon.get("level", 1)

	var stats: Dictionary = {
		"hp": int((float(base.get("hp", 45)) * 2.0 * float(level)) / 100.0) + level + 10,
		"atk": int((float(base.get("atk", 45)) * 2.0 * float(level)) / 100.0) + 5,
		"def": int((float(base.get("def", 45)) * 2.0 * float(level)) / 100.0) + 5,
		"spa": int((float(base.get("spa", 45)) * 2.0 * float(level)) / 100.0) + 5,
		"spd": int((float(base.get("spd", 45)) * 2.0 * float(level)) / 100.0) + 5,
		"spe": int((float(base.get("spe", 45)) * 2.0 * float(level)) / 100.0) + 5,
	}
	pokemon["current_stats"] = stats
	pokemon["max_hp"] = stats["hp"]


func _end_battle(outcome: String, exp_gained: int, ehi_delta: float) -> void:
	_battle_active = false
	var result: Dictionary = {
		"outcome": outcome,
		"zone_id": _context.get("zone_id", ""),
		"exp_gained": exp_gained,
		"ehi_delta": ehi_delta,
	}
	battle_ended.emit(result)
	print("[BattleManager] Battle ended. Outcome: %s" % outcome)
	_context.clear()
	_player_active.clear()
	_opponent_active.clear()
	_turn_number = 0


# =========================================================================
#  Internal — Actor State Accessors
# =========================================================================

func _get_actor_state(actor_key: String) -> Dictionary:
	if actor_key == "player":
		return _player_active
	return _opponent_active


func _set_actor_hp(actor_key: String, hp: int) -> void:
	if actor_key == "player":
		_player_active["current_hp"] = hp
	else:
		_opponent_active["current_hp"] = hp


func _set_actor_status(actor_key: String, status: String) -> void:
	if actor_key == "player":
		_player_active["status"] = status
	else:
		_opponent_active["status"] = status


func _set_actor_field(actor_key: String, field: String, value: Variant) -> void:
	if actor_key == "player":
		_player_active[field] = value
	else:
		_opponent_active[field] = value


# =========================================================================
#  Internal — Ability Engine
# =========================================================================

func _get_stat_multiplier(stage: int) -> float:
	if stage >= 0:
		return (2.0 + float(stage)) / 2.0
	else:
		return 2.0 / (2.0 - float(stage))

func _trigger_ability_hook(trigger_type: String, actor_key: String, context: Dictionary = {}) -> void:
	var actor: Dictionary = _get_actor_state(actor_key)
	if actor.is_empty():
		return
	var ability_id: String = actor.get("ability_id", "")
	if ability_id.is_empty():
		return
		
	var ability_data: AbilityData = DataManager.get_ability(ability_id)
	if ability_data == null:
		return
	var hooks: Array = ability_data.hooks
	
	for hook in hooks:
		if hook.get("trigger", "") == trigger_type:
			_apply_ability_effect(actor_key, hook.get("effect_type", ""), hook.get("params", {}), context)

func _apply_ability_effect(actor_key: String, effect_type: String, params: Dictionary, context: Dictionary) -> void:
	var actor: Dictionary = _get_actor_state(actor_key)
	var ability: AbilityData = DataManager.get_ability(actor.get("ability_id", ""))
	var ability_name: String = ability.name if ability else ""
	
	match effect_type:
		"stat_modifier":
			var target_key: String = params.get("target", "opponent")
			if target_key == "opponent":
				target_key = "opponent" if actor_key == "player" else "player"
			else:
				target_key = actor_key
				
			var target: Dictionary = _get_actor_state(target_key)
			var stat: String = params.get("stat", "atk")
			var stages: int = params.get("stages", -1)
			
			var stat_stages: Dictionary = target.get("stat_stages", {})
			var current_stage: int = stat_stages.get(stat, 0)
			stat_stages[stat] = clampi(current_stage + stages, -6, 6)
			
			var drop_raise: String = "fell!" if stages < 0 else "rose!"
			print("[BattleManager] %s's %s %s's %s %s" % [
				actor.get("species_id", "?"), ability_name, target.get("species_id", "?"), stat.to_upper(), drop_raise
			])
			
		"damage_multiplier":
			var move_data: MoveData = context.get("move_data", null)
			if move_data and move_data.type == params.get("move_type", ""):
				var hp_threshold: float = params.get("hp_threshold", 1.0)
				if float(actor.get("current_hp", 0)) / float(actor.get("max_hp", 1)) <= hp_threshold:
					var current_multiplier: float = context.get("damage_multiplier", 1.0)
					context["damage_multiplier"] = current_multiplier * params.get("multiplier", 1.5)
					print("[BattleManager] %s's %s boosted the attack!" % [actor.get("species_id", "?"), ability_name])
					
		"type_immunity":
			var move_data: MoveData = context.get("move_data", null)
			if move_data and move_data.type == params.get("move_type", ""):
				context["is_immune"] = true
				print("[BattleManager] %s makes %s immune to %s moves!" % [
					ability_name, actor.get("species_id", "?"), params.get("move_type", "")
				])
				
		"status_inflict":
			if params.get("contact_required", false) and not context.get("is_contact", true):
				return
			if randf() <= params.get("chance", 1.0):
				var target_key: String = "opponent" if actor_key == "player" else "player"
				_apply_status(params.get("status", ""), _get_actor_state(target_key), target_key)
				print("[BattleManager] %s's %s inflicted %s!" % [
					actor.get("species_id", "?"), ability_name, params.get("status", "")
				])

		"status_inflict_random":
			if params.get("contact_required", false) and not context.get("is_contact", true):
				return
			if randf() <= params.get("chance", 1.0):
				var statuses: Array = params.get("statuses", [])
				if statuses.size() > 0:
					var picked: Dictionary = statuses[randi() % statuses.size()]
					var target_key: String = "opponent" if actor_key == "player" else "player"
					_apply_status(picked.get("status", ""), _get_actor_state(target_key), target_key)
					print("[BattleManager] %s's %s inflicted %s!" % [
						actor.get("species_id", "?"), ability_name, picked.get("status", "")
					])


# =========================================================================
#  Internal — Signal Handlers
# =========================================================================

func _on_global_ehi_changed(value: float) -> void:
	## Future: adjust wild Pokémon aggression or encounter rates based on global EHI.
	print("[BattleManager] Global EHI changed to %.1f — battle parameters may shift." % value)


func _on_faction_rep_changed(faction: String, value: float) -> void:
	## Future: faction-specific battle bonuses (e.g. Aqua/Magma type bonuses).
	print("[BattleManager] Faction rep update: %s = %.1f" % [faction, value])


func _on_alliance_unlocked() -> void:
	## Alliance unlocked: both factions support the player.
	print("[BattleManager] Alliance unlocked! Dual-faction battle bonuses active.")


# =========================================================================
#  Public Utility — Pokemon Runtime State Builder
# =========================================================================

## Builds a runtime state Dictionary for a Pokémon from its species data + level.
## Use this to prepare Pokémon before passing to start_wild_battle / start_trainer_battle.
## [param species_id] The species ID string.
## [param level] The level for this instance.
## Returns a Dictionary ready for BattleManager use.
func build_pokemon_state(species_id: String, level: int) -> Dictionary:
	var species_data: PokemonData = DataManager.get_pokemon(species_id)
	if species_data == null:
		push_warning("[BattleManager] Couldn't build pokemon state. Bad species id: %s", species_id)
		return {}
		
	var base: Dictionary = species_data.base_stats

	var stats: Dictionary = {
		"hp": int((float(base.get("hp", 45)) * 2.0 * float(level)) / 100.0) + level + 10,
		"atk": int((float(base.get("atk", 45)) * 2.0 * float(level)) / 100.0) + 5,
		"def": int((float(base.get("def", 45)) * 2.0 * float(level)) / 100.0) + 5,
		"spa": int((float(base.get("spa", 45)) * 2.0 * float(level)) / 100.0) + 5,
		"spd": int((float(base.get("spd", 45)) * 2.0 * float(level)) / 100.0) + 5,
		"spe": int((float(base.get("spe", 45)) * 2.0 * float(level)) / 100.0) + 5,
	}
	var max_hp: int = stats["hp"]

	var abilities: Array = species_data.abilities
	var ability_id: String = abilities[0] if abilities.size() > 0 else ""

	# Filter learnset to moves known at the given level.
	var all_moves: Array = species_data.learnset
	var known_moves: Array = all_moves.filter(func(m: Dictionary) -> bool:
		return m.get("method", "level") != "level" or int(m.get("level", 1)) <= level)

	return {
		"species_id": species_id,
		"level": level,
		"exp": 0,
		"max_hp": max_hp,
		"current_hp": max_hp,
		"current_stats": stats,
		"status": "",
		"types": species_data.types,
		"learnset": known_moves,
		"ability_id": ability_id,
		"stat_stages": {
			"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0, "accuracy": 0, "evasion": 0
		},
		"sleep_turns": 0
	}
