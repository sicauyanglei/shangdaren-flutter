from PIL import Image

img = Image.open('screen_gsize.png')
w, h = img.size
print(f'Screen: {w}x{h}')

# Find the red debug text "GSIZE=..."
print('\nSearching for red debug text:')
for y in range(280, 330, 1):
    for x in range(380, 600, 1):
        p = img.getpixel((x, y))
        if p[0] > 200 and p[1] < 50 and p[2] < 50:
            # Found red pixel, read the area
            print(f'  Red text starts at ({x},{y})')
            # Read a wider area to get the full text
            for row_y in range(y-2, y+20):
                row = []
                for col_x in range(x-5, min(x+250, w)):
                    p = img.getpixel((col_x, row_y))
                    if p[0] > 200 and p[1] < 50 and p[2] < 50:
                        row.append('#')
                    elif p[0] > 100 or p[1] > 100 or p[2] > 100:
                        row.append('.')
                    else:
                        row.append(' ')
                line = ''.join(row)
                if '#' in line:
                    print(f'  y={row_y}: |{line}|')
            break
    else:
        continue
    break
