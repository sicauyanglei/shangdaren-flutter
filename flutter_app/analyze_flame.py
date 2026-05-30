from PIL import Image

img = Image.open('screen_flame.png')
w, h = img.size
print(f'Flame Screen: {w}x{h}')

# Create a visual map
print('\nLayout map (sampling every 100px):')
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

# Find red border (debug border we added)
print('\nSearching for red border (R>200, G<100, B<100):')
red_pixels = []
for y in range(0, h, 3):
    for x in range(0, w, 3):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] < 100 and p[2] < 100:
            red_pixels.append((x, y))
            if len(red_pixels) > 50:
                break
    if len(red_pixels) > 50:
        break

if red_pixels:
    min_x = min(p[0] for p in red_pixels)
    max_x = max(p[0] for p in red_pixels)
    min_y = min(p[1] for p in red_pixels)
    max_y = max(p[1] for p in red_pixels)
    print(f'  Red border bounds: x={min_x}-{max_x}, y={min_y}-{max_y}')
    print(f'  Red border size: {max_x-min_x+1}x{max_y-min_y+1}')
    for p in red_pixels[:10]:
        print(f'  Red at ({p[0]},{p[1]})')
else:
    print('  No red border found!')

# Find green game area
print('\nGreen game area boundaries:')
for y_test in [100, 300, 600, 900]:
    start = None
    end = None
    for x in range(0, w):
        p = img.getpixel((x, y_test))
        if 30 < p[0] < 120 and 40 < p[1] < 130 and 20 < p[2] < 90:
            if start is None:
                start = x
            end = x
    if start:
        print(f'  y={y_test}: green x={start}-{end} (width={end-start+1})')
    else:
        print(f'  y={y_test}: no green found')

# Find debug text (green text on black bg)
print('\nSearching for debug text area:')
for y in range(0, 50, 2):
    for x in range(0, 500, 2):
        p = img.getpixel((x, y))
        if p[1] > 150 and p[0] < 100:
            print(f'  Green text pixel at ({x},{y}): {p}')
            break
    else:
        continue
    break

# Check top-left corner for overlay elements
print('\nTop-left corner detail (0-200, 0-100):')
for y in range(0, 100, 10):
    for x in range(0, 200, 20):
        p = img.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p}')
