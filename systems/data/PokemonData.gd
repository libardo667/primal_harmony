class_name PokemonData extends RefCounted

var id: String
var name: String
var national_dex: Variant # int or null
var types: Array[String] = []
var base_stats: Dictionary = {}
var abilities: Array[String] = []
var hidden_ability: Variant # String or null
var learnset: Array = []
var evolution: Variant # Dictionary or null
var dex_entry: String
var catch_rate: int
var base_exp: int
var growth_rate: String
var egg_groups: Array[String] = []
var gender_ratio: float
var is_native_hoenn: bool
var native_zone: Variant # String or null
var is_corrupted: bool
var corruption_zone: Variant # String or null
var corruption_path: Variant # String or null
var base_species: Variant # String or null
var sprites: Dictionary = {} # {"front": "res://...", "back": "...", "icon": "..."}

func _init(data: Dictionary) -> void:
	id = data.get("id", "")
	name = data.get("name", "")
	national_dex = data.get("national_dex", null)
	
	for t in data.get("types", []):
		types.append(t)
		
	base_stats = data.get("base_stats", {})
	
	for a in data.get("abilities", []):
		abilities.append(a)
		
	hidden_ability = data.get("hidden_ability", null)
	learnset = data.get("learnset", [])
	evolution = data.get("evolution", null)
	dex_entry = data.get("dex_entry", "")
	catch_rate = data.get("catch_rate", 0)
	base_exp = data.get("base_exp", 0)
	growth_rate = data.get("growth_rate", "")
	
	for g in data.get("egg_groups", []):
		egg_groups.append(g)
		
	gender_ratio = float(data.get("gender_ratio", 0.0))
	is_native_hoenn = data.get("is_native_hoenn", false)
	native_zone = data.get("native_zone", null)
	is_corrupted = data.get("is_corrupted", false)
	corruption_zone = data.get("corruption_zone", null)
	corruption_path = data.get("corruption_path", null)
	base_species = data.get("base_species", null)
	sprites = data.get("sprites", {})
