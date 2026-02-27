## YesNoMenu — Keyboard-navigable yes/no confirmation overlay.
##
## Shares the textbox.png aesthetic with DialogueManager and TriageChoiceMenu.
## Pauses the scene tree while open; self-queues free after selection.
##
## Usage:
##   var menu := YesNoMenu.new()
##   get_tree().root.add_child(menu)
##   menu.confirmed.connect(_on_yes, CONNECT_ONE_SHOT)
##   menu.cancelled.connect(_on_no, CONNECT_ONE_SHOT)
##   menu.show_prompt("Rehabilitate this Pokémon?")
extends CanvasLayer

# =========================================================================
#  Signals
# =========================================================================

signal confirmed
signal cancelled

# =========================================================================
#  Constants
# =========================================================================

const TEXTBOX := preload("res://assets/sprites/ui/battle_interface/textbox.png")

const OPTIONS: Array = [
	{"key": "yes", "label": "Yes"},
	{"key": "no",  "label": "No"},
]

# =========================================================================
#  State
# =========================================================================

var _cursor_idx: int = 0
var _cursor_labels: Array[Label] = []
var _question_label: Label = null

# =========================================================================
#  Lifecycle
# =========================================================================

func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = TEXTBOX
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bg.offset_top    = -90
	bg.offset_bottom =   0
	bg.offset_left   =   8
	bg.offset_right  =  -8
	add_child(bg)

	_question_label = Label.new()
	_question_label.text = ""
	_question_label.position = Vector2(12, 8)
	_question_label.add_theme_color_override("font_color", Color.WHITE)
	bg.add_child(_question_label)

	for i: int in range(OPTIONS.size()):
		var row := HBoxContainer.new()
		row.position = Vector2(24, 36 + i * 22)
		bg.add_child(row)

		var cursor := Label.new()
		cursor.text = "► "
		cursor.custom_minimum_size = Vector2(20, 0)
		cursor.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(cursor)
		_cursor_labels.append(cursor)

		var opt := Label.new()
		opt.text = OPTIONS[i]["label"]
		opt.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(opt)

	_refresh_cursor()


# =========================================================================
#  Public API
# =========================================================================

func show_prompt(question: String) -> void:
	_cursor_idx = 0
	_question_label.text = question
	_refresh_cursor()
	visible = true
	get_tree().paused = true


# =========================================================================
#  Input
# =========================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_cursor_idx = (_cursor_idx - 1 + OPTIONS.size()) % OPTIONS.size()
		_refresh_cursor()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_cursor_idx = (_cursor_idx + 1) % OPTIONS.size()
		_refresh_cursor()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_accept"):
		_confirm()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel"):
		_cursor_idx = 1  # "No" is index 1
		_confirm()
		get_viewport().set_input_as_handled()


# =========================================================================
#  Internal
# =========================================================================

func _confirm() -> void:
	visible = false
	get_tree().paused = false
	if OPTIONS[_cursor_idx]["key"] == "yes":
		confirmed.emit()
	else:
		cancelled.emit()
	queue_free()


func _refresh_cursor() -> void:
	for i: int in range(_cursor_labels.size()):
		_cursor_labels[i].modulate.a = 1.0 if i == _cursor_idx else 0.0
