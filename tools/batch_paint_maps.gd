## batch_paint_maps.gd
##
## Batch-paints all 441 pokeemerald layouts into Godot .tscn scenes.
##
## Output structure:
##   maps/hoenn/routes/     — Route* maps
##   maps/hoenn/cities/     — Non-route, non-underscore maps (cities + towns)
##   maps/hoenn/interiors/  — Maps with underscores in name (buildings, floors)
##
## Run headless:
##   "C:/Program Files/Godot/Godot_v4.6.1-stable_win64.exe" --headless --script res://tools/batch_paint_maps.gd
##
## After running, import new assets:
##   "C:/Program Files/Godot/Godot_v4.6.1-stable_win64.exe" --headless --import

extends SceneTree

const POKEEMERALD := "C:/Users/levib/pokemon_projects/pokeemerald"
const LAYOUTS_JSON := POKEEMERALD + "/data/layouts/layouts.json"
const TILESETS_DIR := "res://assets/tilesets/"
const MAPS_BASE := "res://maps/hoenn/"

# Path to the zone assignment file (read at build time to set root metadata).
const MAP_ZONE_IDS_PATH := "res://data/map_zone_ids.json"

## Per-type tints for TOZ map variants, based on Emerald type icon palettes.
const TOZ_TINTS := {
	"ashen_glacier": Color(0.7, 0.85, 1.0, 1.0), # Ice: pale blue
	"static_sprawl": Color(1.0, 1.0, 0.4, 1.0), # Electric: acid yellow
	"emberscar": Color(1.0, 0.5, 0.3, 1.0), # Fire: ember orange
	"the_veil": Color(0.8, 0.4, 1.0, 1.0), # Psychic: bright magenta-purple
	"dread_shore": Color(0.2, 0.3, 0.5, 1.0), # Dark: murky deep blue
	"the_murk": Color(0.8, 0.3, 0.9, 1.0), # Poison: vibrant purple
	"the_crucible": Color(0.8, 0.6, 0.4, 1.0), # Ground: dusty ochre
	"the_overgrowth": Color(0.4, 0.9, 0.3, 1.0), # Grass: hyper-green
	"abyss_bloom": Color(0.3, 0.4, 1.0, 1.0), # Water: deep aquatic blue
	"static_sky": Color(0.5, 0.3, 1.0, 1.0), # Dragon: indigo energy
}

# Cache: ts_key ("primary_X|secondary_Y") → TileSet
var _ts_cache: Dictionary = {}
# Cache: abs_path → PackedByteArray (2 bytes per metatile, bits 12-15 = layer type)
var _attr_cache: Dictionary = {}
# Loaded once from MAP_ZONE_IDS_PATH: MAP_ID → zone_id.
var _map_zone_ids: Dictionary = {}

# METATILE_LAYER_TYPE constants — pokeemerald include/global.fieldmap.h, bits 12-15
# NORMAL (0):  bottom sub-tiles → terrain (behind player), top → decoration (above player)
# COVERED (1): BOTH layers behind player — path ground, dirt mats, flowers, water surface
# SPLIT (2):   bottom → terrain, top → decoration (bridges — treated same as NORMAL here)
const LAYER_NORMAL := 0
const LAYER_COVERED := 1
const LAYER_SPLIT := 2

# ── Metatile behavior byte constants ────────────────────────────────────────
# Bits 0-7 of the u16 in metatile_attributes.bin.
# Source: pokeemerald/include/constants/metatile_behaviors.h (sequential enum, 0-based).
# Only the subset relevant for encounter-zone baking is listed here.
const MB_TALL_GRASS := 0x02 # Land — standard tall grass
const MB_LONG_GRASS := 0x03 # Land — long grass (Safari Zone etc.)
const MB_SHORT_GRASS := 0x07 # Land — no rustle animation
const MB_CAVE := 0x08 # Cave encounter
const MB_LONG_GRASS_SOUTH_EDGE := 0x09 # Visual edge tile, same encounter type as long grass
const MB_INDOOR_ENCOUNTER := 0x0B # Indoor land encounter
const MB_POND_WATER := 0x10 # Surfable — pond / lake
const MB_INTERIOR_DEEP_WATER := 0x11 # Interior deep water
const MB_DEEP_WATER := 0x12 # Surfable deep water
const MB_OCEAN_WATER := 0x15 # Surfable ocean
const MB_SHALLOW_WATER := 0x17 # Surfable shallow water
const MB_ASHGRASS := 0x24 # Land — ash-covered grass (Route 113)
# Ledge behaviors — tiles the player jumps over. coll_bits=1 in pokeemerald but the
# GBA engine handles them before collision; in Godot we skip collision placement so
# the player can step onto the tile and trigger the jump via Player._get_behavior_at_tile().
const MB_JUMP_EAST := 56 # 0x38
const MB_JUMP_WEST := 57 # 0x39
const MB_JUMP_NORTH := 58 # 0x3A
const MB_JUMP_SOUTH := 59 # 0x3B

# ─────────────────────────────────────────────────────────────────────────────
func _init() -> void:
	_run()
	quit()

func _run() -> void:
	# Load zone assignment data (used when writing root metadata per map).
	var zf := FileAccess.open(MAP_ZONE_IDS_PATH, FileAccess.READ)
	if zf:
		var zone_data = JSON.parse_string(zf.get_as_text())
		zf.close()
		if zone_data is Dictionary:
			_map_zone_ids = zone_data
			print("batch_paint_maps: Loaded %d zone assignments." % _map_zone_ids.size())
	else:
		print("batch_paint_maps: WARNING — could not load ", MAP_ZONE_IDS_PATH)

	# Read layouts.json
	var f := FileAccess.open(LAYOUTS_JSON, FileAccess.READ)
	if not f:
		print("ERROR: Cannot open ", LAYOUTS_JSON)
		return
	var json_text := f.get_as_text()
	f.close()

	var json_data = JSON.parse_string(json_text)
	if not json_data or not json_data.has("layouts"):
		print("ERROR: Failed to parse layouts.json")
		return

	var layouts: Array = json_data["layouts"]
	print("batch_paint_maps: Processing ", layouts.size(), " layouts...")

	# Ensure output directories exist
	for cat in ["routes", "cities", "interiors"]:
		var abs_path := ProjectSettings.globalize_path(MAPS_BASE + cat)
		DirAccess.make_dir_recursive_absolute(abs_path)

	var ok_count := 0
	var skip_count := 0
	var total := layouts.size()

	for idx in range(total):
		var layout: Dictionary = layouts[idx]
		var raw_name: String = layout["name"].replace("_Layout", "")
		var map_id_key: String = "MAP_" + _name_to_snake(raw_name).to_upper()
		var zone_id: String = _map_zone_ids.get(map_id_key, "")

		# 1. Standard variant
		_process_layout(layout, false)
		
		# 2. TOZ variant (if applicable)
		if not zone_id.is_empty() and TOZ_TINTS.has(zone_id):
			_process_layout(layout, true)
			ok_count += 2
		else:
			ok_count += 1

		if (idx + 1) % 50 == 0 or idx == total - 1:
			print("  Progress: %d / %d  (ok=%d  skipped=%d)" \
				% [idx + 1, total, ok_count, skip_count])

	print("batch_paint_maps: done.  ok=%d  skipped=%d" % [ok_count, skip_count])


# ─────────────────────────────────────────────────────────────────────────────
func _process_layout(layout: Dictionary, is_toz_variant: bool = false) -> bool:
	var raw_name: String = layout["name"].replace("_Layout", "")
	var prim_gname: String = str(layout["primary_tileset"])
	var sec_gname: String = str(layout["secondary_tileset"])
	var width: int = int(layout["width"])
	var height: int = int(layout["height"])
	var bin_path: String = POKEEMERALD + "/" + str(layout["blockdata_filepath"])

	# Collect warp tile positions from this map's JSON so we can skip baking solid
	# collision on them. In pokeemerald, warp tiles have coll_bits=1 in map.bin
	# (they look identical to surrounding walls), but the engine processes warps
	# before collision checks. In Godot we must leave those tiles physically passable
	# or the CharacterBody2D will never reach them.
	var warp_positions: Dictionary = {}
	var map_json_path := POKEEMERALD + "/data/maps/" + raw_name + "/map.json"
	var map_json_file := FileAccess.open(map_json_path, FileAccess.READ)
	if map_json_file:
		var map_json_data = JSON.parse_string(map_json_file.get_as_text())
		map_json_file.close()
		if map_json_data is Dictionary:
			var warps: Array = map_json_data.get("warp_events",
					map_json_data.get("warps", []))
			for w: Dictionary in warps:
				warp_positions[Vector2i(int(w.get("x", -1)), int(w.get("y", -1)))] = true

	# Resolve tileset names ("gTileset_X" → "primary_x" / "secondary_x")
	var prim_name := _gname_to_tileset(prim_gname, true)
	var sec_name := _gname_to_tileset(sec_gname, false)

	if prim_name.is_empty() or sec_name.is_empty():
		print("  SKIP (bad tileset name): ", raw_name,
			"  prim=", prim_gname, "  sec=", sec_gname)
		return false

	# Load metatile layer-type attributes so COVERED tiles (both layers behind player)
	# are routed to TileMapTerrain layer 1 instead of TileMapDecoration.
	var prim_attrs := _load_attrs(POKEEMERALD + "/data/tilesets/primary/"
		+ prim_name.replace("primary_", "") + "/metatile_attributes.bin")
	var sec_attrs := _load_attrs(POKEEMERALD + "/data/tilesets/secondary/"
		+ sec_name.replace("secondary_", "") + "/metatile_attributes.bin")

	# Verify asset PNGs exist
	var prim_bot := TILESETS_DIR + prim_name + "_bottom.png"
	var prim_mid := TILESETS_DIR + prim_name + "_middle.png"
	var prim_top := TILESETS_DIR + prim_name + "_top.png"
	var sec_bot := TILESETS_DIR + sec_name + "_bottom.png"
	var sec_mid := TILESETS_DIR + sec_name + "_middle.png"
	var sec_top := TILESETS_DIR + sec_name + "_top.png"

	if not ResourceLoader.exists(prim_bot):
		print("  SKIP (missing PNG): ", prim_bot)
		return false
	if not ResourceLoader.exists(sec_bot):
		print("  SKIP (missing PNG): ", sec_bot)
		return false

	# Determine output path
	var category := _get_category(raw_name)
	var file_name := _name_to_snake(raw_name)
	if is_toz_variant:
		file_name += "_TOZ"
	var out_path := MAPS_BASE + category + "/" + file_name + ".tscn"

	# Get (or build) a shared TileSet for this pair
	var ts_key := prim_name + "|" + sec_name
	var ts: TileSet
	if _ts_cache.has(ts_key):
		ts = _ts_cache[ts_key]
	else:
		ts = _build_tileset(prim_bot, prim_mid, prim_top, sec_bot, sec_mid, sec_top, prim_name, sec_name)
		_ts_cache[ts_key] = ts

	# ── Build scene tree ────────────────────────────────────────────────────
	var scene_root := Node2D.new()
	scene_root.name = raw_name
	if is_toz_variant:
		scene_root.name += "_TOZ"

	var terrain := TileMap.new()
	terrain.name = "TileMapTerrain"
	terrain.tile_set = ts
	# Layer 0: bottom sub-tiles (Terrain background)
	# Layer 1: middle sub-tiles (GBA layering support)
	# Layer 2: top sub-tiles of COVERED metatiles (Rendered behind player)
	terrain.add_layer(-1) # Adds Layer 1
	terrain.add_layer(-1) # Adds Layer 2
	scene_root.add_child(terrain)
	terrain.owner = scene_root

	var deco := TileMap.new()
	deco.name = "TileMapDecoration"
	deco.tile_set = ts
	deco.z_index = 1
	scene_root.add_child(deco)
	deco.owner = scene_root

	var coll := TileMap.new()
	coll.name = "TileMapCollision"
	coll.tile_set = ts
	coll.visible = false
	scene_root.add_child(coll)
	coll.owner = scene_root

	# ── Paint from map.bin ──────────────────────────────────────────────────
	var bin_file := FileAccess.open(bin_path, FileAccess.READ)
	if not bin_file:
		print("  SKIP (no map.bin): ", raw_name, "  path=", bin_path)
		scene_root.free()
		return false

	# Accumulate tile positions per encounter type for EncounterZones baking.
	var encounter_tiles: Dictionary = {
		"grass": [],
		"water": [],
		"cave": [],
		"indoor": [],
	}

	for y in range(height):
		for x in range(width):
			var val: int = bin_file.get_16()
			var metatile_id: int = val & 0x03FF
			var coll_bits: int = (val & 0x0C00) >> 10

			var src_bot: int
			var src_mid: int
			var src_top: int
			var local_id: int

			if metatile_id >= 512:
				src_bot = 3 # secondary bottom
				src_mid = 4 # secondary middle
				src_top = 5 # secondary top
				local_id = metatile_id - 512
			else:
				src_bot = 0 # primary bottom
				src_mid = 1 # primary middle
				src_top = 2 # primary top
				local_id = metatile_id

			var tx: int = local_id % 8
			var ty: int = local_id / 8
			var atlas_pos: Vector2i = Vector2i(tx, ty)
			var cell_pos: Vector2i = Vector2i(x, y)

			# Paint the 3-layer stack
			terrain.set_cell(0, cell_pos, src_bot, atlas_pos)
			terrain.set_cell(1, cell_pos, src_mid, atlas_pos)

			# Route top sub-tiles based on metatile layer type.
			# COVERED (1): both layers render behind the player — put top on terrain layer 2.
			# NORMAL (0) or SPLIT (2): top layer renders above player — put on decoration.
			var attrs: PackedByteArray = prim_attrs if metatile_id < 512 else sec_attrs
			if _get_layer_type(attrs, local_id) == LAYER_COVERED:
				terrain.set_cell(2, cell_pos, src_top, atlas_pos)
			else:
				deco.set_cell(0, cell_pos, src_top, atlas_pos)

			# Behavior must be read before the collision check so ledge tiles can be excluded.
			var behavior: int = _get_behavior_byte(attrs, local_id)
			var is_ledge: bool = behavior == MB_JUMP_EAST or behavior == MB_JUMP_WEST \
				or behavior == MB_JUMP_NORTH or behavior == MB_JUMP_SOUTH

			if coll_bits != 0 and not warp_positions.has(cell_pos) and not is_ledge:
				# Source 6 = solid collision tile. 
				coll.set_cell(0, cell_pos, 6, Vector2i(0, 0))

			# Bucket by encounter type for EncounterZones baking.
			var enc_type: String = _behavior_to_encounter_type(behavior)
			if not enc_type.is_empty():
				encounter_tiles[enc_type].append(cell_pos)

	bin_file.close()

	# ── Root metadata ───────────────────────────────────────────────────────
	# Derive pokeemerald MAP_ID from raw_name for zone lookup.
	var map_id_key: String = "MAP_" + _name_to_snake(raw_name).to_upper()
	var zone_id: String = _map_zone_ids.get(map_id_key, "")
	scene_root.set_meta("zone_id", zone_id)
	scene_root.set_meta("map_id", map_id_key)
	scene_root.set_meta("is_toz_variant", is_toz_variant)
	scene_root.set_meta("tile_size", 16)
	scene_root.set_meta("map_dimensions_px", Vector2i(width * 16, height * 16))

	# Apply TOZ tint if requested via feature flag or matching zone_id.
	if is_toz_variant and TOZ_TINTS.has(zone_id):
		var tint: Color = TOZ_TINTS[zone_id]
		terrain.modulate = tint
		deco.modulate = tint
		print("  [TOZ] Tinted map '%s' for zone '%s'." % [raw_name, zone_id])

	# ── Encounter zones ──────────────────────────────────────────────────────
	# One Area2D per encounter type, with a CollisionShape2D per tile.
	# collision_layer=4 matches Player's EncounterDetector collision_mask=4.
	_build_encounter_zones(scene_root, encounter_tiles, zone_id)

	# ── Save .tscn ─────────────────────────────────────────────────────────
	var packed := PackedScene.new()
	packed.pack(scene_root)
	scene_root.free()

	var err := ResourceSaver.save(packed, out_path)
	if err == OK:
		return true
	else:
		print("  ERROR saving ", out_path, "  err=", err)
		return false


# ─────────────────────────────────────────────────────────────────────────────
func _build_tileset(prim_bot: String, prim_mid: String, prim_top: String,
					sec_bot: String, sec_mid: String, sec_top: String,
					prim_name: String, sec_name: String) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	# ── Layers must be added BEFORE setting tile data ─────────────────────
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "behavior")
	ts.set_custom_data_layer_type(0, TYPE_INT)

	# ── Sources 0-5: visual layers (no physics polygons) ──────────────────
	var paths := [prim_bot, prim_mid, prim_top, sec_bot, sec_mid, sec_top]
	for source_id in range(6):
		var path: String = paths[source_id]
		if not ResourceLoader.exists(path):
			# print("  INFO: skipping missing layer texture: ", path)
			continue
			
		var tex: Texture2D = load(path)
		if not tex:
			continue
			
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(16, 16)
		
		var tiles_x := tex.get_width() / 16
		var tiles_y := tex.get_height() / 16
		
		# 1. Create all tiles in the source first
		for tx in range(tiles_x):
			for ty in range(tiles_y):
				src.create_tile(Vector2i(tx, ty))

		# 2. Add source to TileSet (this links the above tiles to the TileSet)
		ts.add_source(src, source_id)
		
		# Load attributes for this source
		var attrs: PackedByteArray
		if source_id < 3:
			attrs = _load_attrs(POKEEMERALD + "/data/tilesets/primary/" + prim_name.replace("primary_", "") + "/metatile_attributes.bin")
		else:
			attrs = _load_attrs(POKEEMERALD + "/data/tilesets/secondary/" + sec_name.replace("secondary_", "") + "/metatile_attributes.bin")

		# 3. Now set custom data (the tiles now possess the TileSet's custom data layers)
		for tx in range(tiles_x):
			for ty in range(tiles_y):
				var atlas_pos := Vector2i(tx, ty)
				var tile_idx := ty * 8 + tx
				var behavior := _get_behavior_byte(attrs, tile_idx)
				src.get_tile_data(atlas_pos, 0).set_custom_data("behavior", behavior)

	# ── Source 6: invisible solid collision tile ───────────────────────────
	# Painted on TileMapCollision wherever coll_bits != 0 in the layout.
	var col_tex: Texture2D = load(prim_bot)
	var col_src := TileSetAtlasSource.new()
	col_src.texture = col_tex
	col_src.texture_region_size = Vector2i(16, 16)
	col_src.create_tile(Vector2i(0, 0))
	ts.add_source(col_src, 6) # ← register as ID 6
	var tile_data: TileData = col_src.get_tile_data(Vector2i(0, 0), 0)
	tile_data.add_collision_polygon(0)
	# Full 16×16 solid rectangle in tile-local coords (centre = 0,0).
	tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-8.0, -8.0), Vector2(8.0, -8.0),
		Vector2(8.0, 8.0), Vector2(-8.0, 8.0),
	]))

	return ts


# ─────────────────────────────────────────────────────────────────────────────
## "gTileset_MauvilleGym" → "secondary_mauville_gym"
## "gTileset_General"     → "primary_general"
## Returns "" for invalid names (e.g. "0").
func _gname_to_tileset(gname: String, is_primary: bool) -> String:
	if not gname.begins_with("gTileset_"):
		return ""
	var short := gname.replace("gTileset_", "")
	var snake := _camel_to_snake(short)
	return ("primary_" if is_primary else "secondary_") + snake


## "MauvilleGym" → "mauville_gym"   "SecretBaseBlueCave" → "secret_base_blue_cave"
func _camel_to_snake(s: String) -> String:
	var result := ""
	for i in range(s.length()):
		var c := s[i]
		if i > 0 and c >= "A" and c <= "Z":
			result += "_"
		result += c.to_lower()
	return result


## "LittlerootTown_BrendansHouse_1F" → "littleroot_town_brendans_house_1_f"
## (applies camel_to_snake to each underscore-separated segment)
func _name_to_snake(name: String) -> String:
	var parts := name.split("_")
	var result := PackedStringArray()
	for part in parts:
		result.append(_camel_to_snake(part))
	return "_".join(result)


## Determine the maps/hoenn/ sub-directory.
## Route* (including Route*_X variants) → routes
## Underscore maps (buildings, multi-floor) → interiors
## Everything else (cities, towns, landmarks) → cities
func _get_category(name: String) -> String:
	if name.begins_with("Route"):
		return "routes"
	elif "_" in name:
		return "interiors"
	else:
		return "cities"


# ─────────────────────────────────────────────────────────────────────────────
## Loads (and caches) a pokeemerald metatile_attributes.bin file.
## Each entry is a little-endian u16; bits 12-15 encode the layer type.
## Returns an empty PackedByteArray if the file does not exist (safe default).
func _load_attrs(path: String) -> PackedByteArray:
	if _attr_cache.has(path):
		return _attr_cache[path]
	var f := FileAccess.open(path, FileAccess.READ)
	var data := PackedByteArray()
	if f:
		data = f.get_buffer(f.get_length())
		f.close()
	_attr_cache[path] = data
	return data


## Extracts the METATILE_LAYER_TYPE from bits 12-15 of the u16 attribute word.
## Returns LAYER_NORMAL (0) if attrs is empty or metatile_idx is out of range.
func _get_layer_type(attrs: PackedByteArray, metatile_idx: int) -> int:
	var offset: int = metatile_idx * 2
	if attrs.is_empty() or offset + 1 >= attrs.size():
		return LAYER_NORMAL
	var attr: int = attrs[offset] | (attrs[offset + 1] << 8)
	return (attr >> 12) & 0xF


## Extracts bits 0-7 (MetatileBehavior byte) from the u16 attribute word.
## Returns 0 (MB_NORMAL) if attrs is empty or metatile_idx is out of range.
func _get_behavior_byte(attrs: PackedByteArray, metatile_idx: int) -> int:
	var offset: int = metatile_idx * 2
	if attrs.is_empty() or offset + 1 >= attrs.size():
		return 0
	var attr: int = attrs[offset] | (attrs[offset + 1] << 8)
	return attr & 0xFF


## Maps a behavior byte to an encounter type string, or "" if not an encounter tile.
func _behavior_to_encounter_type(behavior: int) -> String:
	match behavior:
		MB_TALL_GRASS, MB_LONG_GRASS, MB_SHORT_GRASS, \
		MB_LONG_GRASS_SOUTH_EDGE, MB_ASHGRASS:
			return "grass"
		MB_CAVE:
			return "cave"
		MB_INDOOR_ENCOUNTER:
			return "indoor"
		MB_POND_WATER, MB_INTERIOR_DEEP_WATER, MB_DEEP_WATER, \
		MB_OCEAN_WATER, MB_SHALLOW_WATER:
			return "water"
	return ""


## Builds the EncounterZones node under [param root] using pre-bucketed tile positions.
## Creates one Area2D per encounter type (grass/water/cave/indoor) with one
## CollisionShape2D (RectangleShape2D 16×16) child per tile position.
## Area2Ds carry collision_layer=4 (matching Player.EncounterDetector mask=4),
## metadata/zone_id (may be "" for non-TOZ maps), and metadata/encounter_type.
func _build_encounter_zones(root: Node2D, encounter_tiles: Dictionary,
		zone_id: String) -> void:
	# Check if there are any encounter tiles at all.
	var has_any := false
	for enc_type: String in encounter_tiles:
		if not (encounter_tiles[enc_type] as Array).is_empty():
			has_any = true
			break
	if not has_any:
		return

	var zones_node := Node2D.new()
	zones_node.name = "EncounterZones"
	root.add_child(zones_node)
	zones_node.owner = root

	for enc_type: String in encounter_tiles:
		var positions: Array = encounter_tiles[enc_type]
		if positions.is_empty():
			continue

		var area := Area2D.new()
		area.name = enc_type.capitalize() + "EncounterZone"
		area.collision_layer = 4
		area.collision_mask = 0
		area.set_meta("zone_id", zone_id)
		area.set_meta("encounter_type", enc_type)
		zones_node.add_child(area)
		area.owner = root

		for tile_pos: Vector2i in positions:
			var shape_node := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(16.0, 16.0)
			shape_node.shape = rect
			# Position each shape at the pixel centre of its tile.
			shape_node.position = Vector2(tile_pos.x * 16 + 8, tile_pos.y * 16 + 8)
			area.add_child(shape_node)
			shape_node.owner = root
