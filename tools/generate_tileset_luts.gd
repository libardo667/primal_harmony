@tool
extends EditorScript

# This script generates a 256x1 Look-Up Table (LUT) ImageTexture from the ported 
# .pal files for a given tileset. It assumes 16 palettes, each with 16 colors.
# This LUT will be used by a custom shader to colorize the grayscale tiles.

func _run():
	var tileset_dir = "res://assets/tilesets"
	var dir = DirAccess.open(tileset_dir)
	if not dir:
		print("Could not open tilesets directory.")
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var tileset_names = []
	
	while file_name != "":
		# Looking for files like primary_general.png
		if not dir.current_is_dir() and file_name.ends_with(".png") and not file_name.ends_with(".import"):
			var base_name = file_name.replace(".png", "")
			tileset_names.append(base_name)
		file_name = dir.get_next()
		
	dir.list_dir_end()
	
	for t_name in tileset_names:
		_generate_lut(t_name)

func _generate_lut(tileset_name: String):
	var pal_dir_path = "res://assets/tilesets/palettes/" + tileset_name
	
	if not DirAccess.dir_exists_absolute(pal_dir_path):
		return # Some tilesets might not have palettes downloaded/ported

	# Expected dimensions for GBA tileset palette: 256 colors (16 palettes * 16 colors)
	var img = Image.create_empty(256, 1, false, Image.FORMAT_RGBA8)
	
	for pal_index in range(16):
		var pal_file_name = "%02d.pal" % pal_index
		var pal_path = pal_dir_path + "/" + pal_file_name
		
		var file = FileAccess.open(pal_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			var lines = content.split("\n", false)
			
			# Expected JASC-PAL format:
			# Line 0: JASC-PAL
			# Line 1: 0100
			# Line 2: 16 (number of colors)
			# Line 3+: R G B
			
			var colors_found = 0
			for i in range(3, lines.size()):
				var line = lines[i].strip_edges()
				if line.is_empty():
					continue
					
				var rgb = line.split(" ", false)
				if rgb.size() == 3:
					var r = rgb[0].to_int() / 255.0
					var g = rgb[1].to_int() / 255.0
					var b = rgb[2].to_int() / 255.0
					img.set_pixel(pal_index * 16 + colors_found, 0, Color(r, g, b, 1.0))
					colors_found += 1
					
					if colors_found >= 16:
						break
			file.close()
		else:
			# If a palette file is missing, fill with magenta to make it obvious
			for i in range(16):
				img.set_pixel(pal_index * 16 + i, 0, Color(1, 0, 1, 1))

	# The first color of palette 0 is usually the background/transparent color in GBA
	# But in Godot, the texture transparency handles this. We'll leave it as is or make index 0 transparent.
	img.set_pixel(0, 0, Color(0, 0, 0, 0)) # Force absolute 0 to transparent just in case

	var tex = ImageTexture.create_from_image(img)
	var save_path = "res://assets/tilesets/palettes/" + tileset_name + "_lut.tres"
	var err = ResourceSaver.save(tex, save_path)
	
	if err == OK:
		print("Generated LUT for " + tileset_name + " -> " + save_path)
	else:
		print("Error generating LUT for " + tileset_name + ": ", err)
