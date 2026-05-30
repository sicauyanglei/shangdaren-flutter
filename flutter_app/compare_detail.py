from PIL import Image

wv = Image.open('wv_game_state.png')
fl = Image.open('screen_flame_compare.png')

print(f'WebView: {wv.size}')
print(f'Flame: {fl.size}')

if wv.size != fl.size:
    print('WARNING: Sizes differ! Resizing Flame to match WebView for comparison')
    fl = fl.resize(wv.size, Image.LANCZOS)

w, h = wv.size

# Side by side layout map
print('\n=== Layout Comparison (WV vs FL) ===')
for y in range(0, h, 40):
    wv_row = []
    fl_row = []
    for x in range(0, w, 40):
        p = wv.getpixel((x, y))
        if p[0] < 30 and p[1] < 30 and p[2] < 30:
            wv_row.append('.')
        elif p[1] > p[0] and p[1] > p[2] and p[1] > 50:
            wv_row.append('G')
        elif p[0] > 200 and p[1] > 200 and p[2] > 200:
            wv_row.append('W')
        elif p[0] > 200 and p[1] > 150 and p[2] < 100:
            wv_row.append('Y')
        elif p[0] > 200 and p[1] < 100 and p[2] < 100:
            wv_row.append('R')
        elif p[0] > 100 and p[1] > 100 and p[2] > 100:
            wv_row.append('L')
        else:
            wv_row.append('x')

        p = fl.getpixel((x, y))
        if p[0] < 30 and p[1] < 30 and p[2] < 30:
            fl_row.append('.')
        elif p[1] > p[0] and p[1] > p[2] and p[1] > 50:
            fl_row.append('G')
        elif p[0] > 200 and p[1] > 200 and p[2] > 200:
            fl_row.append('W')
        elif p[0] > 200 and p[1] > 150 and p[2] < 100:
            fl_row.append('Y')
        elif p[0] > 200 and p[1] < 100 and p[2] < 100:
            fl_row.append('R')
        elif p[0] > 100 and p[1] > 100 and p[2] > 100:
            fl_row.append('L')
        else:
            fl_row.append('x')

    wv_line = ' '.join(wv_row)
    fl_line = ' '.join(fl_row)
    diff = '  DIFF' if wv_line != fl_line else ''
    print(f'  y={y:3d}: WV={wv_line}')
    print(f'         FL={fl_line}{diff}')

# Key element position comparison
print('\n=== Key Element Positions ===')

# Player left avatar (gold circle)
print('\nPlayer Left Avatar:')
for y in range(0, 80, 5):
    for x in range(0, 100, 5):
        pw = wv.getpixel((x, y))
        pf = fl.getpixel((x, y))
        if (pw[0] > 200 and pw[1] > 150 and pw[2] < 50):
            print(f'  WV gold at ({x},{y}): {pw}')
            break
    else:
        continue
    break

for y in range(0, 80, 5):
    for x in range(0, 100, 5):
        pf = fl.getpixel((x, y))
        if (pf[0] > 200 and pf[1] > 150 and pf[2] < 50):
            print(f'  FL gold at ({x},{y}): {pf}')
            break
    else:
        continue
    break

# Player right avatar
print('\nPlayer Right Avatar:')
for y in range(0, 80, 5):
    for x in range(1180, 1280, 5):
        pw = wv.getpixel((x, y))
        if (pw[0] > 200 and pw[1] > 150 and pw[2] < 50):
            print(f'  WV gold at ({x},{y}): {pw}')
            break
    else:
        continue
    break

for y in range(0, 80, 5):
    for x in range(1180, 1280, 5):
        pf = fl.getpixel((x, y))
        if (pf[0] > 200 and pf[1] > 150 and pf[2] < 50):
            print(f'  FL gold at ({x},{y}): {pf}')
            break
    else:
        continue
    break

# My player info (bottom-left)
print('\nMy Player Info (bottom-left):')
for y in range(640, 720, 5):
    for x in range(0, 200, 10):
        pw = wv.getpixel((x, y))
        if pw[0] > 100 or pw[1] > 100 or pw[2] > 100:
            if pw[0] > 200 and pw[1] > 150 and pw[2] < 50:
                print(f'  WV gold at ({x},{y}): {pw}')
                break
    else:
        continue
    break

for y in range(640, 720, 5):
    for x in range(0, 200, 10):
        pf = fl.getpixel((x, y))
        if pf[0] > 100 or pf[1] > 100 or pf[2] > 100:
            if pf[0] > 200 and pf[1] > 150 and pf[2] < 50:
                print(f'  FL gold at ({x},{y}): {pf}')
                break
    else:
        continue
    break

# Deck area
print('\nDeck Area (top-left):')
for y in range(20, 80, 5):
    for x in range(100, 300, 5):
        pw = wv.getpixel((x, y))
        if pw[0] > 200 and pw[1] > 180 and pw[2] < 50:
            print(f'  WV deck gold at ({x},{y}): {pw}')
            break
    else:
        continue
    break

for y in range(20, 80, 5):
    for x in range(100, 300, 5):
        pf = fl.getpixel((x, y))
        if pf[0] > 200 and pf[1] > 180 and pf[2] < 50:
            print(f'  FL deck gold at ({x},{y}): {pf}')
            break
    else:
        continue
    break

# Hand cards (bottom center)
print('\nHand Cards (bottom center):')
for y in range(550, 720, 5):
    for x in range(400, 900, 5):
        pw = wv.getpixel((x, y))
        if pw[0] > 200 and pw[1] > 200 and pw[2] > 200:
            print(f'  WV white card at ({x},{y}): {pw}')
            break
    else:
        continue
    break

for y in range(550, 720, 5):
    for x in range(400, 900, 5):
        pf = fl.getpixel((x, y))
        if pf[0] > 200 and pf[1] > 200 and pf[2] > 200:
            print(f'  FL white card at ({x},{y}): {pf}')
            break
    else:
        continue
    break

# Round info (bottom-right)
print('\nRound Info (bottom-right):')
for y in range(690, 720, 3):
    for x in range(1200, 1280, 3):
        pw = wv.getpixel((x, y))
        if pw[0] > 150 and pw[1] > 150:
            print(f'  WV at ({x},{y}): {pw}')
            break
    else:
        continue
    break

for y in range(690, 720, 3):
    for x in range(1200, 1280, 3):
        pf = fl.getpixel((x, y))
        if pf[0] > 150 and pf[1] > 150:
            print(f'  FL at ({x},{y}): {pf}')
            break
    else:
        continue
    break

# Time display (top center)
print('\nTime Display (top center):')
for y in range(0, 30, 3):
    for x in range(560, 720, 3):
        pw = wv.getpixel((x, y))
        if pw[0] > 150 or pw[1] > 150 or pw[2] > 150:
            print(f'  WV at ({x},{y}): {pw}')
            break
    else:
        continue
    break

for y in range(0, 30, 3):
    for x in range(560, 720, 3):
        pf = fl.getpixel((x, y))
        if pf[0] > 150 or pf[1] > 150 or pf[2] > 150:
            print(f'  FL at ({x},{y}): {pf}')
            break
    else:
        continue
    break
