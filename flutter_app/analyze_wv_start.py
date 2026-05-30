from PIL import Image

wv = Image.open('wv_00_start.png')
print(f'WebView start: {wv.size}')

# Detailed scan
print('\nWebView start screen elements:')
# Find white/light areas (buttons, text)
for y in range(0, 720, 20):
    for x in range(0, 1280, 20):
        p = wv.getpixel((x, y))
        if p[0] > 200 and p[1] > 200 and p[2] > 200:
            print(f'  White at ({x},{y}): {p[:3]}')
            break
    else:
        continue
    break

# Find cyan/teal buttons (like 开始游戏)
print('\nCyan/teal buttons:')
for y in range(0, 720, 5):
    for x in range(0, 1280, 5):
        p = wv.getpixel((x, y))
        if p[0] > 50 and p[1] > 180 and p[2] > 170 and p[0] < 150:
            print(f'  Cyan at ({x},{y}): {p[:3]}')
            break
    else:
        continue
    break

# Full layout map
print('\nLayout map:')
for y in range(0, 720, 40):
    row = []
    for x in range(0, 1280, 40):
        p = wv.getpixel((x, y))
        if p[0] < 30 and p[1] < 30 and p[2] < 30:
            c = '.'
        elif p[1] > p[0] and p[1] > p[2] and p[1] > 50:
            c = 'G'
        elif p[0] > 200 and p[1] > 200 and p[2] > 200:
            c = 'W'
        elif p[0] > 50 and p[1] > 180 and p[2] > 170 and p[0] < 150:
            c = 'C'
        elif p[0] > 200 and p[1] > 150 and p[2] < 100:
            c = 'Y'
        elif p[0] > 100 and p[1] > 100 and p[2] > 100:
            c = 'L'
        else:
            c = 'x'
        row.append(c)
    line = ' '.join(row)
    print(f'  y={y:3d}: {line}')
