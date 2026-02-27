## RehabLog — Pokémon Rehabilitation & Release Tracker
##
## Autoload singleton tracking every Pokémon the player releases.
## Milestone releases trigger EHI boosts (coordinated with EHI system).
## Also manages counter-release quelling for Type Overload Zones.
##
## Owner: The Mechanic
## Dependencies: EHI autoload (for milestone boosts)
extends Node

## Emitted when the player releases a Pokémon.
## [param species_id] The released Pokémon's species ID (lowercase_snake_case).
## [param destination_zone] The zone_id the Pokémon was released into.
signal pokemon_released(species_id: String, destination_zone: String)

## Emitted when a release milestone is reached.
## [param milestone] The milestone number hit.
## [param total_releases] Total releases at time of trigger.
signal milestone_reached(milestone: int, total_releases: int)

## Emitted when a counter-release quell event occurs.
## [param zone_id] The zone being quelled.
## [param species_id] The species released as the counter.
## [param quell_progress] New quell progress for that zone (0.0–1.0).
signal zone_quelled(zone_id: String, species_id: String, quell_progress: float)

# =========================================================================
#  Constants
# =========================================================================

## Milestone release counts. Each triggers a milestone_reached signal.
const MILESTONES: Array[int] = [1, 5, 10, 25, 50, 100]

## EHI boost given to the destination zone per native release.
const NATIVE_RELEASE_EHI_BOOST: float = 2.0

## EHI boost for a counter-release quell action.
const QUELL_EHI_BOOST: float = 5.0

## Quell progress per counter-release (0.0–1.0 scale for a zone).
const QUELL_PROGRESS_PER_RELEASE: float = 0.1

# =========================================================================
#  Internal State
# =========================================================================

## Full release history.  Each entry is a Dictionary:
##   { "species_id": String, "destination_zone": String, "timestamp": int,
##     "is_native": bool, "is_quell": bool }
var _log: Array[Dictionary] = []

## Total release count (convenience — equals _log.size()).
var _total_releases: int = 0

## Per-zone quell progress (0.0–1.0). Key: zone_id.
var _quell_progress: Dictionary = {}

## Set of already-triggered milestones (to avoid re-firing).
var _milestones_hit: Array[int] = []


# =========================================================================
#  Lifecycle
# =========================================================================

func _ready() -> void:
	print("[RehabLog] System online. Release log initialized.")


# =========================================================================
#  Public API — Releasing
# =========================================================================

## Records a standard ecological release (native species to their home zone).
## Automatically applies an EHI boost to [param destination_zone].
## [param species_data] The full species Dictionary from DataManager (must
##   include "is_native_hoenn" and optionally "native_zone").
func record_release(species_id: String, destination_zone: String,
		species_data: Dictionary = {}) -> void:
	var is_native: bool = species_data.get("is_native_hoenn", false)

	var entry: Dictionary = {
		"species_id": species_id,
		"destination_zone": destination_zone,
		"timestamp": Time.get_ticks_msec(),
		"is_native": is_native,
		"is_quell": false,
	}
	_log.append(entry)
	_total_releases += 1

	pokemon_released.emit(species_id, destination_zone)
	print("[RehabLog] Released %s → %s (native: %s)" % [species_id, destination_zone, is_native])

	# Apply EHI boost for native releases.
	if is_native:
		EHI.modify_zone_ehi(destination_zone, NATIVE_RELEASE_EHI_BOOST)

	_check_milestones()


## Records a counter-release quell action targeting a Type Overload Zone.
## Applies a quell progress increment and an EHI boost to the zone.
## [param species_id] The species used as the counter.
## [param target_zone] The TOZ being quelled.
func record_quell_release(species_id: String, target_zone: String) -> void:
	var entry: Dictionary = {
		"species_id": species_id,
		"destination_zone": target_zone,
		"timestamp": Time.get_ticks_msec(),
		"is_native": false,
		"is_quell": true,
	}
	_log.append(entry)
	_total_releases += 1

	# Update quell progress.
	if not _quell_progress.has(target_zone):
		_quell_progress[target_zone] = 0.0
	_quell_progress[target_zone] = minf(
		_quell_progress[target_zone] + QUELL_PROGRESS_PER_RELEASE, 1.0
	)

	pokemon_released.emit(species_id, target_zone)
	zone_quelled.emit(target_zone, species_id, _quell_progress[target_zone])
	EHI.modify_zone_ehi(target_zone, QUELL_EHI_BOOST)

	print("[RehabLog] Quell release: %s → %s (progress: %.0f%%)" % [
		species_id, target_zone, _quell_progress[target_zone] * 100.0
	])
	_check_milestones()


# =========================================================================
#  Public API — Queries
# =========================================================================

## Returns total number of releases logged.
func get_total_releases() -> int:
	return _total_releases


## Returns the current quell progress (0.0–1.0) for a zone.
## Returns 0.0 if no quell releases have been made for this zone.
func get_quell_progress(zone_id: String) -> float:
	return _quell_progress.get(zone_id, 0.0)


## Returns [code]true[/code] if a zone is fully quelled (progress = 1.0).
func is_zone_quelled(zone_id: String) -> bool:
	return is_equal_approx(_quell_progress.get(zone_id, 0.0), 1.0)


## Returns all release entries for a given species.
func get_releases_by_species(species_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for entry: Dictionary in _log:
		if entry["species_id"] == species_id:
			results.append(entry)
	return results


## Returns all release entries for a given destination zone.
func get_releases_by_zone(zone_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for entry: Dictionary in _log:
		if entry["destination_zone"] == zone_id:
			results.append(entry)
	return results


## Returns a read-only snapshot of the full release log.
func get_full_log() -> Array[Dictionary]:
	return _log.duplicate()


## Returns a summary Dictionary with high-level stats.
func get_summary() -> Dictionary:
	var native_count: int = 0
	var quell_count: int = 0
	for entry: Dictionary in _log:
		if entry["is_quell"]:
			quell_count += 1
		elif entry["is_native"]:
			native_count += 1

	return {
		"total": _total_releases,
		"native_releases": native_count,
		"quell_releases": quell_count,
		"milestones_hit": _milestones_hit.duplicate(),
	}


# =========================================================================
#  Internal
# =========================================================================

func _check_milestones() -> void:
	for milestone: int in MILESTONES:
		if _total_releases >= milestone and not _milestones_hit.has(milestone):
			_milestones_hit.append(milestone)
			milestone_reached.emit(milestone, _total_releases)
			print("[RehabLog] *** MILESTONE: %d releases reached! ***" % milestone)
