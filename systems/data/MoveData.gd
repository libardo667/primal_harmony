class_name MoveData extends RefCounted

var id: String
var name: String
var type: String
var category: String
var power: Variant # int or null
var accuracy: Variant # int or null
var pp: int
var priority: int
var target: String
var effect: Variant # String or null
var flags: Array[String] = []
var description: String
var is_custom: bool

func _init(data: Dictionary) -> void:
	id = data.get("id", "")
	name = data.get("name", "")
	type = data.get("type", "")
	category = data.get("category", "")
	power = data.get("power", null)
	accuracy = data.get("accuracy", null)
	pp = data.get("pp", 0)
	priority = data.get("priority", 0)
	target = data.get("target", "")
	effect = data.get("effect", null)
	
	for f in data.get("flags", []):
		flags.append(f)
		
	description = data.get("description", "")
	is_custom = data.get("is_custom", false)
