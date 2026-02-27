import sys
from PIL import Image

def main():
    try:
        im = Image.open('assets/sprites/player/brendan/walking.png').convert('RGBA')
    except Exception as e:
        print("Failed to open image:", e)
        return

    chars = ' .:-=+*#%@'
    for f in range(9):
        print(f'\nFrame {f}:')
        for y in range(32):
            row = ""
            for x in range(16):
                p = im.getpixel((f*16+x, y))
                if p[3] > 0:
                     # Calculate brightness: (R+G+B)/(3*255) * 9
                     brightness = (p[0] + p[1] + p[2]) / (3.0 * 255.0)
                     v = int(brightness * 9)
                     row += chars[min(9, max(0, v))]
                else:
                     row += " "
            print(row)

if __name__ == '__main__':
    main()
