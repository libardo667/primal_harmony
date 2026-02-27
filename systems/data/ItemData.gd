class_name ItemData extends RefCounted

var id: String
var name: String
var category: String
var effect: String
var effect_value: Variant # int or null
var description: String
var buy_price: Variant # int or null
var sell_price: Variant # int or null
var is_key_item: bool
var is_custom: bool
var zone_association: Variant # String or null

func _init(data: Dictionary) -> void:
	id = data.get("id", "")
	name = data.get("name", "")
	category = data.get("category", "")
	effect = data.get("effect", "")
	effect_value = data.get("effect_value", null)
	description = data.get("description", "")
	buy_price = data.get("buy_price", null)
	sell_price = data.get("sell_price", null)
	is_key_item = data.get("is_key_item", false)
	is_custom = data.get("is_custom", false)
	zone_association = data.get("zone_association", null)
