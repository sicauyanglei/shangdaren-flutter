from PIL import Image

img = Image.open('screen_stretch2.png')
w, h = img.size
print(f'Screen: {w}x{h}')

# Edge check
print('\nEdge pixels:')
for name, x, y in [('TL', 0, 0), ('TR', w-1, 0), ('BL', 0, h-1), ('BR', w-1, h-1), ('Center', w//2, h//2)]:
    p = img.getpixel((x, y))
    print(f'  {name}: {p}')

# Green area extent
print('\nGreen area extent at y=360:')
green_start = None
green_end = None
for x in range(0, w):
    p = img.getpixel((x, 360))
    if 30 < p[0] < 120 and 40 < p[1] < 130 and 20 < p[2] < 90:
        if green_start is None:
            green_start = x
        green_end = x
print(f'  Green x={green_start}-{green_end} (width={green_end-green_start+1 if green_start else 0})')

# Debug text
print('\nDebug text:')
for y in range(0, 30, 2):
    for x in range(0, 400, 2):
        p = img.getpixel((x, y))
        if p[1] > 150 and p[0] < 100 and p[2] < 100:
            print(f'  Green text at ({x},{y}): {p}')
            break
    else:
        continue
    break

# Quick layout comparison with WebView
wv = Image.open('wv_game_state.png')
print(f'\nWebView: {wv.size}')

# Compare green area
wv_green_start = None
wv_green_end = None
for x in range(0, wv.size[0]):
    p = wv.getpixel((x, 360))
    if 30 < p[0] < 120 and 40 < p[1] < 130 and 20 < p[2] < 90:
        if wv_green_start is None:
            wv_green_start = x
        wv_green_end = x
print(f'  WV Green x={wv_green_start}-{wv_green_end} (width={wv_green_end-wv_green_start+1 if wv_green_start else 0})')

# Compare key elements
print('\nKey element positions:')

# Left avatar
for y in range(0, 80, 5):
    for x in range(0, 100, 5):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'  FL left avatar gold at ({x},{y})')
            break
    else:
        continue
    break

for y in range(0, 80, 5):
    for x in range(0, 100, 5):
        p = wv.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'  WV left avatar gold at ({x},{y})')
            break
    else:
        continue
    break

# Right avatar
for y in range(0, 100, 5):
    for x in range(w-100, w, 5):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'  FL right avatar gold at ({x},{y})')
            break
    else:
        continue
    break

for y in range(0, 80, 5):
    for x in range(wv.size[0]-100, wv.size[0], 5):
        p = wv.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'  WV right avatar gold at ({x},{y})')
            break
    else:
        continue
    break

# My player
for y in range(h-80, h, 5):
    for x in range(0, 200, 5):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'  FL my player gold at ({x},{y})')
            break
    else:
        continue
    break

for y in range(wv.size[1]-80, wv.size[1], 5):
    for x in range(0, 200, 5):
        p = wv.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'  WV my player gold at ({x},{y})')
            break
    else:
        continue
    break
