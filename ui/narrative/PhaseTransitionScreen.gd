## PhaseTransitionScreen — Full-screen text card for narrative phase transitions.
##
## A CanvasLayer (layer=250, above all other UI) that:
##   1. Fades in a black screen with centred text ("Six years later.").
##   2. Holds the card for a beat.
##   3. Fades back out.
##   4. Emits transition_completed so PhaseOrchestrator can finalise the phase.
##
## Instantiate once (e.g. from MainGame._ready()) and leave in the tree.
## The scene is invisible by default and shows only during transitions.
##
extends CanvasLayer

## Emitted after the full fade-in → hold → fade-out sequence completes.
signal transition_completed()

# ----- Timing constants (seconds) -----

const FADE_IN_DURATION: float = 1.0
const HOLD_DURATION: float = 2.5
const FADE_OUT_DURATION: float = 1.0

# ----- Node references (assigned in _ready) -----

var _background: ColorRect = null
var _label: Label = null
var _tween: Tween = null

# ----- Lifecycle -----

func _ready() -> void:
	_background = $Background
	_label = $CardLabel
	visible = false
	PhaseOrchestrator.register_transition_screen(self)


# ----- Public API -----

## Begin the text-card sequence for the given card text.
## Called by PhaseOrchestrator._begin_transition() when a screen is registered.
func play_transition(card_text: String) -> void:
	_label.text = card_text
	_background.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	visible = true

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(false)

	## Fade in background then label together.
	_tween.tween_property(_background, "modulate:a", 1.0, FADE_IN_DURATION)
	_tween.parallel().tween_property(_label, "modulate:a", 1.0, FADE_IN_DURATION)

	## Hold.
	_tween.tween_interval(HOLD_DURATION)

	## Fade out label then background together.
	_tween.tween_property(_label, "modulate:a", 0.0, FADE_OUT_DURATION)
	_tween.parallel().tween_property(_background, "modulate:a", 0.0, FADE_OUT_DURATION)

	_tween.tween_callback(_on_sequence_finished)


# ----- Private -----

func _on_sequence_finished() -> void:
	visible = false
	transition_completed.emit()
