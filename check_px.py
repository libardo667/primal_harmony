from PIL import Image

img = Image.open("assets/tilesets/secondary_mauville_bottom.png").convert("RGBA")
ax, ay = 1, 0
pixels = list(img.crop((ax*16, ay*16, ax*16+16, ay*16+16)).getdata())
t = sum(1 for p in pixels if p[3] == 0)
print("Mauville mt1 atlas(%d,%d): %d/256 transparent" % (ax, ay, t))

img2 = Image.open("assets/tilesets/primary_general_bottom.png").convert("RGBA")
ax, ay = 4, 0
p2 = list(img2.crop((ax*16, ay*16, ax*16+16, ay*16+16)).getdata())
t2 = sum(1 for p in p2 if p[3] == 0)
print("Primary mt4 flower atlas(%d,%d): %d/256 transparent" % (ax, ay, t2))
ax2, ay2 = 44 % 8, 44 // 8
p3 = list(img2.crop((ax2*16, ay2*16, ax2*16+16, ay2*16+16)).getdata())
t3 = sum(1 for p in p3 if p[3] == 0)
print("Primary mt44 water atlas(%d,%d): %d/256 transparent" % (ax2, ay2, t3))
