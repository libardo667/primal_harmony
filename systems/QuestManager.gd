extends Node

signal flag_changed(flag_id: String, value: bool)

var _flags := {}

func set_flag(flag_id: String, value: bool) -> void:
    _flags[flag_id] = value
    emit_signal("flag_changed", flag_id, value)

func get_flag(flag_id: String) -> bool:
    return _flags.get(flag_id, false)

func toggle_flag(flag_id: String) -> void:
    set_flag(flag_id, not get_flag(flag_id))
    
func clear_all() -> void:
    _flags.clear()
