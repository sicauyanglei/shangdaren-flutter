from PIL import Image

fl = Image.open('screen_v3.png')
w, h = fl.size

# Try to read the debug text "sz=..."
# The text is at y=20, green on black
# Let's try to read it character by character
print('Reading debug text at y=20:')
for y in range(18, 28):
    row = []
    for x in range(0, 350, 1):
        p = fl.getpixel((x, y))
        if p[1] > 150 and p[0] < 100 and p[2] < 100:
            row.append('#')
        elif p[0] > 100 or p[1] > 100 or p[2] > 100:
            row.append('.')
        else:
            row.append(' ')
    line = ''.join(row)
    if '#' in line:
        print(f'  y={y}: |{line}|')

# The text format is: sz=NNNxNNN sx=N.NN sy=N.NN
# Let's extract the numbers by looking at the pattern
# Green pixels at y=20 start around x=12
print('\nGreen pixel positions at y=20:')
green_positions = []
for x in range(0, 350, 1):
    p = fl.getpixel((x, 20))
    if p[1] > 150 and p[0] < 100 and p[2] < 100:
        green_positions.append(x)
if green_positions:
    print(f'  x range: {green_positions[0]}-{green_positions[-1]}')
    print(f'  Total green pixels: {len(green_positions)}')
