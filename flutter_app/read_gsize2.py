from PIL import Image

img = Image.open('screen_gsize2.png')
w, h = img.size
print(f'Screen: {w}x{h}')

# Search for red text on black background at (400, 300)
print('\nSearching for red debug text around (400, 300):')
for y in range(290, 330, 1):
    row = []
    for x in range(390, 660, 1):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] < 50 and p[2] < 50:
            row.append('#')
        elif p[0] < 30 and p[1] < 30 and p[2] < 30:
            row.append(' ')
        else:
            row.append('.')
    line = ''.join(row)
    if '#' in line:
        print(f'  y={y}: |{line}|')

# Also search entire screen for red text
print('\nSearching entire screen for red text:')
found = False
for y in range(0, h, 5):
    for x in range(0, w, 5):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] < 50 and p[2] < 50:
            print(f'  Red at ({x},{y}): {p[:3]}')
            found = True
            break
    if found:
        break
