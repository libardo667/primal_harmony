class_name AbilityData extends RefCounted

var id: String
var name: String
var description: String
var hooks: Array = []

func _init(data: Dictionary) -> void:
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	hooks = data.get("hooks", [])
