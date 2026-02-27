@tool
extends EditorScript

# Route 117 dimensions
const MAP_WIDTH = 60
const MAP_HEIGHT = 40

func _run():
	var scene_path = "res://maps/hoenn/routes/route_117.tscn"
	var packed_scene = ResourceLoader.load(scene_path)
	if not packed_scene:
		print("Could not load scene: ", scene_path)
		return
		
	var root = packed_scene.instantiate()
	var terrain: TileMap = root.get_node("TileMapTerrain")
	var deco: TileMap = root.get_node("TileMapDecoration")
	var coll: TileMap = root.get_node("TileMapCollision")
	
	if not terrain or not deco:
		print("Could not find TileMap nodes")
		return

	var ts = TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	var files = [
		{"id": 0, "path": "res://assets/tilesets/primary_general_bottom.png"},
		{"id": 1, "path": "res://assets/tilesets/primary_general_top.png"},
		{"id": 2, "path": "res://assets/tilesets/secondary_mauville_bottom.png"},
		{"id": 3, "path": "res://assets/tilesets/secondary_mauville_top.png"}
	]

	for file in files:
		var src = TileSetAtlasSource.new()
		var tex = load(file.path)
		if tex:
			src.texture = tex
			src.texture_region_size = Vector2i(16, 16)
			var tiles_x = tex.get_width() / 16
			var tiles_y = tex.get_height() / 16
			for tx in range(tiles_x):
				for ty in range(tiles_y):
					src.create_tile(Vector2i(tx, ty))
			ts.add_source(src, file.id)

	# Assign the newly built TileSet
	terrain.tile_set = ts
	deco.tile_set = ts
	coll.tile_set = ts

	# Clear existing spatial data
	terrain.clear()
	deco.clear()
	coll.clear()
	
	# Route 117 is 60x20
	var map_width = 60
	var map_height = 20
	var file = FileAccess.open("C:/Users/levib/pokemon_projects/pokeemerald/data/layouts/Route117/map.bin", FileAccess.READ)
	
	if not file:
		print("Could not open map.bin!")
		return
		
	for y in range(map_height):
		for x in range(map_width):
			var val = file.get_16()
			var metatile_id = val & 0x03FF
			
			var source_bottom = 0
			var source_top = 1
			var local_id = metatile_id
			
			if metatile_id >= 512:
				source_bottom = 2
				source_top = 3
				local_id = metatile_id - 512
				
			var tx = local_id % 8
			var ty = local_id / 8
			var atlas_pos = Vector2i(tx, ty)
			
			terrain.set_cell(0, Vector2i(x, y), source_bottom, atlas_pos)
			deco.set_cell(0, Vector2i(x, y), source_top, atlas_pos)
	file.close()

	# Save the modified scene
	var new_packed = PackedScene.new()
	new_packed.pack(root)
	var err = ResourceSaver.save(new_packed, scene_path)
	if err == OK:
		print("Successfully painted reference atlas sheet Route 117. Saved to ", scene_path)
	else:
		print("Error saving scene: ", err)
