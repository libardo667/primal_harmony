import os
from PIL import Image

def generate_spriteframes(png_path, out_path, resource_path):
    out = []
    
    # Header
    out.append('[gd_resource type="SpriteFrames" load_steps=100 format=3]\n')
    out.append(f'[ext_resource type="Texture2D" path="{resource_path}" id="1_tex"]')
    out.append("")
    
    dirs = ["down", "up", "left"]
    
    sub_resources = []
    animations = []
    
    subres_id = 1
    
    def add_atlas(x, y, w, h):
        nonlocal subres_id
        current_id = f"AtlasTexture_{subres_id}"
        sub_resources.append(f'[sub_resource type="AtlasTexture" id="{current_id}"]')
        sub_resources.append('atlas = ExtResource("1_tex")')
        sub_resources.append(f'region = Rect2({x}, {y}, {w}, {h})')
        sub_resources.append("")
        subres_id += 1
        return current_id
        
    for i, d in enumerate(dirs):
        # idle: frame i
        idx_idle = i
        id_idle = add_atlas(idx_idle * 16, 0, 16, 32)
        
        animations.append(f'{{\n"frames": [{{\n"duration": 1.0,\n"texture": SubResource("{id_idle}")\n}}],\n"loop": true,\n"name": &"idle_{d}",\n"speed": 5.0\n}}')
        
        # walk: step1, idle, step2, idle
        walk_frames = [
            add_atlas((3 + i * 2) * 16, 0, 16, 32),
            id_idle,
            add_atlas((4 + i * 2) * 16, 0, 16, 32),
            id_idle
        ]
        
        frames_str = ",\n".join([f'{{\n"duration": 1.0,\n"texture": SubResource("{fid}")\n}}' for fid in walk_frames])
        animations.append(f'{{\n"frames": [{frames_str}],\n"loop": true,\n"name": &"walk_{d}",\n"speed": 6.0\n}}')
        
    out.extend(sub_resources)
    
    out.append("[resource]")
    anim_array = ",\n".join(animations)
    out.append(f'animations = [{anim_array}]')
    
    with open(out_path, "w") as f:
        f.write("\n".join(out))

def main():
    base_dir = "assets/sprites/npcs"
    for root, _, files in os.walk(base_dir):
        for filename in files:
            if filename.endswith(".png") and not "_spriteframes" in filename:
                filepath = os.path.join(root, filename)
                # Only process if dimensions are typical for an NPC spritesheet
                try:
                    img = Image.open(filepath)
                    if img.size != (144, 32):
                        continue
                    # It's a 9-frame sprite sheet
                    name_no_ext = os.path.splitext(filename)[0]
                    out_path = os.path.join(root, f"{name_no_ext}_spriteframes.tres")
                    # Construct the Godot res:// path correctly by splitting at assets/
                    rel_path = filepath.replace("\\", "/").split("assets/sprites/npcs/")[1]
                    res_path = f"res://assets/sprites/npcs/{rel_path}"
                    generate_spriteframes(filepath, out_path, res_path)
                    print(f"Generated {out_path}")
                except Exception as e:
                    print(f"Skipping {filepath}: {e}")
            filepath = os.path.join(base_dir, filename)
            # Only process if dimensions are typical for an NPC spritesheet
            try:
                img = Image.open(filepath)
                if img.size != (144, 32):
                    continue
                # It's a 9-frame sprite sheet
                name_no_ext = os.path.splitext(filename)[0]
                out_path = os.path.join(base_dir, f"{name_no_ext}_spriteframes.tres")
                res_path = f"res://assets/sprites/npcs/{filename}"
                generate_spriteframes(filepath, out_path, res_path)
                print(f"Generated {out_path}")
            except Exception as e:
                print(f"Skipping {filepath}: {e}")

if __name__ == "__main__":
    main()
