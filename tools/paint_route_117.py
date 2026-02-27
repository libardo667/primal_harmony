import sys

def inject_tile_data(filepath, tilemap_name, tile_data):
    with open(filepath, 'r') as f:
        lines = f.readlines()
        
    out_lines = []
    in_target_node = False
    
    for line in lines:
        if line.startswith(f'[node name="{tilemap_name}" type="TileMap"'):
            in_target_node = True
            
        if in_target_node and line.startswith('tile_data ='):
            continue # We will write our own
            
        if in_target_node and line.startswith('[node'):
            if line.startswith(f'[node name="{tilemap_name}"'):
                pass
            else:
                # We reached the next node, inject here
                out_lines.append(f'tile_data = PackedInt32Array({", ".join(map(str, tile_data))})\n')
                in_target_node = False
                
        out_lines.append(line)
        
    if in_target_node:
        out_lines.append(f'tile_data = PackedInt32Array({", ".join(map(str, tile_data))})\n')
        
    with open(filepath, 'w') as f:
        f.writelines(out_lines)

# Route 117 is 60x40 tiles.
# Let's paint the terrain layer with grass (we'll guess grass is tile 0,0 in primary_general.png)
# In Godot 4, TileMap data is a PackedInt32Array. Each cell is 3 integers:
# [x, y, source_id, atlas_x, atlas_y, alternative_tile] packed into 2 integers (Godot 4 format is actually 2 ints per tile in PackedInt32Array for format 2? Wait no, format 2 uses 3 ints per cell: cell_coords.x, cell_coords.y, (source_id << 16) | (atlas_coords.x) | (atlas_coords.y << 16)...
# Actually Godot 4 format 2 PackedInt32Array is complex.
# The easiest way to inject tile data into a tscn is actually to let Godot do it, or just write a GDScript tool script.
