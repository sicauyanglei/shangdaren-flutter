from PIL import Image
import os

path = os.path.join(r'E:\AI-PRJ\shangdaren-game', 'screenshot7.png')
img = Image.open(path)
w, h = img.size
print(f"Screenshot7: {w}x{h}")

# Find teal button center
teal_pixels = []
for y in range(200, 550):
    for x in range(350, 950):
        r, g, b, a = img.getpixel((x, y))
        if r > 50 and r < 120 and g > 170 and g < 230 and b > 160 and b < 220:
            teal_pixels.append((x, y))

if teal_pixels:
    min_x = min(p[0] for p in teal_pixels)
    max_x = max(p[0] for p in teal_pixels)
    min_y = min(p[1] for p in teal_pixels)
    max_y = max(p[1] for p in teal_pixels)
    center_x = (min_x + max_x) // 2
    center_y = (min_y + max_y) // 2
    print(f"Teal button: ({min_x},{min_y}) to ({max_x},{max_y}), center=({center_x},{center_y})")
    print(f"Teal pixel count: {len(teal_pixels)}")
else:
    print("No teal button found - game may have already started!")
    
    # Check for hand cards
    bottom = img.crop((0, int(h*0.7), w, h))
    bp = list(bottom.getdata())
    white = sum(1 for p in bp if p[0] > 200 and p[1] > 200 and p[2] > 200)
    print(f"White in bottom 30%: {white/len(bp)*100:.1f}%")
