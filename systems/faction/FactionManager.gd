## FactionManager — Team Aqua & Team Magma Reputation System
##
## Autoload singleton tracking the player's standing with both factions.
## Certain thresholds gate story events and the final alliance arc.
##
## Owner: The Mechanic
extends Node

## Emitted when either faction's reputation changes.
## [param faction] "aqua" or "magma".
## [param value] The new reputation value.
signal faction_rep_changed(faction: String, value: float)

## Emitted when the alliance becomes possible (both factions ≥ threshold).
signal alliance_unlocked()

# ----- Constants -----

const REP_MIN: float = 0.0
const REP_MAX: float = 100.0
const DEFAULT_REP: float = 25.0

## Both factions must reach this threshold for the final alliance arc.
const ALLIANCE_THRESHOLD: float = 75.0

## Story-gate thresholds that other systems can reference.
const THRESHOLDS: Dictionary = {
	"distrust": 0.0,
	"neutral": 25.0,
	"friendly": 50.0,
	"trusted": 75.0,
	"bonded": 100.0,
}

## Default tension factor — when one faction gains, the other loses this fraction.
## Set to 0.0 to disable tension.  0.25 means a +10 Aqua action costs −2.5 Magma.
const DEFAULT_TENSION: float = 0.25

# ----- Internal State -----

var _aqua_rep: float = DEFAULT_REP
var _magma_rep: float = DEFAULT_REP
var _alliance_unlocked: bool = false


# =========================================================================
#  Lifecycle
# =========================================================================

func _ready() -> void:
	print("[FactionManager] System online. Aqua: %.1f  Magma: %.1f" % [_aqua_rep, _magma_rep])


# =========================================================================
#  Public API
# =========================================================================

## Returns the reputation value for the given faction ("aqua" or "magma").
func get_rep(faction: String) -> float:
	match faction:
		"aqua":
			return _aqua_rep
		"magma":
			return _magma_rep
		_:
			push_error("[FactionManager] Unknown faction: %s" % faction)
			return 0.0


## Modifies a faction's rep by [param delta].
## If [param tension_factor] ≥ 0, the opposing faction is penalised by
## [code]delta * tension_factor[/code] (negative mirror).
## Pass [code]tension_factor = 0.0[/code] for rep changes with no cross-effect.
## Pass [code]tension_factor = -1.0[/code] to use the default tension constant.
func modify_rep(faction: String, delta: float, tension_factor: float = -1.0) -> void:
	var actual_tension: float = DEFAULT_TENSION if tension_factor < 0.0 else tension_factor

	match faction:
		"aqua":
			_set_aqua_rep(_aqua_rep + delta)
			if actual_tension > 0.0 and not is_zero_approx(delta):
				_set_magma_rep(_magma_rep - delta * actual_tension)
		"magma":
			_set_magma_rep(_magma_rep + delta)
			if actual_tension > 0.0 and not is_zero_approx(delta):
				_set_aqua_rep(_aqua_rep - delta * actual_tension)
		_:
			push_error("[FactionManager] Unknown faction: %s" % faction)
			return

	_check_alliance()


## Returns [code]true[/code] if both factions are at or above the alliance threshold.
func get_alliance_ready() -> bool:
	return _aqua_rep >= ALLIANCE_THRESHOLD and _magma_rep >= ALLIANCE_THRESHOLD


## Returns the named tier for a given faction's current rep value.
func get_rep_tier(faction: String) -> String:
	var rep: float = get_rep(faction)
	if rep >= THRESHOLDS["bonded"]:
		return "bonded"
	elif rep >= THRESHOLDS["trusted"]:
		return "trusted"
	elif rep >= THRESHOLDS["friendly"]:
		return "friendly"
	elif rep >= THRESHOLDS["neutral"]:
		return "neutral"
	else:
		return "distrust"


## Returns a read-only snapshot of both faction reps.
func get_all_rep_data() -> Dictionary:
	return {
		"aqua": _aqua_rep,
		"magma": _magma_rep,
		"alliance_ready": get_alliance_ready(),
	}


# =========================================================================
#  Internal
# =========================================================================

func _set_aqua_rep(value: float) -> void:
	var old: float = _aqua_rep
	_aqua_rep = clampf(value, REP_MIN, REP_MAX)
	if not is_equal_approx(old, _aqua_rep):
		faction_rep_changed.emit("aqua", _aqua_rep)
		print("[FactionManager] Aqua rep: %.1f → %.1f" % [old, _aqua_rep])


func _set_magma_rep(value: float) -> void:
	var old: float = _magma_rep
	_magma_rep = clampf(value, REP_MIN, REP_MAX)
	if not is_equal_approx(old, _magma_rep):
		faction_rep_changed.emit("magma", _magma_rep)
		print("[FactionManager] Magma rep: %.1f → %.1f" % [old, _magma_rep])


func _check_alliance() -> void:
	if not _alliance_unlocked and get_alliance_ready():
		_alliance_unlocked = true
		alliance_unlocked.emit()
		print("[FactionManager] *** ALLIANCE UNLOCKED — Both factions at %.1f+ ***" % ALLIANCE_THRESHOLD)
