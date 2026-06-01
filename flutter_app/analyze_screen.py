from PIL import Image

img = Image.open('screen6.png')
w, h = img.size
print(f'Screen: {w}x{h}')

print('Layout map (sampling every 100px):')
for y in [0, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1199]:
    row = []
    for x in range(0, w, 100):
        p = img.getpixel((x, y))
        if p[0] < 30 and p[1] < 30 and p[2] < 30:
            c = '.'
        elif abs(p[0]-128) < 20 and abs(p[1]-128) < 20 and abs(p[2]-128) < 20:
            c = 'g'
        elif p[1] > p[0] and p[1] > p[2] and p[1] > 50:
            c = 'G'
        elif p[0] > 200 and p[1] > 200 and p[2] > 200:
            c = 'W'
        elif p[0] > 200 and p[1] > 150 and p[2] < 100:
            c = 'Y'
        elif p[0] > 200 and p[1] < 100 and p[2] < 100:
            c = 'R'
        elif p[0] > 100 and p[1] > 100 and p[2] > 100:
            c = 'L'
        else:
            c = 'x'
        row.append(c)
    line = ' '.join(row)
    print(f'  y={y:4d}: {line}')

print('\nFinding game canvas boundaries...')
green_start = None
green_end = None
for x in range(0, w):
    p = img.getpixel((x, 600))
    if 30 < p[0] < 120 and 40 < p[1] < 130 and 20 < p[2] < 90:
        if green_start is None:
            green_start = x
        green_end = x
print(f'Green area at y=600: x={green_start} to x={green_end}')

green_start2 = None
green_end2 = None
for x in range(0, w):
    p = img.getpixel((x, 100))
    if 30 < p[0] < 120 and 40 < p[1] < 130 and 20 < p[2] < 90:
        if green_start2 is None:
            green_start2 = x
        green_end2 = x
if green_start2:
    print(f'Green area at y=100: x={green_start2} to x={green_end2}')
else:
    print(f'No green at y=100')
    for x in range(0, w, 200):
        p = img.getpixel((x, 100))
        print(f'  ({x},100): {p}')

# Find overlay elements - search for non-black, non-green, non-gray pixels
print('\nSearching for overlay elements (non-game pixels):')
overlay_pixels = []
for y in range(0, h, 10):
    for x in range(0, w, 10):
        p = img.getpixel((x, y))
        r, g, b = p[0], p[1], p[2]
        # Skip game background (green), black, and gray letterbox
        if 30 < r < 120 and 40 < g < 130 and 20 < b < 90:
            continue
        if r < 30 and g < 30 and b < 30:
            continue
        if abs(r-128) < 20 and abs(g-128) < 20 and abs(b-128) < 20:
            continue
        # This might be an overlay element
        if r > 150 or g > 150 or b > 150:
            overlay_pixels.append((x, y, p))

print(f'Found {len(overlay_pixels)} potential overlay pixels')
# Group by region
regions = {}
for x, y, p in overlay_pixels:
    rx = x // 200 * 200
    ry = y // 200 * 200
    key = f'({rx}-{rx+199},{ry}-{ry+199})'
    if key not in regions:
        regions[key] = 0
    regions[key] += 1

for key, count in sorted(regions.items(), key=lambda x: -x[1])[:15]:
    print(f'  {key}: {count} pixels')
