from PIL import Image

img = Image.open('screen_default_vp.png')
w, h = img.size

# Detailed scan of the top area
print('Top area detail (y=0-50):')
for y in range(0, 50, 5):
    for x in range(0, 300, 20):
        p = img.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p[:3]}')

# Check where green game background starts
print('\nGreen background start (scanning from top):')
for y in range(0, 200, 5):
    p = img.getpixel((640, y))
    if 5 < p[0] < 80 and 30 < p[1] < 100 and 10 < p[2] < 60:
        print(f'  Green starts at y={y}: {p[:3]}')
        break

# Check where gray ends
print('\nGray area (scanning from top):')
for y in range(0, 200, 5):
    p = img.getpixel((640, y))
    if p[0] > 100 and p[1] > 100 and p[2] > 100:
        print(f'  Gray at y={y}: {p[:3]}')
    else:
        print(f'  Not gray at y={y}: {p[:3]}')
        break

# Check game rendering area
print('\nGame rendering area (y=50-700):')
for y in [50, 100, 200, 300, 400, 500, 600, 700]:
    p = img.getpixel((640, y))
    print(f'  ({640},{y}): {p[:3]}')

# Left player avatar area detail
print('\nLeft player avatar detail:')
for y in range(10, 70, 5):
    for x in range(0, 80, 5):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'  Gold at ({x},{y}): {p[:3]}')

# Right player avatar area detail
print('\nRight player avatar detail:')
for y in range(10, 70, 5):
    for x in range(w-80, w, 5):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'  Gold at ({x},{y}): {p[:3]}')

# My player info
print('\nMy player info (bottom-left):')
for y in range(h-80, h, 5):
    for x in range(0, 150, 5):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'  Gold at ({x},{y}): {p[:3]}')

# Hand cards area
print('\nHand cards (bottom center):')
for y in range(h-200, h, 10):
    for x in range(300, 900, 20):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] > 200 and p[2] > 200:
            print(f'  White at ({x},{y}): {p[:3]}')
            break
    else:
        continue
    break

# Deck area
print('\nDeck area (top-left):')
for y in range(20, 80, 5):
    for x in range(100, 300, 5):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] > 180 and p[2] < 50:
            print(f'  Gold at ({x},{y}): {p[:3]}')
            break
    else:
        continue
    break

# Compare with WebView
wv = Image.open('wv_game_state.png')
print(f'\n=== WebView comparison ===')
print(f'WebView: {wv.size}')

# WebView top area
print('WV Top area (y=0-50):')
for y in range(0, 50, 5):
    for x in range(0, 300, 20):
        p = wv.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p[:3]}')
