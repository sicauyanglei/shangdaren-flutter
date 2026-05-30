from PIL import Image

img = Image.open('screen_topleft.png')
w, h = img.size
print(f'Screen: {w}x{h}')

# Search for red rectangle at (0,0)
print('\nSearching for red pixels:')
red_pixels = []
for y in range(0, 50, 1):
    for x in range(0, 300, 1):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] < 50 and p[2] < 50:
            red_pixels.append((x, y))

if red_pixels:
    min_x = min(p[0] for p in red_pixels)
    max_x = max(p[0] for p in red_pixels)
    min_y = min(p[1] for p in red_pixels)
    max_y = max(p[1] for p in red_pixels)
    print(f'  Red area: x={min_x}-{max_x}, y={min_y}-{max_y}')
else:
    print('  No red pixels found in top-left area')

# Wider search
for y in range(0, h, 3):
    for x in range(0, w, 3):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] < 50 and p[2] < 50 and y > 5:
            print(f'  Red at ({x},{y}): {p[:3]}')
            break
    else:
        continue
    break

# Check green area
green_start = None
green_end = None
for x in range(0, w):
    p = img.getpixel((x, 360))
    if 5 < p[0] < 80 and 30 < p[1] < 100 and 10 < p[2] < 60:
        if green_start is None:
            green_start = x
        green_end = x
print(f'Green area at y=360: x={green_start}-{green_end}')

# Check (0,0) pixel
p = img.getpixel((0, 0))
print(f'Pixel (0,0): {p[:3]}')
p = img.getpixel((0, 20))
print(f'Pixel (0,20): {p[:3]}')
