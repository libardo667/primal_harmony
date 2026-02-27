## DataManager — Central Data Access Layer
##
## Autoload singleton that loads and exposes all game data (Pokémon, moves, items, zones).
## Currently stubbed as an interface — actual loading logic is deferred until The Keeper
## delivers confirmed JSON schemas.
##
## Owner: The Mechanic (interface)  •  Depends on: The Keeper (data files)
extends Node

# =========================================================================
#  Internal State
# =========================================================================

## Loaded data caches — populated by _load_all_data() once schemas are confirmed.
var _pokemon_data: Dictionary = {} # Maps String -> PokemonData
var _move_data: Dictionary = {} # Maps String -> MoveData
var _item_data: Dictionary = {} # Maps String -> ItemData
var _zone_data: Dictionary = {} # Maps String -> ZoneData
var _ability_data: Dictionary = {} # Maps String -> AbilityData

## National-dex → canonical display name, loaded from all_pokemon.csv.
var _name_by_dex: Dictionary = {}

var _data_loaded: bool = false


# =========================================================================
#  Lifecycle
# =========================================================================

func _ready() -> void:
	_load_all_data()


# =========================================================================
#  Public API — Pokémon
# =========================================================================

## Returns the PokemonData for a Pokémon species, or null
## if the species is not found.
func get_pokemon(species_id: String) -> PokemonData:
	if _pokemon_data.has(species_id):
		return _pokemon_data[species_id]
	push_warning("[DataManager] Pokémon not found: %s" % species_id)
	return null


## Returns all loaded Pokémon species IDs.
func get_all_pokemon_ids() -> Array:
	return _pokemon_data.keys()


# =========================================================================
#  Public API — Moves
# =========================================================================

## Returns the MoveData for a move, or null if not found.
func get_move(move_id: String) -> MoveData:
	if _move_data.has(move_id):
		return _move_data[move_id]
	push_warning("[DataManager] Move not found: %s" % move_id)
	return null


## Returns all loaded move IDs.
func get_all_move_ids() -> Array:
	return _move_data.keys()


# =========================================================================
#  Public API — Items
# =========================================================================

## Returns the ItemData for an item, or null if not found.
func get_item(item_id: String) -> ItemData:
	if _item_data.has(item_id):
		return _item_data[item_id]
	push_warning("[DataManager] Item not found: %s" % item_id)
	return null


## Returns all loaded item IDs.
func get_all_item_ids() -> Array:
	return _item_data.keys()


# =========================================================================
#  Public API — Abilities
# =========================================================================

## Returns the AbilityData for an ability, or null if not found.
func get_ability(ability_id: String) -> AbilityData:
	var normalized_id: String = ability_id.to_lower().replace(" ", "_").replace("-", "_")
	if _ability_data.has(normalized_id):
		return _ability_data[normalized_id]
	push_warning("[DataManager] Ability not found: %s" % ability_id)
	return null

## Returns all loaded ability IDs.
func get_all_ability_ids() -> Array:
	return _ability_data.keys()


# =========================================================================
#  Public API — Zones
# =========================================================================

## Returns the ZoneData for a zone, or null if not found.
func get_zone(zone_id: String) -> ZoneData:
	if _zone_data.has(zone_id):
		return _zone_data[zone_id]
	push_warning("[DataManager] Zone not found: %s" % zone_id)
	return null


## Returns all loaded zone IDs.
func get_all_zone_ids() -> Array:
	return _zone_data.keys()


# =========================================================================
#  Public API — Status
# =========================================================================

## Returns [code]true[/code] if data has been successfully loaded.
func is_data_loaded() -> bool:
	return _data_loaded


## Returns the canonical display name for a Pokémon species.
## Checks PokemonData.name first, then all_pokemon.csv by national dex, then prettifies the id.
func get_pokemon_display_name(species_id: String) -> String:
	var pdata: PokemonData = get_pokemon(species_id)
	if pdata != null:
		if not pdata.name.is_empty():
			return pdata.name
		var dex_var: Variant = pdata.national_dex
		if dex_var != null:
			var dex: int = int(dex_var)
			if _name_by_dex.has(dex):
				return _name_by_dex[dex]
	return species_id.replace("_", " ").capitalize()


# =========================================================================
#  Internal — Data Loading (Stubbed)
# =========================================================================

## Loads all JSON data from disk. Scans each data subdirectory and loads every
## non-schema JSON file. Called on _ready().
func _load_all_data() -> void:
	print("[DataManager] Loading all data from disk...")

	var loaded_ok: bool = true
	loaded_ok = _load_directory("res://data/pokemon/", _pokemon_data, "pokemon") and loaded_ok
	loaded_ok = _load_directory("res://data/moves/", _move_data, "move") and loaded_ok
	loaded_ok = _load_directory("res://data/items/", _item_data, "item") and loaded_ok
	loaded_ok = _load_directory("res://data/zones/", _zone_data, "zone") and loaded_ok
	loaded_ok = _load_directory("res://data/abilities/", _ability_data, "ability") and loaded_ok
	_load_pokemon_csv_names()

	_data_loaded = loaded_ok
	if _data_loaded:
		print("[DataManager] Load complete. Pokémon: %d  Moves: %d  Items: %d  Zones: %d  Abilities: %d" % [
			_pokemon_data.size(), _move_data.size(), _item_data.size(), _zone_data.size(), _ability_data.size()
		])
	else:
		push_warning("[DataManager] One or more directories failed to load.")


## Loads canonical display names from all_pokemon.csv (column 1 = dex#, column 2 = name).
func _load_pokemon_csv_names() -> void:
	var file: FileAccess = FileAccess.open("res://all_pokemon.csv", FileAccess.READ)
	if file == null:
		push_warning("[DataManager] Could not open all_pokemon.csv — display names will fall back to species_id.")
		return
	file.get_line()  # skip header
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts: PackedStringArray = line.split(",")
		if parts.size() >= 2:
			var dex: int = int(parts[0].strip_edges().trim_prefix("\uFEFF"))
			var pname: String = parts[1].strip_edges().trim_prefix("\"")
			if dex > 0 and not pname.is_empty():
				_name_by_dex[dex] = pname
	file.close()
	print("[DataManager] Loaded %d Pokémon display names from CSV." % _name_by_dex.size())


## Scans [param dir_path] for .json files, parses each, and stores by their "id" key
## into [param cache]. Schema files (_schema.json) are automatically skipped.
## Extracted dictionaries to their respective wrapper classes prior to caching.
## Returns [code]true[/code] if the directory was opened successfully.
func _load_directory(dir_path: String, cache: Dictionary, type_hint: String) -> bool:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_warning("[DataManager] Could not open directory: %s" % dir_path)
		return false

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json") \
				and not file_name.begins_with("_"):
			var full_path: String = dir_path + file_name
			var data: Dictionary = _load_json(full_path)
			if not data.is_empty():
				var id: String = data.get("id", "")
				if id.is_empty():
					# Zones use zone_id instead of id.
					id = data.get("zone_id", "")
				if not id.is_empty():
					match type_hint:
						"pokemon": cache[id] = PokemonData.new(data)
						"move": cache[id] = MoveData.new(data)
						"item": cache[id] = ItemData.new(data)
						"zone": cache[id] = ZoneData.new(data)
						"ability": cache[id] = AbilityData.new(data)
						_: push_warning("[DataManager] Unknown type hint: %s" % type_hint)
				else:
					push_warning("[DataManager] File has no id/zone_id: %s" % full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return true


## Parses a JSON file at [param path] and returns its contents as a Dictionary.
## Returns an empty Dictionary on error.
func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[DataManager] Could not open file: %s" % path)
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: int = json.parse(json_text)
	if err != OK:
		push_error("[DataManager] JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}

	var result: Variant = json.get_data()
	if typeof(result) != TYPE_DICTIONARY:
		push_error("[DataManager] Expected Dictionary in %s, got %s" % [path, typeof(result)])
		return {}

	return result as Dictionary
