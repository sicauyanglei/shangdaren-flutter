from PIL import Image

img = Image.open('screen_rect.png')
w, h = img.size
print(f'Screen: {w}x{h}')

# Search for red rectangle at (398,298) to (648,328)
print('\nSearching for red rectangle:')
red_count = 0
for y in range(290, 340, 1):
    for x in range(390, 660, 1):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] < 50 and p[2] < 50:
            red_count += 1

print(f'  Red pixels in area: {red_count}')

# Also check if game is rendering at all
print('\nGame rendering check:')
for y in [100, 300, 500, 700]:
    p = img.getpixel((640, y))
    print(f'  (640,{y}): {p[:3]}')

# Check green area
green_start = None
green_end = None
for x in range(0, w):
    p = img.getpixel((x, 360))
    if 5 < p[0] < 80 and 30 < p[1] < 100 and 10 < p[2] < 60:
        if green_start is None:
            green_start = x
        green_end = x
print(f'Green area at y=360: x={green_start}-{green_end} (width={green_end-green_start+1 if green_start else 0})')
