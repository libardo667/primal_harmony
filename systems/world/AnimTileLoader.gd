## AnimTileLoader.gd
##
## Autoload singleton.  Register in Project Settings → Autoloads as "AnimTileLoader".
##
## Called by MainGame._load_map() after the new map scene is added to the tree.
## It inspects the map's TileSet, identifies which tilesets are in use, loads the
## matching *_anim_bottom.tres / *_anim_top.tres sources, adds them to the TileSet,
## then re-routes every animated metatile cell to the animated source.
##
## After this runs, Godot's built-in TileSetAtlasSource animation loop takes over —
## no per-frame script work required at runtime.
##
## Build-time dependency: pokeemerald.
## Runtime dependency:    res://assets/tilesets/anim/  only (no pokeemerald paths).

extends Node

# Cache: ts_name → { "config": dict, "bottom_src": TileSetAtlasSource, "top_src": TileSetAtlasSource }
var _cache: Dictionary = {}

# Map from texture filename stem → ts_name  (e.g. "primary_general_bottom" → "primary_general")
# Both bottom and top stems must be listed so both layers get rerouted.
const TEXTURE_STEM_TO_TILESET := {
	# Primaries
	"primary_general_bottom": "primary_general",
	"primary_general_middle": "primary_general",
	"primary_general_top": "primary_general",
	"primary_building_bottom": "primary_building",
	"primary_building_middle": "primary_building",
	"primary_building_top": "primary_building",
	"primary_secret_base_bottom": "primary_secret_base",
	"primary_secret_base_middle": "primary_secret_base",
	"primary_secret_base_top": "primary_secret_base",
	# Secondaries – general-paired
	"secondary_battle_frontier_outside_east_bottom": "secondary_battle_frontier_outside_east",
	"secondary_battle_frontier_outside_east_middle": "secondary_battle_frontier_outside_east",
	"secondary_battle_frontier_outside_east_top": "secondary_battle_frontier_outside_east",
	"secondary_battle_frontier_outside_west_bottom": "secondary_battle_frontier_outside_west",
	"secondary_battle_frontier_outside_west_middle": "secondary_battle_frontier_outside_west",
	"secondary_battle_frontier_outside_west_top": "secondary_battle_frontier_outside_west",
	"secondary_battle_palace_bottom": "secondary_battle_palace",
	"secondary_battle_palace_middle": "secondary_battle_palace",
	"secondary_battle_palace_top": "secondary_battle_palace",
	"secondary_bike_shop_bottom": "secondary_bike_shop",
	"secondary_bike_shop_middle": "secondary_bike_shop",
	"secondary_bike_shop_top": "secondary_bike_shop",
	"secondary_cave_bottom": "secondary_cave",
	"secondary_cave_middle": "secondary_cave",
	"secondary_cave_top": "secondary_cave",
	"secondary_dewford_bottom": "secondary_dewford",
	"secondary_dewford_middle": "secondary_dewford",
	"secondary_dewford_top": "secondary_dewford",
	"secondary_ever_grande_bottom": "secondary_ever_grande",
	"secondary_ever_grande_middle": "secondary_ever_grande",
	"secondary_ever_grande_top": "secondary_ever_grande",
	"secondary_facility_bottom": "secondary_facility",
	"secondary_facility_middle": "secondary_facility",
	"secondary_facility_top": "secondary_facility",
	"secondary_fallarbor_bottom": "secondary_fallarbor",
	"secondary_fallarbor_middle": "secondary_fallarbor",
	"secondary_fallarbor_top": "secondary_fallarbor",
	"secondary_fortree_bottom": "secondary_fortree",
	"secondary_fortree_middle": "secondary_fortree",
	"secondary_fortree_top": "secondary_fortree",
	"secondary_inside_of_truck_bottom": "secondary_inside_of_truck",
	"secondary_inside_of_truck_middle": "secondary_inside_of_truck",
	"secondary_inside_of_truck_top": "secondary_inside_of_truck",
	"secondary_inside_ship_bottom": "secondary_inside_ship",
	"secondary_inside_ship_middle": "secondary_inside_ship",
	"secondary_inside_ship_top": "secondary_inside_ship",
	"secondary_island_harbor_bottom": "secondary_island_harbor",
	"secondary_island_harbor_middle": "secondary_island_harbor",
	"secondary_island_harbor_top": "secondary_island_harbor",
	"secondary_lavaridge_bottom": "secondary_lavaridge",
	"secondary_lavaridge_middle": "secondary_lavaridge",
	"secondary_lavaridge_top": "secondary_lavaridge",
	"secondary_lilycove_bottom": "secondary_lilycove",
	"secondary_lilycove_middle": "secondary_lilycove",
	"secondary_lilycove_top": "secondary_lilycove",
	"secondary_mauville_bottom": "secondary_mauville",
	"secondary_mauville_middle": "secondary_mauville",
	"secondary_mauville_top": "secondary_mauville",
	"secondary_meteor_falls_bottom": "secondary_meteor_falls",
	"secondary_meteor_falls_middle": "secondary_meteor_falls",
	"secondary_meteor_falls_top": "secondary_meteor_falls",
	"secondary_mirage_tower_bottom": "secondary_mirage_tower",
	"secondary_mirage_tower_middle": "secondary_mirage_tower",
	"secondary_mirage_tower_top": "secondary_mirage_tower",
	"secondary_mossdeep_bottom": "secondary_mossdeep",
	"secondary_mossdeep_middle": "secondary_mossdeep",
	"secondary_mossdeep_top": "secondary_mossdeep",
	"secondary_navel_rock_bottom": "secondary_navel_rock",
	"secondary_navel_rock_middle": "secondary_navel_rock",
	"secondary_navel_rock_top": "secondary_navel_rock",
	"secondary_pacifidlog_bottom": "secondary_pacifidlog",
	"secondary_pacifidlog_middle": "secondary_pacifidlog",
	"secondary_pacifidlog_top": "secondary_pacifidlog",
	"secondary_petalburg_bottom": "secondary_petalburg",
	"secondary_petalburg_middle": "secondary_petalburg",
	"secondary_petalburg_top": "secondary_petalburg",
	"secondary_rustboro_bottom": "secondary_rustboro",
	"secondary_rustboro_middle": "secondary_rustboro",
	"secondary_rustboro_top": "secondary_rustboro",
	"secondary_rusturf_tunnel_bottom": "secondary_rusturf_tunnel",
	"secondary_rusturf_tunnel_middle": "secondary_rusturf_tunnel",
	"secondary_rusturf_tunnel_top": "secondary_rusturf_tunnel",
	"secondary_slateport_bottom": "secondary_slateport",
	"secondary_slateport_middle": "secondary_slateport",
	"secondary_slateport_top": "secondary_slateport",
	"secondary_sootopolis_bottom": "secondary_sootopolis",
	"secondary_sootopolis_middle": "secondary_sootopolis",
	"secondary_sootopolis_top": "secondary_sootopolis",
	"secondary_underwater_bottom": "secondary_underwater",
	"secondary_underwater_middle": "secondary_underwater",
	"secondary_underwater_top": "secondary_underwater",
	# Secondaries – building-paired
	"secondary_battle_arena_bottom": "secondary_battle_arena",
	"secondary_battle_arena_middle": "secondary_battle_arena",
	"secondary_battle_arena_top": "secondary_battle_arena",
	"secondary_battle_dome_bottom": "secondary_battle_dome",
	"secondary_battle_dome_middle": "secondary_battle_dome",
	"secondary_battle_dome_top": "secondary_battle_dome",
	"secondary_battle_factory_bottom": "secondary_battle_factory",
	"secondary_battle_factory_middle": "secondary_battle_factory",
	"secondary_battle_factory_top": "secondary_battle_factory",
	"secondary_battle_frontier_bottom": "secondary_battle_frontier",
	"secondary_battle_frontier_middle": "secondary_battle_frontier",
	"secondary_battle_frontier_top": "secondary_battle_frontier",
	"secondary_battle_frontier_ranking_hall_bottom": "secondary_battle_frontier_ranking_hall",
	"secondary_battle_frontier_ranking_hall_middle": "secondary_battle_frontier_ranking_hall",
	"secondary_battle_frontier_ranking_hall_top": "secondary_battle_frontier_ranking_hall",
	"secondary_battle_pike_bottom": "secondary_battle_pike",
	"secondary_battle_pike_middle": "secondary_battle_pike",
	"secondary_battle_pike_top": "secondary_battle_pike",
	"secondary_battle_pyramid_bottom": "secondary_battle_pyramid",
	"secondary_battle_pyramid_middle": "secondary_battle_pyramid",
	"secondary_battle_pyramid_top": "secondary_battle_pyramid",
	"secondary_battle_tent_bottom": "secondary_battle_tent",
	"secondary_battle_tent_middle": "secondary_battle_tent",
	"secondary_battle_tent_top": "secondary_battle_tent",
	"secondary_brendans_mays_house_bottom": "secondary_brendans_mays_house",
	"secondary_brendans_mays_house_middle": "secondary_brendans_mays_house",
	"secondary_brendans_mays_house_top": "secondary_brendans_mays_house",
	"secondary_cable_club_bottom": "secondary_cable_club",
	"secondary_cable_club_middle": "secondary_cable_club",
	"secondary_cable_club_top": "secondary_cable_club",
	"secondary_contest_bottom": "secondary_contest",
	"secondary_contest_middle": "secondary_contest",
	"secondary_contest_top": "secondary_contest",
	"secondary_dewford_gym_bottom": "secondary_dewford_gym",
	"secondary_dewford_gym_middle": "secondary_dewford_gym",
	"secondary_dewford_gym_top": "secondary_dewford_gym",
	"secondary_elite_four_bottom": "secondary_elite_four",
	"secondary_elite_four_middle": "secondary_elite_four",
	"secondary_elite_four_top": "secondary_elite_four",
	"secondary_fortree_gym_bottom": "secondary_fortree_gym",
	"secondary_fortree_gym_middle": "secondary_fortree_gym",
	"secondary_fortree_gym_top": "secondary_fortree_gym",
	"secondary_generic_building_bottom": "secondary_generic_building",
	"secondary_generic_building_middle": "secondary_generic_building",
	"secondary_generic_building_top": "secondary_generic_building",
	"secondary_lab_bottom": "secondary_lab",
	"secondary_lab_middle": "secondary_lab",
	"secondary_lab_top": "secondary_lab",
	"secondary_lavaridge_gym_bottom": "secondary_lavaridge_gym",
	"secondary_lavaridge_gym_middle": "secondary_lavaridge_gym",
	"secondary_lavaridge_gym_top": "secondary_lavaridge_gym",
	"secondary_lilycove_museum_bottom": "secondary_lilycove_museum",
	"secondary_lilycove_museum_middle": "secondary_lilycove_museum",
	"secondary_lilycove_museum_top": "secondary_lilycove_museum",
	"secondary_mauville_game_corner_bottom": "secondary_mauville_game_corner",
	"secondary_mauville_game_corner_middle": "secondary_mauville_game_corner",
	"secondary_mauville_game_corner_top": "secondary_mauville_game_corner",
	"secondary_mauville_gym_bottom": "secondary_mauville_gym",
	"secondary_mauville_gym_middle": "secondary_mauville_gym",
	"secondary_mauville_gym_top": "secondary_mauville_gym",
	"secondary_mossdeep_game_corner_bottom": "secondary_mossdeep_game_corner",
	"secondary_mossdeep_game_corner_middle": "secondary_mossdeep_game_corner",
	"secondary_mossdeep_game_corner_top": "secondary_mossdeep_game_corner",
	"secondary_mossdeep_gym_bottom": "secondary_mossdeep_gym",
	"secondary_mossdeep_gym_middle": "secondary_mossdeep_gym",
	"secondary_mossdeep_gym_top": "secondary_mossdeep_gym",
	"secondary_mystery_events_house_bottom": "secondary_mystery_events_house",
	"secondary_mystery_events_house_middle": "secondary_mystery_events_house",
	"secondary_mystery_events_house_top": "secondary_mystery_events_house",
	"secondary_oceanic_museum_bottom": "secondary_oceanic_museum",
	"secondary_oceanic_museum_middle": "secondary_oceanic_museum",
	"secondary_oceanic_museum_top": "secondary_oceanic_museum",
	"secondary_petalburg_gym_bottom": "secondary_petalburg_gym",
	"secondary_petalburg_gym_middle": "secondary_petalburg_gym",
	"secondary_petalburg_gym_top": "secondary_petalburg_gym",
	"secondary_pokemon_center_bottom": "secondary_pokemon_center",
	"secondary_pokemon_center_middle": "secondary_pokemon_center",
	"secondary_pokemon_center_top": "secondary_pokemon_center",
	"secondary_pokemon_day_care_bottom": "secondary_pokemon_day_care",
	"secondary_pokemon_day_care_middle": "secondary_pokemon_day_care",
	"secondary_pokemon_day_care_top": "secondary_pokemon_day_care",
	"secondary_pokemon_fan_club_bottom": "secondary_pokemon_fan_club",
	"secondary_pokemon_fan_club_middle": "secondary_pokemon_fan_club",
	"secondary_pokemon_fan_club_top": "secondary_pokemon_fan_club",
	"secondary_pokemon_school_bottom": "secondary_pokemon_school",
	"secondary_pokemon_school_middle": "secondary_pokemon_school",
	"secondary_pokemon_school_top": "secondary_pokemon_school",
	"secondary_pretty_petal_flower_shop_bottom": "secondary_pretty_petal_flower_shop",
	"secondary_pretty_petal_flower_shop_middle": "secondary_pretty_petal_flower_shop",
	"secondary_pretty_petal_flower_shop_top": "secondary_pretty_petal_flower_shop",
	"secondary_rustboro_gym_bottom": "secondary_rustboro_gym",
	"secondary_rustboro_gym_middle": "secondary_rustboro_gym",
	"secondary_rustboro_gym_top": "secondary_rustboro_gym",
	"secondary_seashore_house_bottom": "secondary_seashore_house",
	"secondary_seashore_house_middle": "secondary_seashore_house",
	"secondary_seashore_house_top": "secondary_seashore_house",
	"secondary_shop_bottom": "secondary_shop",
	"secondary_shop_middle": "secondary_shop",
	"secondary_shop_top": "secondary_shop",
	"secondary_sootopolis_gym_bottom": "secondary_sootopolis_gym",
	"secondary_sootopolis_gym_middle": "secondary_sootopolis_gym",
	"secondary_sootopolis_gym_top": "secondary_sootopolis_gym",
	"secondary_trainer_hill_bottom": "secondary_trainer_hill",
	"secondary_trainer_hill_middle": "secondary_trainer_hill",
	"secondary_trainer_hill_top": "secondary_trainer_hill",
	"secondary_trick_house_puzzle_bottom": "secondary_trick_house_puzzle",
	"secondary_trick_house_puzzle_middle": "secondary_trick_house_puzzle",
	"secondary_trick_house_puzzle_top": "secondary_trick_house_puzzle",
	"secondary_union_room_bottom": "secondary_union_room",
	"secondary_union_room_middle": "secondary_union_room",
	"secondary_union_room_top": "secondary_union_room",
	"secondary_unused_1_bottom": "secondary_unused_1",
	"secondary_unused_1_middle": "secondary_unused_1",
	"secondary_unused_1_top": "secondary_unused_1",
	"secondary_unused_2_bottom": "secondary_unused_2",
	"secondary_unused_2_middle": "secondary_unused_2",
	"secondary_unused_2_top": "secondary_unused_2",
	# Secret base variants
	"secondary_secret_base_blue_cave_bottom": "secondary_secret_base_blue_cave",
	"secondary_secret_base_blue_cave_middle": "secondary_secret_base_blue_cave",
	"secondary_secret_base_blue_cave_top": "secondary_secret_base_blue_cave",
	"secondary_secret_base_brown_cave_bottom": "secondary_secret_base_brown_cave",
	"secondary_secret_base_brown_cave_middle": "secondary_secret_base_brown_cave",
	"secondary_secret_base_brown_cave_top": "secondary_secret_base_brown_cave",
	"secondary_secret_base_red_cave_bottom": "secondary_secret_base_red_cave",
	"secondary_secret_base_red_cave_middle": "secondary_secret_base_red_cave",
	"secondary_secret_base_red_cave_top": "secondary_secret_base_red_cave",
	"secondary_secret_base_shrub_bottom": "secondary_secret_base_shrub",
	"secondary_secret_base_shrub_middle": "secondary_secret_base_shrub",
	"secondary_secret_base_shrub_top": "secondary_secret_base_shrub",
	"secondary_secret_base_tree_bottom": "secondary_secret_base_tree",
	"secondary_secret_base_tree_middle": "secondary_secret_base_tree",
	"secondary_secret_base_tree_top": "secondary_secret_base_tree",
	"secondary_secret_base_yellow_cave_bottom": "secondary_secret_base_yellow_cave",
	"secondary_secret_base_yellow_cave_middle": "secondary_secret_base_yellow_cave",
	"secondary_secret_base_yellow_cave_top": "secondary_secret_base_yellow_cave",
}

# Columns of metatiles in the atlas (always 8 wide, matching build_godot_tilesets.py)
const ATLAS_COLS := 8


## Main entry point — call this after add_child(_current_map) in MainGame.
func setup_map_animations(map_node: Node) -> void:
	var terrain: TileMap = map_node.get_node_or_null("TileMapTerrain")
	var deco: TileMap = map_node.get_node_or_null("TileMapDecoration")
	if terrain == null or deco == null:
		return

	# IMPORTANT: Duplicate the TileSet resource so modifications (adding sources, rerouting)
	# are local to this map instance and don't corrupt the shared .tres file.
	var ts: TileSet = terrain.tile_set.duplicate()
	terrain.tile_set = ts
	deco.tile_set = ts

	# Discover which tilesets are active: check static source IDs 0-7.
	# Convention from paint_route_*.gd:
	#   source_id 0 = primary bottom,   1 = primary top
	#   source_id 2 = secondary bottom, 3 = secondary top
	var anim_source_ids := {} # static_src_id (int) → anim_src_id (int)
	var meta_row_maps := {} # static_src_id (int) → { metatile_idx: row }

	for static_src_id in range(8):
		if not ts.has_source(static_src_id):
			continue
		var src := ts.get_source(static_src_id) as TileSetAtlasSource
		if src == null or src.texture == null:
			continue

		var stem: String = src.texture.resource_path.get_file().get_basename()
		if not TEXTURE_STEM_TO_TILESET.has(stem):
			continue

		var ts_name: String = TEXTURE_STEM_TO_TILESET[stem]
		var side_key := "bottom_src"
		if stem.ends_with("_middle"):
			side_key = "middle_src"
		elif stem.ends_with("_top"):
			side_key = "top_src"

		# Load and cache config + anim sources if needed
		if not _cache.has(ts_name):
			_cache[ts_name] = _load_tileset_anim(ts_name)
		var entry: Dictionary = _cache[ts_name]
		if entry.is_empty():
			continue
		var anim_src: TileSetAtlasSource = entry.get(side_key)
		if anim_src == null:
			continue

		# Always duplicate before adding. A TileSetAtlasSource can only belong to
		# one TileSet at a time — Godot rejects re-adding the same object and returns
		# INVALID_SOURCE (-1), which _reroute_layer then passes to set_cell(), erasing
		# every animated cell on that map. Each map gets its own shallow copy instead.
		var anim_src_id: int = ts.add_source(anim_src.duplicate())

		anim_source_ids[static_src_id] = anim_src_id

		# Build metatile → atlas-row lookup for this source
		if not meta_row_maps.has(static_src_id):
			var cfg: Dictionary = entry.get("config", {})
			var animated: Dictionary = cfg.get("animated_metatiles", {})
			var lookup := {}
			for m_str in animated.keys():
				lookup[int(m_str)] = int(animated[m_str].get("row", 0))
			meta_row_maps[static_src_id] = lookup

	if anim_source_ids.is_empty():
		return

	# Re-route cells on terrain layer 0 (bottom sub-tiles), layer 1 (middle sub-tiles),
	# and layer 2 (COVERED top sub-tiles), then deco layer 0.
	_reroute_layer(terrain, 0, anim_source_ids, meta_row_maps)
	if terrain.get_layers_count() > 1:
		_reroute_layer(terrain, 1, anim_source_ids, meta_row_maps)
	if terrain.get_layers_count() > 2:
		_reroute_layer(terrain, 2, anim_source_ids, meta_row_maps)
	_reroute_layer(deco, 0, anim_source_ids, meta_row_maps)


func _reroute_layer(
		tilemap: TileMap,
		layer: int,
		anim_source_ids: Dictionary, # static_src_id → anim_src_id
		meta_row_maps: Dictionary # static_src_id → { metatile_idx: row }
) -> void:
	for cell_pos: Vector2i in tilemap.get_used_cells(layer):
		var src_id: int = tilemap.get_cell_source_id(layer, cell_pos)
		var atlas_pos: Vector2i = tilemap.get_cell_atlas_coords(layer, cell_pos)

		if not anim_source_ids.has(src_id):
			continue

		var metatile_idx: int = atlas_pos.y * ATLAS_COLS + atlas_pos.x
		var row_map: Dictionary = meta_row_maps.get(src_id, {})
		if not row_map.has(metatile_idx):
			continue

		var anim_src_id: int = anim_source_ids[src_id]
		var anim_row: int = row_map[metatile_idx]

		# Atlas col 0 = first animation frame; Godot cycles the rest automatically.
		tilemap.set_cell(layer, cell_pos, anim_src_id, Vector2i(0, anim_row))


## Loads the JSON config and both .tres atlas sources for a named tileset.
func _load_tileset_anim(ts_name: String) -> Dictionary:
	var config_path := "res://assets/tilesets/anim/%s_anim_config.json" % ts_name
	var bottom_path := "res://assets/tilesets/%s_anim_bottom.tres" % ts_name
	var middle_path := "res://assets/tilesets/%s_anim_middle.tres" % ts_name
	var top_path := "res://assets/tilesets/%s_anim_top.tres" % ts_name

	if not FileAccess.file_exists(config_path):
		return {}

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return {}
	var cfg = JSON.parse_string(file.get_as_text())
	file.close()
	if not cfg is Dictionary:
		return {}

	var bottom_src: TileSetAtlasSource = load(bottom_path) if ResourceLoader.exists(bottom_path) else null
	var middle_src: TileSetAtlasSource = load(middle_path) if ResourceLoader.exists(middle_path) else null
	var top_src: TileSetAtlasSource = load(top_path) if ResourceLoader.exists(top_path) else null

	if bottom_src == null and middle_src == null and top_src == null:
		push_warning("AnimTileLoader: no .tres files found for '%s'. Run tools/build_anim_tilesets.gd first." % ts_name)
		return {}

	return {
		"config": cfg,
		"bottom_src": bottom_src,
		"middle_src": middle_src,
		"top_src": top_src,
	}


## Return the source_id if anim_src is already in the TileSet, else -1.
func _find_source_id_for(ts: TileSet, anim_src: TileSetAtlasSource) -> int:
	for i in range(ts.get_source_count()):
		var src_id = ts.get_source_id(i)
		if ts.get_source(src_id) == anim_src:
			return src_id
	return -1
