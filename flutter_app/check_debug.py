from PIL import Image

img = Image.open('screen_debug.png')
w, h = img.size
print(f'Screen: {w}x{h}')

# Find the debug text (green text on black bg)
print('\nSearching for debug text:')
for y in range(0, 30, 2):
    for x in range(0, 400, 2):
        p = img.getpixel((x, y))
        if p[1] > 150 and p[0] < 100 and p[2] < 100:
            print(f'  Green text at ({x},{y}): {p}')
            break
    else:
        continue
    break

# Check if green fills entire screen
print('\nEdge check:')
for name, x, y in [('TL', 0, 0), ('TR', w-1, 0), ('BL', 0, h-1), ('BR', w-1, h-1)]:
    p = img.getpixel((x, y))
    print(f'  {name}: {p}')

# Check green area extent
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

# Check overlay elements
print('\nOverlay elements:')

# Player left avatar
for y in range(0, 80, 5):
    for x in range(0, 100, 5):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'  Left avatar gold at ({x},{y}): {p}')
            break
    else:
        continue
    break

# Player right avatar
for y in range(0, 100, 5):
    for x in range(w-100, w, 5):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'  Right avatar gold at ({x},{y}): {p}')
            break
    else:
        continue
    break

# My player info
for y in range(h-80, h, 5):
    for x in range(0, 200, 5):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'  My player gold at ({x},{y}): {p}')
            break
    else:
        continue
    break

# Round info
for y in range(h-30, h, 3):
    for x in range(w-80, w, 3):
        p = img.getpixel((x, y))
        if p[0] > 150 and p[1] > 150:
            print(f'  Round info at ({x},{y}): {p}')
            break
    else:
        continue
    break
