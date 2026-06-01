from PIL import Image

fl = Image.open('flame_start.png')
wv = Image.open('wv_00_start.png')

print(f'Flame: {fl.size}, WebView: {wv.size}')

# Check what's shown on Flame
print('\nFlame start screen analysis:')
# Sample center
for y in [0, 100, 200, 300, 360, 400, 500, 600, 700]:
    p = fl.getpixel((640, y))
    print(f'  (640,{y}): {p[:3]}')

# Check for start button or any UI elements
print('\nSearching for buttons/UI elements:')
for y in range(0, 720, 10):
    for x in range(0, 1280, 10):
        p = fl.getpixel((x, y))
        if p[0] > 200 and p[1] > 200 and p[2] > 200:
            print(f'  White at ({x},{y}): {p[:3]}')
            break
    else:
        continue
    break

# Check for any colored elements
print('\nSearching for colored elements:')
colors_found = set()
for y in range(0, 720, 5):
    for x in range(0, 1280, 5):
        p = fl.getpixel((x, y))
        if p[0] > 200 and p[1] < 100 and p[2] < 100:
            if 'red' not in colors_found:
                colors_found.add('red')
                print(f'  Red at ({x},{y}): {p[:3]}')
        elif p[0] > 200 and p[1] > 200 and p[2] < 100:
            if 'yellow' not in colors_found:
                colors_found.add('yellow')
                print(f'  Yellow at ({x},{y}): {p[:3]}')
        elif p[0] < 100 and p[1] > 200 and p[2] < 100:
            if 'green' not in colors_found:
                colors_found.add('green')
                print(f'  Green at ({x},{y}): {p[:3]}')

# WebView start screen
print('\nWebView start screen analysis:')
for y in [0, 100, 200, 300, 360, 400, 500, 600, 700]:
    p = wv.getpixel((640, y))
    print(f'  (640,{y}): {p[:3]}')
