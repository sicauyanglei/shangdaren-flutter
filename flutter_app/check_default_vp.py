from PIL import Image

img = Image.open('screen_default_vp.png')
w, h = img.size
print(f'Screen: {w}x{h}')

# Edge check
for name, x, y in [('TL', 0, 0), ('TR', w-1, 0), ('BL', 0, h-1), ('BR', w-1, h-1), ('Center', w//2, h//2)]:
    p = img.getpixel((x, y))
    print(f'  {name}: {p}')

# Green area extent
green_start = None
green_end = None
for x in range(0, w):
    p = img.getpixel((x, 360))
    if 30 < p[0] < 120 and 40 < p[1] < 130 and 20 < p[2] < 90:
        if green_start is None:
            green_start = x
        green_end = x
print(f'Green area at y=360: x={green_start}-{green_end} (width={green_end-green_start+1 if green_start else 0})')

# Debug text
for y in range(0, 30, 2):
    for x in range(0, 400, 2):
        p = img.getpixel((x, y))
        if p[1] > 150 and p[0] < 100 and p[2] < 100:
            print(f'Debug text at ({x},{y}): {p}')
            # Read more of the text area
            for dx in range(x, min(x+300, w), 2):
                pp = img.getpixel((dx, y))
                if pp[1] > 100 and pp[0] < 100:
                    pass
                else:
                    break
            break
    else:
        continue
    break

# Key elements
for y in range(0, 80, 5):
    for x in range(0, 100, 5):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'Left avatar gold at ({x},{y})')
            break
    else:
        continue
    break

for y in range(0, 100, 5):
    for x in range(w-100, w, 5):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] > 150 and p[2] < 50:
            print(f'Right avatar gold at ({x},{y})')
            break
    else:
        continue
    break
