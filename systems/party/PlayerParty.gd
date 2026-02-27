## PlayerParty — Player's Active Pokémon Party
##
## Autoload singleton holding the player's team (up to 6 Pokémon) and
## the rehab box (caught invasive Pokémon awaiting release).
##
## Party slots store runtime state Dictionaries built by BattleManager.build_pokemon_state().
## The rehab box stores the same format, keyed by species_id, with an additional
## "origin_zone" field for RehabLog tracking.
##
## Usage:
##   PlayerParty.add_to_party("scleecko", 5)
##   PlayerParty.add_to_rehab_box("venomish", 8, "the_murk")
##   var active := PlayerParty.get_active()
extends Node

# =========================================================================
#  Signals
# =========================================================================

## Emitted when a Pokémon is added to the player's party.
signal party_changed(party: Array)

## Emitted when a Pokémon is moved to the rehab box.
signal rehab_box_changed(rehab_box: Array)

## Emitted when the active (lead) party slot changes.
signal active_slot_changed(index: int)

# =========================================================================
#  Constants
# =========================================================================

const PARTY_MAX: int = 6

# =========================================================================
#  Internal State
# =========================================================================

## Up to 6 runtime state Dictionaries (from BattleManager.build_pokemon_state).
var _party: Array[Dictionary] = []

## Caught invasive / corrupted Pokémon awaiting release.
## Each entry: build_pokemon_state dict + "origin_zone": String + "caught_at": int (msec).
var _rehab_box: Array[Dictionary] = []

## Index of the active (lead) Pokémon in _party.
var _active_slot: int = 0


# =========================================================================
#  Lifecycle
# =========================================================================

func _ready() -> void:
	print("[PlayerParty] System online. Party capacity: %d." % PARTY_MAX)


# =========================================================================
#  Public API — Party Management
# =========================================================================

## Builds a runtime state and adds it to the player's party.
## Returns true if successful, false if the party is full.
func add_to_party(species_id: String, level: int) -> bool:
	if _party.size() >= PARTY_MAX:
		push_warning("[PlayerParty] Party full — cannot add %s." % species_id)
		return false
	var state: Dictionary = BattleManager.build_pokemon_state(species_id, level)
	if state.is_empty():
		push_warning("[PlayerParty] build_pokemon_state failed for %s." % species_id)
		return false
	_party.append(state)
	party_changed.emit(_party.duplicate(true))
	print("[PlayerParty] Added %s (Lv.%d) to party. Party size: %d." % [species_id, level, _party.size()])
	return true


## Removes the Pokémon at [param index] from the party.
## Adjusts the active slot if needed.
func remove_from_party(index: int) -> bool:
	if index < 0 or index >= _party.size():
		return false
	var removed: Dictionary = _party[index]
	_party.remove_at(index)
	if _active_slot >= _party.size():
		_active_slot = max(0, _party.size() - 1)
	party_changed.emit(_party.duplicate(true))
	print("[PlayerParty] Removed %s from party." % removed.get("species_id", "?"))
	return true


## Swaps the positions of two party slots.
func swap_party_slots(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= _party.size() or b >= _party.size():
		return
	var temp: Dictionary = _party[a]
	_party[a] = _party[b]
	_party[b] = temp
	party_changed.emit(_party.duplicate(true))


## Sets the active (lead) party slot. Clamps to valid range.
func set_active_slot(index: int) -> void:
	_active_slot = clampi(index, 0, max(0, _party.size() - 1))
	active_slot_changed.emit(_active_slot)


## Returns the active Pokémon runtime state, or an empty Dictionary if party is empty.
func get_active() -> Dictionary:
	if _party.is_empty():
		return {}
	return _party[_active_slot].duplicate(true)


## Returns the full party as a read-only snapshot.
func get_party() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry: Dictionary in _party:
		copy.append(entry.duplicate(true))
	return copy


## Returns true if the player has at least one Pokémon with HP > 0.
func has_usable_pokemon() -> bool:
	for entry: Dictionary in _party:
		if entry.get("current_hp", 0) > 0:
			return true
	return false


## Returns the number of Pokémon currently in the party.
func get_party_size() -> int:
	return _party.size()


## Updates the runtime state of the active Pokémon in-place (e.g. after a battle).
func update_active_state(new_state: Dictionary) -> void:
	if _party.is_empty():
		return
	_party[_active_slot] = new_state
	party_changed.emit(_party.duplicate(true))


# =========================================================================
#  Public API — Rehab Box
# =========================================================================

## Adds a caught invasive/corrupted Pokémon to the rehab box.
## [param origin_zone] is the zone_id where it was caught (for RehabLog tracking).
func add_to_rehab_box(species_id: String, level: int, origin_zone: String) -> void:
	var state: Dictionary = BattleManager.build_pokemon_state(species_id, level)
	if state.is_empty():
		push_warning("[PlayerParty] build_pokemon_state failed for rehab entry: %s." % species_id)
		return
	state["origin_zone"] = origin_zone
	state["caught_at"] = Time.get_ticks_msec()
	_rehab_box.append(state)
	rehab_box_changed.emit(_rehab_box.duplicate(true))
	print("[PlayerParty] Rehab box: added %s (Lv.%d) from zone '%s'. Box size: %d." % [
		species_id, level, origin_zone, _rehab_box.size()
	])


## Returns a read-only snapshot of the rehab box.
func get_rehab_box() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry: Dictionary in _rehab_box:
		copy.append(entry.duplicate(true))
	return copy


## Removes a Pokémon from the rehab box at [param index] and returns it.
## Returns an empty Dictionary if index is invalid.
func take_from_rehab_box(index: int) -> Dictionary:
	if index < 0 or index >= _rehab_box.size():
		return {}
	var entry: Dictionary = _rehab_box[index]
	_rehab_box.remove_at(index)
	rehab_box_changed.emit(_rehab_box.duplicate(true))
	return entry


## Returns the number of Pokémon in the rehab box.
func get_rehab_box_size() -> int:
	return _rehab_box.size()
