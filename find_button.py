from PIL import Image
import os

path = os.path.join(r'E:\AI-PRJ\shangdaren-game', 'screenshot4.png')
img = Image.open(path)
w, h = img.size

# Search for teal/cyan pixels (start button color: #4ecdc4 = RGB(78, 205, 196))
teal_pixels = []
for y in range(h):
    for x in range(w):
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
    print(f"Teal pixels found: {len(teal_pixels)}")
    print(f"Teal region: ({min_x},{min_y}) to ({max_x},{max_y})")
    print(f"Teal center: ({center_x},{center_y})")
else:
    print("No teal pixels found!")

# Also search for white text pixels in center area
white_pixels = []
for y in range(250, 500):
    for x in range(400, 900):
        r, g, b, a = img.getpixel((x, y))
        if r > 230 and g > 230 and b > 230:
            white_pixels.append((x, y))

if white_pixels:
    min_x = min(p[0] for p in white_pixels)
    max_x = max(p[0] for p in white_pixels)
    min_y = min(p[1] for p in white_pixels)
    max_y = max(p[1] for p in white_pixels)
    print(f"White text region: ({min_x},{min_y}) to ({max_x},{max_y})")
    print(f"White text count: {len(white_pixels)}")
else:
    print("No white text found in center area")

# Search for the red pixel area
red_pixels = []
for y in range(300, 420):
    for x in range(580, 700):
        r, g, b, a = img.getpixel((x, y))
        if r > 200 and g < 50 and b < 50:
            red_pixels.append((x, y))

if red_pixels:
    min_x = min(p[0] for p in red_pixels)
    max_x = max(p[0] for p in red_pixels)
    min_y = min(p[1] for p in red_pixels)
    max_y = max(p[1] for p in red_pixels)
    print(f"Red region: ({min_x},{min_y}) to ({max_x},{max_y})")
    print(f"Red pixel count: {len(red_pixels)}")
