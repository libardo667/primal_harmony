## PhaseTransitionCard — Full-screen text card for phase/story transitions.
##
## Fades in a black overlay with centered text, holds briefly, then fades out.
## Used for beats like "Six years later." between narrative phases.
## Pauses the scene tree for its full duration. Self-queues free on completion.
##
## Usage:
##   var card := PhaseTransitionCard.new()
##   get_tree().root.add_child(card)
##   card.transition_done.connect(_on_card_done, CONNECT_ONE_SHOT)
##   card.play("Six years later.")
extends CanvasLayer

# =========================================================================
#  Signals
# =========================================================================

signal transition_done

# =========================================================================
#  Timing Constants
# =========================================================================

const FADE_IN_DURATION: float  = 0.6
const HOLD_DURATION: float     = 2.5
const FADE_OUT_DURATION: float = 0.6

# =========================================================================
#  Internal Nodes
# =========================================================================

var _bg: ColorRect = null
var _label: Label   = null

# =========================================================================
#  Lifecycle
# =========================================================================

func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.0)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.modulate.a = 0.0
	_bg.add_child(_label)


# =========================================================================
#  Public API
# =========================================================================

## Plays the full fade-in → hold → fade-out sequence with [param text] centred.
## Emits [signal transition_done] when complete and frees the node.
func play(text: String) -> void:
	_label.text = text
	get_tree().paused = true

	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)

	# Fade in background and text simultaneously.
	tween.tween_property(_bg, "color:a", 1.0, FADE_IN_DURATION)
	tween.parallel().tween_property(_label, "modulate:a", 1.0, FADE_IN_DURATION)

	# Hold.
	tween.tween_interval(HOLD_DURATION)

	# Fade out.
	tween.tween_property(_bg, "color:a", 0.0, FADE_OUT_DURATION)
	tween.parallel().tween_property(_label, "modulate:a", 0.0, FADE_OUT_DURATION)

	tween.tween_callback(_finish)


# =========================================================================
#  Internal
# =========================================================================

func _finish() -> void:
	get_tree().paused = false
	transition_done.emit()
	queue_free()
