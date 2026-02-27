## EHI — Ecological Harmony Index
##
## Autoload singleton tracking Hoenn's ecological health.
## Global EHI is the aggregate across all zones.
## Per-zone EHI drives encounter tables, weather, NPC state, and map visuals.
##
## Owner: The Mechanic
extends Node

## Emitted whenever a zone's EHI value changes.
## [param zone_id] The zone whose EHI changed.
## [param value] The new EHI value for that zone.
signal ehi_changed(zone_id: String, value: float)

## Emitted whenever the global EHI is recalculated.
## [param value] The new global EHI value.
signal global_ehi_changed(value: float)

## ----- Constants -----

const EHI_MIN: float = 0.0
const EHI_MAX: float = 100.0
const DEFAULT_ZONE_EHI: float = 30.0 ## Infested baseline — Hoenn starts in crisis

## ----- Internal State -----

## Aggregate EHI across all registered zones.
var _global_ehi: float = 0.0

## Per-zone EHI values.  Key: zone_id (String) → Value: float (0–100).
var _zone_ehi: Dictionary = {}


# =========================================================================
#  Lifecycle
# =========================================================================

func _ready() -> void:
	print("[EHI] System online. No zones registered yet.")


# =========================================================================
#  Public API
# =========================================================================

## Returns the current global EHI (0–100).
func get_global_ehi() -> float:
	return _global_ehi


## Returns the EHI for a specific zone, or [code]DEFAULT_ZONE_EHI[/code] if the
## zone has not been registered yet.
func get_zone_ehi(zone_id: String) -> float:
	if _zone_ehi.has(zone_id):
		return _zone_ehi[zone_id]
	return DEFAULT_ZONE_EHI


## Registers a zone with an optional starting EHI.
## If the zone already exists, this is a no-op.
func register_zone(zone_id: String, initial_value: float = DEFAULT_ZONE_EHI) -> void:
	if _zone_ehi.has(zone_id):
		return
	_zone_ehi[zone_id] = clampf(initial_value, EHI_MIN, EHI_MAX)
	_recalculate_global()
	print("[EHI] Zone registered: %s (EHI = %.1f)" % [zone_id, _zone_ehi[zone_id]])


## Modifies a zone's EHI by [param delta]. Positive values heal, negative values
## degrade. The value is clamped to [0, 100]. Emits [signal ehi_changed].
## Automatically registers the zone if it doesn't exist yet.
func modify_zone_ehi(zone_id: String, delta: float) -> void:
	if not _zone_ehi.has(zone_id):
		register_zone(zone_id)

	var old_value: float = _zone_ehi[zone_id]
	var new_value: float = clampf(old_value + delta, EHI_MIN, EHI_MAX)
	_zone_ehi[zone_id] = new_value

	if not is_equal_approx(old_value, new_value):
		ehi_changed.emit(zone_id, new_value)
		_recalculate_global()
		print("[EHI] Zone %s: %.1f → %.1f (Δ%.1f)" % [zone_id, old_value, new_value, delta])


## Sets a zone's EHI to an absolute value (clamped).
func set_zone_ehi(zone_id: String, value: float) -> void:
	if not _zone_ehi.has(zone_id):
		register_zone(zone_id)

	var old_value: float = _zone_ehi[zone_id]
	var new_value: float = clampf(value, EHI_MIN, EHI_MAX)
	_zone_ehi[zone_id] = new_value

	if not is_equal_approx(old_value, new_value):
		ehi_changed.emit(zone_id, new_value)
		_recalculate_global()


## Returns the number of registered zones.
func get_zone_count() -> int:
	return _zone_ehi.size()


## Returns all zone IDs currently registered.
func get_all_zone_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: String in _zone_ehi.keys():
		ids.append(key)
	return ids


## Returns a read-only snapshot of all zone EHI values.
func get_all_zone_data() -> Dictionary:
	return _zone_ehi.duplicate()


# =========================================================================
#  Internal
# =========================================================================

## Recalculates the global EHI as the mean of all per-zone values.
func _recalculate_global() -> void:
	if _zone_ehi.is_empty():
		_global_ehi = 0.0
		return

	var total: float = 0.0
	for value: float in _zone_ehi.values():
		total += value

	var old_global: float = _global_ehi
	_global_ehi = total / float(_zone_ehi.size())

	if not is_equal_approx(old_global, _global_ehi):
		global_ehi_changed.emit(_global_ehi)
