extends CanvasLayer

signal dialogue_started
signal dialogue_finished

var _lines := []
var _current_line_idx := 0
var _is_active := false

var _bg_rect: TextureRect
var _speaker_label: Label
var _text_label: RichTextLabel

func _ready() -> void:
    layer = 100 # High layer to render on top of everything
    visible = false
    
    # We'll use a Panel for scaling flexibility, in case the texture is 320x64 fixed.
    _bg_rect = TextureRect.new()
    var tex = load("res://assets/sprites/ui/battle_interface/textbox.png") as Texture2D
    if tex:
        _bg_rect.texture = tex
    _bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    
    _bg_rect.custom_minimum_size = Vector2(0, 80)
    _bg_rect.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _bg_rect.offset_top = -80
    _bg_rect.offset_bottom = 0
    _bg_rect.offset_left = 8
    _bg_rect.offset_right = -8
    add_child(_bg_rect)
    
    _speaker_label = Label.new()
    _speaker_label.position = Vector2(12, 8)
    _speaker_label.size = Vector2(304, 20)
    _speaker_label.add_theme_color_override("font_color", Color.AQUA)
    _bg_rect.add_child(_speaker_label)
    
    _text_label = RichTextLabel.new()
    _text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    _text_label.offset_left = 12
    _text_label.offset_top = 28
    _text_label.offset_right = -12
    _text_label.offset_bottom = -8
    _text_label.bbcode_enabled = true
    _text_label.scroll_active = false
    _text_label.fit_content = true
    _bg_rect.add_child(_text_label)
    
    # Crucial: Allow the dialogue manager to process inputs while the game is paused
    process_mode = Node.PROCESS_MODE_ALWAYS

func play_dialogue(lines: Array, speaker: String = "") -> void:
    if lines.is_empty():
        return
    
    _lines = lines
    _current_line_idx = 0
    _is_active = true
    
    if speaker != "":
        _speaker_label.text = speaker
        _speaker_label.visible = true
    else:
        _speaker_label.visible = false
        
    _show_current_line()
    visible = true
    
    get_tree().paused = true # Pause the game while talking
    emit_signal("dialogue_started")

func _show_current_line() -> void:
    _text_label.text = _lines[_current_line_idx]

func _input(event: InputEvent) -> void:
    if not _is_active:
        return

    if event.is_action_pressed("ui_accept"):
        get_viewport().set_input_as_handled()
        _current_line_idx += 1
        if _current_line_idx >= _lines.size():
            _finish_dialogue()
        else:
            _show_current_line()

func _finish_dialogue() -> void:
    _is_active = false
    visible = false
    get_tree().paused = false
    emit_signal("dialogue_finished")
