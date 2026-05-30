from PIL import Image

img = Image.open('screen_stretch.png')
w, h = img.size
print(f'Screen: {w}x{h}')

# Check if game fills entire screen (no letterboxing)
print('\nCorner pixels:')
for name, x, y in [('TL', 0, 0), ('TR', w-1, 0), ('BL', 0, h-1), ('BR', w-1, h-1), ('Center', w//2, h//2)]:
    p = img.getpixel((x, y))
    print(f'  {name} ({x},{y}): {p}')

# Layout map
print('\nLayout map:')
for y_pos in [0, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1199]:
    row = []
    for x_pos in range(0, w, 100):
        p = img.getpixel((x_pos, y_pos))
        if p[0] < 30 and p[1] < 30 and p[2] < 30:
            c = '.'
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
    print(f'  y={y_pos:4d}: {line}')

# Check if green fills entire screen
green_found = False
for y_pos in range(0, h, 50):
    p = img.getpixel((0, y_pos))
    if 30 < p[0] < 120 and 40 < p[1] < 130 and 20 < p[2] < 90:
        green_found = True
        break
    p = img.getpixel((w-1, y_pos))
    if 30 < p[0] < 120 and 40 < p[1] < 130 and 20 < p[2] < 90:
        green_found = True
        break

print(f'\nGreen at edges: {green_found}')

# Check for gray letterbox bars
gray_at_top = False
gray_at_bottom = False
for x_pos in range(0, w, 50):
    p = img.getpixel((x_pos, 0))
    if abs(p[0]-128) < 20 and abs(p[1]-128) < 20 and abs(p[2]-128) < 20:
        gray_at_top = True
    p = img.getpixel((x_pos, h-1))
    if abs(p[0]-128) < 20 and abs(p[1]-128) < 20 and abs(p[2]-128) < 20:
        gray_at_bottom = True

print(f'Gray letterbox top: {gray_at_top}, bottom: {gray_at_bottom}')
