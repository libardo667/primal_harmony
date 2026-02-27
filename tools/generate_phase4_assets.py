import os
from PIL import Image, ImageDraw, ImageFont

# Define directories
trainers_dir = "assets/sprites/trainers/player"
os.makedirs(trainers_dir, exist_ok=True)
ui_dir = "assets/sprites/ui"
os.makedirs(ui_dir, exist_ok=True)

def create_placeholder(path, size, color, text):
    img = Image.new('RGBA', size, color)
    draw = ImageDraw.Draw(img)
    # Simple text drawing
    # Need to load default font
    try:
        font = ImageFont.load_default()
    except Exception:
        font = None
    
    if font:
        # Get text size
        bbox = draw.textbbox((0, 0), text, font=font)
        text_w = bbox[2] - bbox[0]
        text_h = bbox[3] - bbox[1]
        x = (size[0] - text_w) / 2
        y = (size[1] - text_h) / 2
        draw.text((x, y), text, fill=(255, 255, 255, 255), font=font)
    img.save(path)
    print(f"Created: {path}")

# Player Sprites (Overworld placeholders)
# Let's say 4 directions * 4 frames for walk = 16 frames. 16x16 pixels per frame.
# Sprite sheet size: 64x64
create_placeholder(f"{trainers_dir}/player_walk.png", (64, 64), (50, 150, 50, 255), "Walk")
create_placeholder(f"{trainers_dir}/player_run.png", (64, 64), (150, 50, 50, 255), "Run")
create_placeholder(f"{trainers_dir}/player_idle.png", (64, 64), (50, 50, 150, 255), "Idle")

# Ability UI
# banner: maybe 200x40
create_placeholder(f"{ui_dir}/ability_banner.png", (200, 40), (40, 40, 40, 200), "Ability")
# icon placeholder: 24x24
create_placeholder(f"{ui_dir}/ability_icon_placeholder.png", (24, 24), (100, 100, 100, 255), "A")

print("Done generating Phase 4 assets.")
