## build_anim_tilesets.gd
##
## Run from terminal (project root):
##   godot --headless --script res://tools/build_anim_tilesets.gd
##
## Reads every *_anim_config.json in assets/tilesets/anim/ and generates
## a TileSetAtlasSource .tres with Godot-native animated tiles.
## Output: assets/tilesets/{tileset_name}_anim_bottom.tres
##          assets/tilesets/{tileset_name}_anim_top.tres
##
## Run export_tileset_anim_frames.py first to generate the atlas PNGs and JSON.
## After this script runs, open the .tres files in the TileSet editor to
## visually review animation frames and tweak speeds if needed.

extends SceneTree

func _init() -> void:
	var anim_dir := "res://assets/tilesets/anim"
	var out_dir := "res://assets/tilesets"

	var dir := DirAccess.open(anim_dir)
	if dir == null:
		push_error("build_anim_tilesets: directory not found: " + anim_dir)
		quit()
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with("_anim_config.json"):
			_process_config(anim_dir + "/" + file_name, out_dir)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("build_anim_tilesets: done.")
	quit()


func _process_config(config_path: String, out_dir: String) -> void:
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open: " + config_path)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("Invalid JSON in: " + config_path)
		return

	var cfg: Dictionary = parsed
	var ts_name: String = cfg.get("tileset", "")
	var fps: float = float(cfg.get("fps", 3.75))
	var bottom_path: String = cfg.get("bottom_atlas", "")
	var middle_path: String = cfg.get("middle_atlas", "")
	var top_path: String = cfg.get("top_atlas", "")
	var metatile_map: Dictionary = cfg.get("animated_metatiles", {})

	if ts_name == "" or bottom_path == "" or metatile_map.is_empty():
		push_error("Incomplete config in: " + config_path)
		return

	print("  Processing: " + ts_name + "  (" + str(metatile_map.size()) + " animated metatiles)")

	for side in ["bottom", "middle", "top"]:
		var atlas_path: String = ""
		match side:
			"bottom": atlas_path = bottom_path
			"middle": atlas_path = middle_path
			"top": atlas_path = top_path
		
		if atlas_path == "": continue
		
		var out_path: String = out_dir + "/" + ts_name + "_anim_" + side + ".tres"
		_build_source(atlas_path, fps, metatile_map, out_path)


func _build_source(
		atlas_path: String,
		fps: float,
		metatile_map: Dictionary,
		out_path: String
) -> void:
	var tex: Texture2D = load(atlas_path) as Texture2D
	
	if tex == null and atlas_path.ends_with(".png"):
		var global_path = ProjectSettings.globalize_path(atlas_path)
		var img = Image.load_from_file(global_path)
		if img:
			tex = ImageTexture.create_from_image(img)
	
	if tex == null:
		push_error("Cannot load atlas texture: " + atlas_path)
		return

	var tsas := TileSetAtlasSource.new()
	tsas.texture = tex
	tsas.texture_region_size = Vector2i(16, 16)

	for m_str in metatile_map.keys():
		var entry: Dictionary = metatile_map[m_str]
		var row: int = int(entry.get("row", 0))
		var frame_count: int = int(entry.get("frame_count", 1))
		var coords := Vector2i(0, row)

		tsas.create_tile(coords)

		if frame_count <= 1:
			continue # Static tile — no animation properties needed

		# All frames are laid out horizontally: col 0..frame_count-1, same row.
		tsas.set_tile_animation_columns(coords, frame_count)
		tsas.set_tile_animation_frames_count(coords, frame_count)
		tsas.set_tile_animation_speed(coords, fps)
		for fi in range(frame_count):
			tsas.set_tile_animation_frame_duration(coords, fi, 1.0)

	var err := ResourceSaver.save(tsas, out_path)
	if err != OK:
		push_error("Failed to save: " + out_path + "  (error " + str(err) + ")")
	else:
		print("    Saved: " + out_path)
