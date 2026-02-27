import struct

data = open('C:/Users/levib/pokemon_projects/pokeemerald/data/tilesets/primary/general/metatiles.bin', 'rb').read()
num_metatiles = len(data) // 16
print('Checking metatiles for tile indices 508, 509, 510, 511...')
found = False
for m in range(num_metatiles):
    layer_tiles = struct.unpack('<8H', data[m*16:(m+1)*16])
    for i in range(8):
        val = layer_tiles[i]
        t_idx = val & 0x03FF
        pal_idx = (val & 0xF000) >> 12
        if t_idx in [508, 509, 510, 511]:
            print(f'Metatile {m} layer {i} uses tile {t_idx} with pal_idx {pal_idx}')
            found = True
print('Done. Found:', found)
