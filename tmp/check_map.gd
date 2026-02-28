@tool
extends SceneTree

func _init():
	var map_path = "res://maps/hoenn/routes/route114.tscn"
	var scene = load(map_path)
	if not scene:
		print("Failed to load map")
		quit()
	
	var root = scene.instantiate()
	var terrain = root.find_child("TileMapTerrain", true, false) as TileMap
	var deco = root.find_child("TileMapDecoration", true, false) as TileMap
	
	var target = Vector2i(8, 63)
	print("Checking tiles at (8, 63):")
	
	for l in range(terrain.get_layers_count()):
		var source_id = terrain.get_cell_source_id(l, target)
		var atlas_coords = terrain.get_cell_atlas_coords(l, target)
		print("Terrain Layer %d: Source %d, Coords %s" % [l, source_id, atlas_coords])
		
	var d_source_id = deco.get_cell_source_id(0, target)
	var d_atlas_coords = deco.get_cell_atlas_coords(0, target)
	print("Decoration Layer 0: Source %d, Coords %s" % [d_source_id, d_atlas_coords])
	
	# Check surroundings
	print("\nSurroundings (Deco):")
	for dy in range(-2, 3):
		var line = ""
		for dx in range(-2, 3):
			var coords = target + Vector2i(dx, dy)
			var sid = deco.get_cell_source_id(0, coords)
			line += "[%d]" % sid if sid != -1 else "[. ]"
		print(line)
	
	root.free()
	quit()
