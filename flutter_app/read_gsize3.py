from PIL import Image

img = Image.open('screen_gsize3.png')
w, h = img.size
print(f'Screen: {w}x{h}')

# Search for red text
print('\nSearching for red text (R>200, G<50, B<50):')
for y in range(290, 340, 1):
    for x in range(390, 660, 1):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] < 50 and p[2] < 50:
            print(f'  RED at ({x},{y}): {p[:3]}')
            # Read surrounding area
            for row_y in range(y-2, y+25):
                row = []
                for col_x in range(x-5, min(x+300, w)):
                    p = img.getpixel((col_x, row_y))
                    if p[0] > 200 and p[1] < 50 and p[2] < 50:
                        row.append('#')
                    elif p[0] < 30 and p[1] < 30 and p[2] < 30:
                        row.append(' ')
                    else:
                        row.append('.')
                line = ''.join(row)
                if '#' in line:
                    print(f'  y={row_y}: |{line}|')
            break
    else:
        continue
    break
else:
    print('  No red text found at (400,300)')

# Search wider
print('\nWider search for red text:')
found = False
for y in range(0, h, 3):
    for x in range(0, w, 3):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] < 50 and p[2] < 50:
            if y > 5:
                print(f'  RED at ({x},{y}): {p[:3]}')
                found = True
                break
    if found:
        break
if not found:
    print('  No red text found anywhere (except status bar)')
