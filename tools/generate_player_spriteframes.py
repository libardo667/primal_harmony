import sys

def main():
    players = ["brendan", "may"]
    for player in players:
        walk_path = f"res://assets/sprites/player/{player}/walking.png"
        run_path = f"res://assets/sprites/player/{player}/running.png"
        
        out = []
        
        # Header
        out.append('[gd_resource type="SpriteFrames" load_steps=100 format=3]\n')
        out.append(f'[ext_resource type="Texture2D" path="{walk_path}" id="1_walk"]')
        out.append(f'[ext_resource type="Texture2D" path="{run_path}" id="2_run"]')
        out.append("")
        
        dirs = ["down", "up", "left"]
        
        sub_resources = []
        animations = []
        
        subres_id = 1
        
        def add_atlas(tex_id, x, y, w, h):
            nonlocal subres_id
            current_id = f"AtlasTexture_{subres_id}"
            sub_resources.append(f'[sub_resource type="AtlasTexture" id="{current_id}"]')
            sub_resources.append(f'atlas = ExtResource("{tex_id}")')
            sub_resources.append(f'region = Rect2({x}, {y}, {w}, {h})')
            sub_resources.append("")
            subres_id += 1
            return current_id
            
        for i, d in enumerate(dirs):
            # idle: frame i
            idx_idle = i
            id_idle = add_atlas("1_walk", idx_idle * 16, 0, 16, 32)
            
            animations.append(f'{{\n"frames": [{{\n"duration": 1.0,\n"texture": SubResource("{id_idle}")\n}}],\n"loop": true,\n"name": &"idle_{d}",\n"speed": 5.0\n}}')
            
            # walk: step1, idle, step2, idle
            walk_frames = [
                add_atlas("1_walk", (3 + i * 2) * 16, 0, 16, 32),
                id_idle,
                add_atlas("1_walk", (4 + i * 2) * 16, 0, 16, 32),
                id_idle
            ]
            
            frames_str = ",\n".join([f'{{\n"duration": 1.0,\n"texture": SubResource("{fid}")\n}}' for fid in walk_frames])
            animations.append(f'{{\n"frames": [{frames_str}],\n"loop": true,\n"name": &"walk_{d}",\n"speed": 6.0\n}}')
            
            # run: step1, idle, step2, idle
            id_run_idle = add_atlas("2_run", idx_idle * 16, 0, 16, 32)
            run_frames = [
                add_atlas("2_run", (3 + i * 2) * 16, 0, 16, 32),
                id_run_idle,
                add_atlas("2_run", (4 + i * 2) * 16, 0, 16, 32),
                id_run_idle
            ]
            
            run_frames_str = ",\n".join([f'{{\n"duration": 1.0,\n"texture": SubResource("{fid}")\n}}' for fid in run_frames])
            animations.append(f'{{\n"frames": [{run_frames_str}],\n"loop": true,\n"name": &"run_{d}",\n"speed": 10.0\n}}')
            
        out.extend(sub_resources)
        
        out.append("[resource]")
        anim_array = ",\n".join(animations)
        out.append(f'animations = [{anim_array}]')
        
        with open(f"assets/sprites/player/{player}/{player}_spriteframes.tres", "w") as f:
            f.write("\n".join(out))
        print(f"Generated {player} spriteframes.")

if __name__ == "__main__":
    main()
