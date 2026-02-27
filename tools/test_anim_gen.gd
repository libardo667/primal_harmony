extends SceneTree

func _init():
	var ts = TileSet.new()
	var tsas = TileSetAtlasSource.new()
	tsas.texture = load("res://assets/tilesets/secondary_mauville_bottom.png")
	tsas.texture_region_size = Vector2i(16, 16)
	tsas.create_tile(Vector2i(0, 0))
	tsas.set_tile_animation_columns(Vector2i(0, 0), 1)
	tsas.set_tile_animation_frames_count(Vector2i(0, 0), 4)
	tsas.set_tile_animation_frame_duration(Vector2i(0, 0), 0, 0.5)
	
	ts.add_source(tsas)
	
	ResourceSaver.save(ts, "res://tools/test_anim.tres")
	print("Saved test_anim.tres")
