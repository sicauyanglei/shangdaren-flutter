from PIL import Image

wv = Image.open('screen_webview.png')
fl = Image.open('screen_flame.png')

print(f'WebView: {wv.size}')
print(f'Flame: {fl.size}')

# WebView layout analysis
w, h = wv.size
print(f'\n=== WebView Layout Analysis ({w}x{h}) ===')
print('Layout map (sampling every 80px):')
for y in [0, 40, 80, 120, 160, 200, 280, 360, 440, 520, 600, 680]:
    row = []
    for x in range(0, w, 80):
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
        elif p[0] > 50 and p[1] < 50 and p[2] < 50:
            c = 'r'
        elif p[0] < 50 and p[1] > 50 and p[2] < 50:
            c = 'g'
        elif p[0] < 50 and p[1] < 50 and p[2] > 50:
            c = 'b'
        else:
            c = 'x'
        row.append(c)
    line = ' '.join(row)
    print(f'  y={y:4d}: {line}')

# Key element positions in WebView
print('\n=== Key Element Positions in WebView ===')

# Player left (top-left area)
print('Player left avatar area (0-80, 0-80):')
for y in range(0, 80, 10):
    for x in range(0, 80, 10):
        p = wv.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p}')

# Player right (top-right area)
print('\nPlayer right avatar area (1200-1280, 0-80):')
for y in range(0, 80, 10):
    for x in range(1200, 1280, 10):
        p = wv.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p}')

# My player (bottom-left area)
print('\nMy player area (0-200, 640-720):')
for y in range(640, 720, 10):
    for x in range(0, 200, 20):
        p = wv.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p}')

# Center area (deck, discards)
print('\nCenter area (400-880, 200-520):')
for y in range(200, 520, 40):
    for x in range(400, 880, 80):
        p = wv.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p}')

# Action buttons area
print('\nAction buttons area (400-880, 520-600):')
for y in range(520, 600, 10):
    for x in range(400, 880, 40):
        p = wv.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p}')

# Hand cards area (bottom)
print('\nHand cards area (400-880, 560-720):')
for y in range(560, 720, 20):
    for x in range(400, 880, 40):
        p = wv.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p}')

# Round info (bottom-right)
print('\nRound info (1200-1280, 680-720):')
for y in range(680, 720, 5):
    for x in range(1200, 1280, 10):
        p = wv.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p}')

# Time display (top center)
print('\nTime display (560-720, 0-30):')
for y in range(0, 30, 5):
    for x in range(560, 720, 20):
        p = wv.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p}')

# Settings gear (top-right)
print('\nSettings gear (1240-1280, 0-40):')
for y in range(0, 40, 5):
    for x in range(1240, 1280, 5):
        p = wv.getpixel((x, y))
        if p[0] > 100 or p[1] > 100 or p[2] > 100:
            print(f'  ({x},{y}): {p}')

# Now analyze Flame screenshot
print('\n\n=== Flame Layout Analysis ===')
fw, fh = fl.size
print(f'Flame screen: {fw}x{fh}')

# Calculate expected scale and offset
# BlueStacks resolution: 2664x1200
# Design: 1280x720
sx = fw / 1280
sy = fh / 720
s = min(sx, sy)
cw = 1280 * s
ch = 720 * s
ox = (fw - cw) / 2
oy = (fh - ch) / 2
print(f'Expected: scale={s:.4f}, canvas={cw:.1f}x{ch:.1f}, offset=({ox:.1f},{oy:.1f})')

# Check red border position to verify overlay alignment
print('\nRed border analysis:')
red_top = []
red_bottom = []
red_left = []
red_right = []
for x in range(0, fw, 5):
    p = fl.getpixel((x, 0))
    if p[0] > 200 and p[1] < 100 and p[2] < 100:
        red_top.append(x)
for x in range(0, fw, 5):
    p = fl.getpixel((x, fh-1))
    if p[0] > 200 and p[1] < 100 and p[2] < 100:
        red_bottom.append(x)
for y in range(0, fh, 5):
    p = fl.getpixel((0, y))
    if p[0] > 200 and p[1] < 100 and p[2] < 100:
        red_left.append(y)
for y in range(0, fh, 5):
    p = fl.getpixel((fw-1, y))
    if p[0] > 200 and p[1] < 100 and p[2] < 100:
        red_right.append(y)

if red_top:
    print(f'  Top: x={min(red_top)}-{max(red_top)}')
if red_bottom:
    print(f'  Bottom: x={min(red_bottom)}-{max(red_bottom)}')
if red_left:
    print(f'  Left: y={min(red_left)}-{max(red_left)}')
if red_right:
    print(f'  Right: y={min(red_right)}-{max(red_right)}')

# Debug text
print('\nDebug text area (searching for green text):')
for y in range(0, 50, 2):
    for x in range(0, 600, 2):
        p = fl.getpixel((x, y))
        if p[1] > 150 and p[0] < 100 and p[2] < 100:
            print(f'  Green text at ({x},{y}): {p}')
            break
    else:
        continue
    break

# Sample more of the debug text
for y in range(15, 35, 2):
    row_text = []
    for x in range(0, 500, 2):
        p = fl.getpixel((x, y))
        if p[1] > 100 and p[0] < 100:
            row_text.append(f'({x},{p[1]})')
    if row_text:
        print(f'  y={y}: {row_text[:5]}')
