## PhaseOrchestrator — Narrative Phase State Manager
##
## Autoload singleton that tracks the current narrative phase (1–3),
## manages phase transitions with text-card sequences, and persists
## phase state via QuestManager flags.
##
## Phases (from data/narrative/phases.json):
##   1 — Roots       (~age 8,  tutorial-scale, The Holdfast)
##   2 — Pressure    (~age 14, town-scale, Slateport region)
##   3 — Threshold   (~age 20, full game, Kyogre/Groudon crisis)
##
## Usage:
##   PhaseOrchestrator.current_phase          -> int (1, 2, or 3)
##   PhaseOrchestrator.advance_phase()        -> triggers text card + phase_changed signal
##   PhaseOrchestrator.get_current_phase_data() -> Dictionary from phases.json
##
extends Node

## Emitted when a phase transition completes and the new phase is active.
## [param from_phase] The phase that just ended (0 if starting from cold boot).
## [param to_phase]   The phase now active.
signal phase_changed(from_phase: int, to_phase: int)

## Emitted when the text-card transition sequence begins (before screen fade).
## [param card_text] The text shown on screen (e.g. "Six years later.").
signal transition_started(card_text: String)

## Emitted when the text-card transition sequence ends and gameplay resumes.
signal transition_finished()

# ----- Constants -----

const PHASES_DATA_PATH: String = "res://data/narrative/phases.json"
const PHASE_FLAG_PREFIX: String = "phase_"
const PHASE_FLAG_SUFFIX: String = "_started"
const MIN_PHASE: int = 1
const MAX_PHASE: int = 3

# ----- Internal State -----

## The currently active narrative phase (1, 2, or 3).
var current_phase: int = MIN_PHASE

## Raw phase definitions loaded from data/narrative/phases.json.
var _phases: Array = []

## Whether a transition is currently in progress (blocks re-entry).
var _transitioning: bool = false

## Tracks the from/to phases during an in-flight transition.
var _pending_from: int = 0
var _pending_to: int = 0

## Optional reference to PhaseTransitionScreen; set via register_transition_screen().
var _transition_screen: Node = null

# ----- Lifecycle -----

func _ready() -> void:
	_load_phases_data()
	_restore_phase_from_flags()


# ----- Public API -----

## Returns the data dictionary for the current phase.
func get_current_phase_data() -> Dictionary:
	return _get_phase_data(current_phase)


## Returns the data dictionary for a specific phase id (1–3).
func get_phase_data(phase_id: int) -> Dictionary:
	return _get_phase_data(phase_id)


## Returns true if a phase transition is currently in progress.
func is_transitioning() -> bool:
	return _transitioning


## Advances from the current phase to the next, playing the text-card sequence.
## Emits transition_started, waits for the screen (or a short timer), then
## emits phase_changed and transition_finished.
## Does nothing if already at MAX_PHASE or mid-transition.
func advance_phase() -> void:
	if _transitioning:
		return
	if current_phase >= MAX_PHASE:
		return
	_begin_transition(current_phase, current_phase + 1)


## Directly sets the phase without a transition sequence.
## Intended only for save-game restoration and test scaffolding — not for
## normal story progression.
func set_phase_direct(phase_id: int) -> void:
	if phase_id < MIN_PHASE or phase_id > MAX_PHASE:
		push_error("PhaseOrchestrator.set_phase_direct: invalid phase %d" % phase_id)
		return
	var from := current_phase
	current_phase = phase_id
	_persist_phase(phase_id)
	phase_changed.emit(from, current_phase)


## Registers the PhaseTransitionScreen so the orchestrator can show text cards.
## Called by PhaseTransitionScreen._ready(). Connects the screen's
## transition_completed signal back to _on_screen_transition_completed.
func register_transition_screen(screen: Node) -> void:
	_transition_screen = screen
	if screen.has_signal("transition_completed"):
		if not screen.transition_completed.is_connected(_on_screen_transition_completed):
			screen.transition_completed.connect(_on_screen_transition_completed)


# ----- Private -----

func _load_phases_data() -> void:
	var file := FileAccess.open(PHASES_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("PhaseOrchestrator: cannot open %s (error %d)" % [
			PHASES_DATA_PATH, FileAccess.get_open_error()
		])
		return
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("PhaseOrchestrator: failed to parse phases JSON from %s" % PHASES_DATA_PATH)
		return

	var root := parsed as Dictionary
	if not root.has("phases") or not root["phases"] is Array:
		push_error("PhaseOrchestrator: missing 'phases' array in %s" % PHASES_DATA_PATH)
		return

	_phases = root["phases"] as Array


func _restore_phase_from_flags() -> void:
	## Walk phases descending; the highest started flag wins.
	for phase_id: int in range(MAX_PHASE, MIN_PHASE - 1, -1):
		var flag := PHASE_FLAG_PREFIX + str(phase_id) + PHASE_FLAG_SUFFIX
		if QuestManager.get_flag(flag):
			current_phase = phase_id
			return

	## No flags set — fresh game, start at phase 1 and record it.
	current_phase = MIN_PHASE
	_persist_phase(MIN_PHASE)


func _get_phase_data(phase_id: int) -> Dictionary:
	for entry: Variant in _phases:
		if entry is Dictionary and entry.get("id") == phase_id:
			return entry as Dictionary
	return {}


func _persist_phase(phase_id: int) -> void:
	var flag := PHASE_FLAG_PREFIX + str(phase_id) + PHASE_FLAG_SUFFIX
	QuestManager.set_flag(flag, true)


func _begin_transition(from_phase: int, to_phase: int) -> void:
	_transitioning = true
	_pending_from = from_phase
	_pending_to = to_phase
	var target_data := _get_phase_data(to_phase)
	var card_text: String = str(target_data.get("transition_card", ""))

	if card_text.is_empty() or card_text == "null":
		## No text card for this transition — complete immediately.
		_complete_transition(from_phase, to_phase)
		return

	transition_started.emit(card_text)

	if _transition_screen != null and _transition_screen.has_method("play_transition"):
		## Screen will call _on_screen_transition_completed when done.
		_transition_screen.play_transition(card_text)
	else:
		## No screen registered — complete after a minimal delay so callers
		## have one frame to respond to transition_started.
		await get_tree().process_frame
		_complete_transition(from_phase, to_phase)


func _complete_transition(from_phase: int, to_phase: int) -> void:
	current_phase = to_phase
	_persist_phase(to_phase)
	_transitioning = false
	transition_finished.emit()
	phase_changed.emit(from_phase, to_phase)


func _on_screen_transition_completed() -> void:
	## Called by PhaseTransitionScreen.transition_completed signal.
	_complete_transition(_pending_from, _pending_to)
