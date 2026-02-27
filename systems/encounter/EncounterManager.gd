## EncounterManager — Dynamic Wild Encounter System
##
## Autoload singleton that reads zone encounter tables from data/zones/ JSON.
## Filters encounter tables by local EHI state and rolls weighted random encounters.
## Fully data-driven — does not hardcode any species or encounter rates.
##
## Owner: The Mechanic
## Dependencies: DataManager (zone data), EHI (local zone EHI query)
extends Node

## Emitted when an encounter is triggered.
## [param pokemon_data] A Dictionary containing the species data + encounter context:
##   { "species_id", "species_data" (from DataManager), "level", "zone_id",
##     "ehi_state", "time_of_day" }
signal encounter_triggered(pokemon_data: Dictionary)

# =========================================================================
#  Constants
# =========================================================================

## EHI thresholds defining encounter state bands.
const EHI_INFESTED_MAX: float = 35.0
const EHI_PARTIAL_MAX: float = 70.0
# Above EHI_PARTIAL_MAX = restored

## Repel step budget (steps before a repel wears off).
const REPEL_DURATION: int = 100

# =========================================================================
#  Internal State
# =========================================================================

## Cached zone data from DataManager. Refreshed on first access or explicitly.
var _zone_cache: Dictionary = {}

## Whether zone data has been loaded from DataManager.
var _zones_loaded: bool = false

## Repel steps remaining. 0 = no repel active.
var _repel_steps: int = 0


# =========================================================================
#  Lifecycle
# =========================================================================

func _ready() -> void:
	print("[EncounterManager] System online.")
	_load_zones()


# =========================================================================
#  Public API — Encounter Generation
# =========================================================================

## Attempts to trigger a wild encounter in [param zone_id] at the current EHI.
## Returns [code]true[/code] if an encounter was triggered and the signal fired.
## Returns [code]false[/code] if no valid encounter entries exist, or a repel
## is active and the rolled Pokémon is too low level.
## [param step_encounter_rate] Probability of encounter per step (0.0–1.0).
func try_encounter(zone_id: String, step_encounter_rate: float = 0.1) -> bool:
	# Repel check.
	if _repel_steps > 0:
		_repel_steps -= 1
		# Repel suppresses encounter roll — will still roll but block low-level entries.
		# (Full repel level check happens after species selection.)

	if randf() > step_encounter_rate:
		return false

	var table: Array = _get_encounter_table(zone_id)
	if table.is_empty():
		push_warning("[EncounterManager] No encounter entries for zone: %s" % zone_id)
		return false

	# Filter by time of day.
	var time_key: String = _get_time_of_day()
	var filtered: Array = _filter_by_time(table, time_key)
	if filtered.is_empty():
		filtered = table # Fallback: ignore time filter if nothing passes.

	# Weighted random selection.
	var entry: Dictionary = _weighted_roll(filtered)
	if entry.is_empty():
		return false

	# Roll level within range.
	var level_range: Array = entry.get("level_range", [5, 10])
	var level: int = randi_range(level_range[0], level_range[1])

	# Repel: block encounters below player level (simplified: block if level < 5).
	# Full implementation will compare against lead Pokémon level once BattleManager exists.
	if _repel_steps > 0 and level < 5:
		return false

	var species_id: String = entry.get("species_id", "")
	var species_data: PokemonData = DataManager.get_pokemon(species_id)
	var ehi_state: String = _get_ehi_state(zone_id)

	var pokemon_data: Dictionary = {
		"species_id": species_id,
		"species_data": species_data,
		"level": level,
		"zone_id": zone_id,
		"ehi_state": ehi_state,
		"time_of_day": time_key,
	}

	encounter_triggered.emit(pokemon_data)
	print("[EncounterManager] ⚡ Encounter! %s (Lv.%d) in %s [%s]" % [
		species_id, level, zone_id, ehi_state
	])
	return true


## Returns the encounter table for [param zone_id] filtered to the current EHI state.
## Returns an empty Array if zone data is unavailable.
func get_current_table(zone_id: String) -> Array:
	return _get_encounter_table(zone_id)


## Returns the EHI state label for a zone: "infested", "partial", or "restored".
func get_zone_ehi_state(zone_id: String) -> String:
	return _get_ehi_state(zone_id)


## Returns the dominant type of a zone (for quell logic), or "" if unknown.
func get_zone_dominant_type(zone_id: String) -> String:
	var zone_data: ZoneData = _get_zone_data(zone_id)
	if zone_data != null:
		return zone_data.dominant_type
	return ""


## Returns the quell_types Array for a zone (types effective for counter-release).
func get_zone_quell_types(zone_id: String) -> Array:
	var zone_data: ZoneData = _get_zone_data(zone_id)
	if zone_data != null:
		return zone_data.quell_types
	return []


## Returns the native_species Array for a zone.
func get_zone_native_species(zone_id: String) -> Array:
	var zone_data: ZoneData = _get_zone_data(zone_id)
	if zone_data != null:
		return zone_data.native_species
	return []


## Returns the corrupted_variants Array for a zone (invasive species eligible for triage-catch).
func get_zone_corrupted_variants(zone_id: String) -> Array:
	var zone_data: ZoneData = _get_zone_data(zone_id)
	if zone_data != null:
		return zone_data.corrupted_variants
	return []


## Returns the initial EHI value for a zone as specified in its data file.
## Used by MainGame to seed EHI on first map load.
func get_zone_initial_ehi(zone_id: String) -> float:
	var zone_data: ZoneData = _get_zone_data(zone_id)
	if zone_data != null:
		return zone_data.ehi_local
	return EHI.DEFAULT_ZONE_EHI


## Activates a repel for [param steps] steps.
func apply_repel(steps: int) -> void:
	_repel_steps = steps
	print("[EncounterManager] Repel active for %d steps." % steps)


## Returns remaining repel steps.
func get_repel_steps() -> int:
	return _repel_steps


## Forces zone data to reload from DataManager (call after DataManager is fully loaded).
func reload_zones() -> void:
	_zone_cache.clear()
	_zones_loaded = false
	_load_zones()


# =========================================================================
#  Internal — Data Loading
# =========================================================================

func _load_zones() -> void:
	if _zones_loaded:
		return

	var all_zone_ids: Array = DataManager.get_all_zone_ids()
	if all_zone_ids.is_empty():
		push_warning("[EncounterManager] DataManager has no zone data. Encounter tables unavailable.")
		return

	for zone_id: String in all_zone_ids:
		_zone_cache[zone_id] = DataManager.get_zone(zone_id)

	_zones_loaded = true
	print("[EncounterManager] Loaded %d zone(s): %s" % [
		_zone_cache.size(), ", ".join(Array(_zone_cache.keys()))
	])


func _get_zone_data(zone_id: String) -> ZoneData:
	if not _zones_loaded:
		_load_zones()
	if _zone_cache.has(zone_id):
		return _zone_cache[zone_id]
	push_warning("[EncounterManager] Zone data not found: %s" % zone_id)
	return null


# =========================================================================
#  Internal — Encounter Logic
# =========================================================================

func _get_ehi_state(zone_id: String) -> String:
	var ehi: float = EHI.get_zone_ehi(zone_id)
	if ehi <= EHI_INFESTED_MAX:
		return "infested"
	elif ehi <= EHI_PARTIAL_MAX:
		return "partial"
	else:
		return "restored"


func _get_encounter_table(zone_id: String) -> Array:
	var zone_data: ZoneData = _get_zone_data(zone_id)
	if zone_data == null:
		return []

	var encounter_table: Dictionary = zone_data.encounter_table
	var state: String = _get_ehi_state(zone_id)
	return encounter_table.get(state, [])


func _filter_by_time(table: Array, time_key: String) -> Array:
	var result: Array = []
	for entry: Dictionary in table:
		var tod: Variant = entry.get("time_of_day", null)
		if tod == null or tod == "any" or tod == time_key:
			result.append(entry)
	return result


func _weighted_roll(table: Array) -> Dictionary:
	if table.is_empty():
		return {}

	var total_weight: int = 0
	for entry: Dictionary in table:
		total_weight += entry.get("weight", 1)

	if total_weight <= 0:
		return table[0]

	var roll: int = randi_range(0, total_weight - 1)
	var cumulative: int = 0
	for entry: Dictionary in table:
		cumulative += entry.get("weight", 1)
		if roll < cumulative:
			return entry

	return table[table.size() - 1] # Fallback.


func _get_time_of_day() -> String:
	# TODO: Replace with actual day/night cycle hook once implemented.
	var hour: int = Time.get_datetime_dict_from_system().get("hour", 12)
	if hour >= 6 and hour < 20:
		return "day"
	return "night"
