from PIL import Image

fl = Image.open('screen_v3.png')
wv = Image.open('wv_game_state.png')

print(f'Flame: {fl.size}, WebView: {wv.size}')

# Key element positions comparison
print('\n=== Key Element Position Comparison ===')

# Left player avatar
print('\nLeft player avatar (gold circle):')
for label, img, ww, hh in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    found = False
    for y in range(0, 80, 3):
        for x in range(0, 100, 3):
            p = img.getpixel((x, y))
            if p[0] > 200 and p[1] > 150 and p[2] < 50:
                print(f'  {label} gold at ({x},{y})')
                found = True
                break
        if found:
            break
    if not found:
        print(f'  {label} NOT FOUND')

# Right player avatar
print('\nRight player avatar:')
for label, img, ww, hh in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    found = False
    for y in range(0, 100, 3):
        for x in range(ww-100, ww, 3):
            p = img.getpixel((x, y))
            if p[0] > 200 and p[1] > 150 and p[2] < 50:
                print(f'  {label} gold at ({x},{y})')
                found = True
                break
        if found:
            break
    if not found:
        print(f'  {label} NOT FOUND')

# My player info
print('\nMy player info (bottom-left):')
for label, img, ww, hh in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    found = False
    for y in range(hh-80, hh, 3):
        for x in range(0, 200, 3):
            p = img.getpixel((x, y))
            if p[0] > 200 and p[1] > 150 and p[2] < 50:
                print(f'  {label} gold at ({x},{y})')
                found = True
                break
        if found:
            break
    if not found:
        print(f'  {label} NOT FOUND')

# Deck count
print('\nDeck count (gold text):')
for label, img, ww, hh in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    found = False
    for y in range(20, 80, 3):
        for x in range(100, 300, 3):
            p = img.getpixel((x, y))
            if p[0] > 200 and p[1] > 180 and p[2] < 50:
                print(f'  {label} deck gold at ({x},{y})')
                found = True
                break
        if found:
            break
    if not found:
        print(f'  {label} NOT FOUND')

# Hand cards
print('\nHand cards (white area, bottom):')
for label, img, ww, hh in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    found = False
    for y in range(hh-200, hh, 5):
        for x in range(300, ww-300, 5):
            p = img.getpixel((x, y))
            if p[0] > 200 and p[1] > 200 and p[2] > 200:
                print(f'  {label} white at ({x},{y})')
                found = True
                break
        if found:
            break
    if not found:
        print(f'  {label} NOT FOUND')

# Round info
print('\nRound info (bottom-right):')
for label, img, ww, hh in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    found = False
    for y in range(hh-30, hh, 3):
        for x in range(ww-80, ww, 3):
            p = img.getpixel((x, y))
            if p[0] > 150 and p[1] > 150:
                print(f'  {label} at ({x},{y}): {p[:3]}')
                found = True
                break
        if found:
            break
    if not found:
        print(f'  {label} NOT FOUND')

# Time display
print('\nTime display (top center):')
for label, img, ww, hh in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    found = False
    for y in range(0, 30, 3):
        for x in range(500, 780, 3):
            p = img.getpixel((x, y))
            if p[0] > 150 or p[1] > 150 or p[2] > 150:
                print(f'  {label} at ({x},{y}): {p[:3]}')
                found = True
                break
        if found:
            break
    if not found:
        print(f'  {label} NOT FOUND')

# Action buttons
print('\nAction buttons (center-bottom):')
for label, img, ww, hh in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    found = False
    for y in range(hh-300, hh-100, 5):
        for x in range(400, ww-400, 5):
            p = img.getpixel((x, y))
            if (p[0] > 200 and p[1] < 100 and p[2] < 100) or (p[0] > 200 and p[1] > 150 and p[2] < 50):
                print(f'  {label} button at ({x},{y}): {p[:3]}')
                found = True
                break
        if found:
            break
    if not found:
        print(f'  {label} NOT FOUND')

# Zimo badge
print('\nZimo badge (red/gold gradient):')
for label, img, ww, hh in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    found = False
    for y in range(hh-300, hh-100, 5):
        for x in range(400, ww-400, 5):
            p = img.getpixel((x, y))
            if p[0] > 200 and p[1] > 50 and p[1] < 120 and p[2] < 80:
                print(f'  {label} zimo at ({x},{y}): {p[:3]}')
                found = True
                break
        if found:
            break
    if not found:
        print(f'  {label} NOT FOUND')

# Debug text
print('\nDebug text:')
for y in range(0, 30, 2):
    for x in range(0, 400, 2):
        p = fl.getpixel((x, y))
        if p[1] > 150 and p[0] < 100 and p[2] < 100:
            print(f'  FL debug at ({x},{y}): {p[:3]}')
            break
    else:
        continue
    break
