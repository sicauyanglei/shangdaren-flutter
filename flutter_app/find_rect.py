from PIL import Image

img = Image.open('screen_rect2.png')
w, h = img.size
print(f'Screen: {w}x{h}')

# Search for red rectangle anywhere on screen
print('\nSearching for red pixels (R>200, G<50, B<50):')
red_pixels = []
for y in range(0, h, 3):
    for x in range(0, w, 3):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] < 50 and p[2] < 50:
            red_pixels.append((x, y))
            if len(red_pixels) > 20:
                break
    if len(red_pixels) > 20:
        break

print(f'Found {len(red_pixels)} red pixels')
for px in red_pixels[:10]:
    p = img.getpixel(px)
    print(f'  ({px[0]},{px[1]}): {p[:3]}')

if red_pixels:
    min_x = min(p[0] for p in red_pixels)
    max_x = max(p[0] for p in red_pixels)
    min_y = min(p[1] for p in red_pixels)
    max_y = max(p[1] for p in red_pixels)
    print(f'Red area: x={min_x}-{max_x}, y={min_y}-{max_y}')
