from PIL import Image

img = Image.open('screen_gsize.png')
w, h = img.size

# Search entire screen for red pixels (R>200, G<50, B<50)
print('Searching for red pixels...')
red_pixels = []
for y in range(0, h, 3):
    for x in range(0, w, 3):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] < 50 and p[2] < 50:
            red_pixels.append((x, y, p[:3]))
            if len(red_pixels) > 30:
                break
    if len(red_pixels) > 30:
        break

print(f'Found {len(red_pixels)} red pixels')
for px in red_pixels[:20]:
    print(f'  ({px[0]},{px[1]}): {px[2]}')
