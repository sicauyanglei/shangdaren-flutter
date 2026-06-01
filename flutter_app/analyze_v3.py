from PIL import Image

fl = Image.open('screen_v3.png')
w, h = fl.size

# Read the debug text more carefully
print('Debug text area:')
for y in range(18, 28, 1):
    row = []
    for x in range(0, 350, 1):
        p = fl.getpixel((x, y))
        if p[1] > 150 and p[0] < 100 and p[2] < 100:
            row.append('#')
        elif p[0] > 100 or p[1] > 100 or p[2] > 100:
            row.append('.')
        else:
            row.append(' ')
    line = ''.join(row)
    if '#' in line:
        print(f'  y={y}: {line}')

# Check overlay elements more carefully
# Right player - search wider area
print('\nRight player search (wider):')
for y in range(0, 200, 3):
    for x in range(w-200, w, 3):
        p = fl.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'  Gold at ({x},{y}): {p[:3]}')
            break
    else:
        continue
    break

# Round info - search wider
print('\nRound info search (wider):')
for y in range(h-50, h, 3):
    for x in range(w-200, w, 3):
        p = fl.getpixel((x, y))
        if p[0] > 100 and p[1] > 100:
            print(f'  Light at ({x},{y}): {p[:3]}')
            break
    else:
        continue
    break

# Time display - search wider
print('\nTime display search (wider):')
for y in range(0, 40, 3):
    for x in range(400, 900, 3):
        p = fl.getpixel((x, y))
        if p[0] > 150 or p[1] > 150 or p[2] > 150:
            if not (p[0] > 200 and p[1] > 150 and p[2] < 50):
                print(f'  Light at ({x},{y}): {p[:3]}')
                break
    else:
        continue
    break

# Zimo badge - search wider
print('\nZimo badge search (wider):')
for y in range(h-300, h, 5):
    for x in range(300, w-300, 5):
        p = fl.getpixel((x, y))
        if p[0] > 200 and p[1] > 50 and p[1] < 120 and p[2] < 80:
            print(f'  Red at ({x},{y}): {p[:3]}')
            break
    else:
        continue
    break

# Check what's at the bottom of the screen
print('\nBottom area detail (y=600-720):')
for y in range(600, 720, 10):
    for x in range(0, w, 40):
        p = fl.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p[:3]}')

# Check center area for hand cards
print('\nCenter-bottom area (y=500-700):')
for y in range(500, 700, 20):
    for x in range(300, w-300, 20):
        p = fl.getpixel((x, y))
        if p[0] > 200 and p[1] > 200 and p[2] > 200:
            print(f'  White at ({x},{y}): {p[:3]}')
