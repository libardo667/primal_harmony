## TriageChoiceMenu — Keyboard-navigable triage catch choice overlay.
##
## Visually matches DialogueManager: textbox.png backing panel anchored to the
## bottom of the screen, text ► cursor, arrow-key navigation, ui_accept to
## confirm, ui_cancel to flee.
##
## Usage:
##   var menu := TriageChoiceMenu.new()
##   add_child(menu)
##   menu.choice_made.connect(_on_triage_choice)
##   menu.show_menu(species_display_name, level)
##   # — or after dialogue finishes —
##   menu.show_menu_bare()          # no species line; just the option list
##
## Signal:
##   choice_made(choice: String)   # "catch" | "battle" | "flee"
##
## The menu pauses the scene tree while open and unpauses on selection.
extends CanvasLayer

# =========================================================================
#  Signals
# =========================================================================

signal choice_made(choice: String)

# =========================================================================
#  Constants
# =========================================================================

const TEXTBOX := preload("res://assets/sprites/ui/battle_interface/textbox.png")

const OPTIONS: Array = [
	{"key": "catch",  "label": "Catch  (Triage)"},
	{"key": "battle", "label": "Battle"},
	{"key": "flee",   "label": "Flee"},
]

# =========================================================================
#  State
# =========================================================================

var _cursor_idx: int = 0
var _cursor_labels: Array[Label] = []

# =========================================================================
#  Lifecycle
# =========================================================================

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _build_ui() -> void:
	# ── Backing panel (textbox.png, full-width bottom, 90 px tall) ──────────
	var bg := TextureRect.new()
	bg.texture = TEXTBOX
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bg.offset_top    = -90
	bg.offset_bottom =   0
	bg.offset_left   =   8
	bg.offset_right  =  -8
	add_child(bg)

	# ── "What will you do?" header ──────────────────────────────────────────
	var header := Label.new()
	header.text = "What will you do?"
	header.position = Vector2(12, 6)
	header.add_theme_color_override("font_color", Color.WHITE)
	bg.add_child(header)

	# ── Option rows (► cursor + label) ─────────────────────────────────────
	for i: int in range(OPTIONS.size()):
		var row := HBoxContainer.new()
		row.position = Vector2(24, 30 + i * 18)
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

## Show the menu, optionally with a one-line encounter header inside the panel.
func show_menu() -> void:
	_cursor_idx = 0
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
		# Cancel = flee.
		_cursor_idx = OPTIONS.size() - 1  # "flee" is last
		_confirm()
		get_viewport().set_input_as_handled()


# =========================================================================
#  Internal
# =========================================================================

func _confirm() -> void:
	visible = false
	get_tree().paused = false
	var choice: String = OPTIONS[_cursor_idx]["key"]
	choice_made.emit(choice)


func _refresh_cursor() -> void:
	for i: int in range(_cursor_labels.size()):
		_cursor_labels[i].modulate.a = 1.0 if i == _cursor_idx else 0.0
