from PIL import Image

wv = Image.open('screen_wv_game.png')
fl = Image.open('screen_flame.png')

print(f'WebView game: {wv.size}')
print(f'Flame game: {fl.size}')

# Detailed WebView analysis
w, h = wv.size
print(f'\n=== WebView Game Layout ({w}x{h}) ===')

# Full layout map
print('Layout map:')
for y in range(0, h, 40):
    row = []
    for x in range(0, w, 40):
        p = wv.getpixel((x, y))
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
        elif p[0] > 50 and p[2] > 50 and p[1] < 50:
            c = 'P'
        elif p[2] > p[0] and p[2] > p[1] and p[2] > 50:
            c = 'B'
        else:
            c = 'x'
        row.append(c)
    line = ' '.join(row)
    print(f'  y={y:3d}: {line}')

# Find specific elements in WebView
print('\n=== WebView Element Search ===')

# Player left avatar
print('Player left (searching gold/green circle):')
for y in range(0, 80, 5):
    for x in range(0, 100, 5):
        p = wv.getpixel((x, y))
        if (p[0] > 200 and p[1] > 150 and p[2] < 50) or (p[0] > 200 and p[1] < 100 and p[2] < 100):
            print(f'  ({x},{y}): {p}')

# Player right avatar
print('\nPlayer right (searching top-right):')
for y in range(0, 80, 5):
    for x in range(1180, 1280, 5):
        p = wv.getpixel((x, y))
        if (p[0] > 200 and p[1] > 150 and p[2] < 50) or (p[0] > 200 and p[1] < 100 and p[2] < 100):
            print(f'  ({x},{y}): {p}')

# My player info (bottom-left)
print('\nMy player info (bottom-left):')
for y in range(640, 720, 5):
    for x in range(0, 200, 10):
        p = wv.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p}')

# Deck area (center-top)
print('\nDeck area (center, y=20-80):')
for y in range(20, 80, 10):
    for x in range(100, 400, 20):
        p = wv.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p}')

# Deck count number
print('\nDeck count (searching gold text):')
for y in range(20, 80, 3):
    for x in range(100, 400, 3):
        p = wv.getpixel((x, y))
        if p[0] > 200 and p[1] > 180 and p[2] < 50:
            print(f'  ({x},{y}): {p}')

# Hand cards (bottom area)
print('\nHand cards area (y=560-710):')
for y in range(560, 710, 20):
    for x in range(200, 1100, 40):
        p = wv.getpixel((x, y))
        if p[0] > 200 and p[1] > 200 and p[2] > 200:
            print(f'  White at ({x},{y}): {p}')
            break
    else:
        continue
    break

# Discard area center
print('\nCenter discard area (y=200-500):')
for y in range(200, 500, 40):
    for x in range(300, 1000, 40):
        p = wv.getpixel((x, y))
        if p[0] > 200 and p[1] > 200 and p[2] > 200:
            print(f'  White at ({x},{y}): {p}')

# Round info (bottom-right)
print('\nRound info (bottom-right):')
for y in range(690, 720, 3):
    for x in range(1200, 1280, 3):
        p = wv.getpixel((x, y))
        if p[0] > 150 or p[1] > 150 or p[2] > 150:
            print(f'  ({x},{y}): {p}')

# Time display
print('\nTime display (top center):')
for y in range(0, 30, 3):
    for x in range(500, 780, 3):
        p = wv.getpixel((x, y))
        if p[0] > 150 or p[1] > 150 or p[2] > 150:
            print(f'  ({x},{y}): {p}')

# Settings gear
print('\nSettings gear (top-right):')
for y in range(0, 40, 3):
    for x in range(1240, 1280, 3):
        p = wv.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p}')

# Left player discards
print('\nLeft player discards (left side, y=100-600):')
for y in range(100, 600, 40):
    for x in range(0, 100, 10):
        p = wv.getpixel((x, y))
        if p[0] > 200 and p[1] > 200 and p[2] > 200:
            print(f'  White at ({x},{y}): {p}')
            break

# Right player discards
print('\nRight player discards (right side, y=100-600):')
for y in range(100, 600, 40):
    for x in range(1180, 1280, 10):
        p = wv.getpixel((x, y))
        if p[0] > 200 and p[1] > 200 and p[2] > 200:
            print(f'  White at ({x},{y}): {p}')
            break

# My discards (bottom-left area)
print('\nMy discards (bottom-left, y=400-600):')
for y in range(400, 600, 20):
    for x in range(0, 200, 10):
        p = wv.getpixel((x, y))
        if p[0] > 200 and p[1] > 200 and p[2] > 200:
            print(f'  White at ({x},{y}): {p}')
            break
