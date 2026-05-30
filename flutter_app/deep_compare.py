from PIL import Image

wv = Image.open('wv_02_game_playing.png')
fl = Image.open('flame_game.png')

print(f'WebView: {wv.size}, Flame: {fl.size}')

# WebView element positions from JS
wv_elements = {
    'game-container': (0, 0, 1280, 720),
    'player-left': (10, 5, 147, 101),
    'player-right': (1124, 5, 147, 72),
    'bottom-area': (0, 495, 1280, 225),
    'my-hand': (573, 560, 280, 245),
    'action-buttons': (628, 495, 170, 45),
    'round-info': (1214, 680, 56, 31),
    'current-time': (597, 10, 86, 29),
    'center-area': (180, 35, 180, 50),
    'deck-stack': (180, 35, 59, 17),
}

# Find corresponding elements in Flame screenshot
def find_color_region(img, w, h, y_start, y_end, x_start, x_end, condition, step=3):
    """Find first pixel matching condition"""
    for y in range(max(0, y_start), min(h, y_end), step):
        for x in range(max(0, x_start), min(w, x_end), step):
            p = img.getpixel((x, y))
            if condition(p):
                return (x, y)
    return None

# Find gold pixels (avatar borders, deck count)
def is_gold(p):
    return p[0] > 200 and p[1] > 150 and p[2] < 50

# Find white pixels (cards)
def is_white(p):
    return p[0] > 200 and p[1] > 200 and p[2] > 200

# Find green background
def is_green_bg(p):
    return 5 < p[0] < 80 and 30 < p[1] < 100 and 10 < p[2] < 60

# Find light pixels (text)
def is_light(p):
    return p[0] > 150 and p[1] > 150

print('\n=== WebView Element Positions (from JS) ===')
for name, (x, y, w, h) in wv_elements.items():
    print(f'  {name:20s}: x={x:4d}, y={y:4d}, w={w:4d}, h={h:4d}')

print('\n=== Flame Element Detection ===')
fw, fh = fl.size

# Left player avatar
left_avatar = find_color_region(fl, fw, fh, 0, 80, 0, 100, is_gold)
print(f'  Left Avatar (gold): {left_avatar}')

# Right player avatar
right_avatar = find_color_region(fl, fw, fh, 0, 100, fw-100, fw, is_gold)
print(f'  Right Avatar (gold): {right_avatar}')

# My player avatar
my_avatar = find_color_region(fl, fw, fh, fh-80, fh, 0, 200, is_gold)
print(f'  My Player (gold): {my_avatar}')

# Deck count
deck_count = find_color_region(fl, fw, fh, 0, 80, 100, 300, is_gold)
print(f'  Deck Count (gold): {deck_count}')

# Hand cards
hand_cards = find_color_region(fl, fw, fh, fh-200, fh, 300, fw-300, is_white)
print(f'  Hand Cards (white): {hand_cards}')

# Round info
round_info = find_color_region(fl, fw, fh, fh-30, fh, fw-80, fw, is_light)
print(f'  Round Info (light): {round_info}')

# Time display
time_display = find_color_region(fl, fw, fh, 0, 30, 500, 780, 
    lambda p: (p[0] > 150 or p[1] > 150 or p[2] > 150) and not is_gold(p))
print(f'  Time Display: {time_display}')

# Action buttons
action_btns = find_color_region(fl, fw, fh, fh-300, fh-100, 400, fw-400,
    lambda p: (p[0] > 200 and p[1] < 100 and p[2] < 100) or is_gold(p))
print(f'  Action Buttons: {action_btns}')

# Zimo badge
zimo = find_color_region(fl, fw, fh, fh-300, fh-100, 400, fw-400,
    lambda p: p[0] > 200 and p[1] > 50 and p[1] < 120 and p[2] < 80)
print(f'  Zimo Badge: {zimo}')

# Check green background coverage
print('\n=== Green Background Coverage ===')
for y_test in [0, 10, 20, 100, 360, 600, 700]:
    green_start = None
    green_end = None
    for x in range(0, fw):
        p = fl.getpixel((x, y_test))
        if is_green_bg(p):
            if green_start is None:
                green_start = x
            green_end = x
    if green_start:
        print(f'  y={y_test:4d}: green x={green_start}-{green_end} (width={green_end-green_start+1})')
    else:
        p = fl.getpixel((640, y_test))
        print(f'  y={y_test:4d}: no green, pixel at 640={p[:3]}')

# WebView green background
print('\nWebView green background:')
for y_test in [0, 10, 20, 100, 360, 600, 700]:
    green_start = None
    green_end = None
    for x in range(0, wv.size[0]):
        p = wv.getpixel((x, y_test))
        if is_green_bg(p):
            if green_start is None:
                green_start = x
            green_end = x
    if green_start:
        print(f'  y={y_test:4d}: green x={green_start}-{green_end} (width={green_end-green_start+1})')
    else:
        p = wv.getpixel((640, y_test))
        print(f'  y={y_test:4d}: no green, pixel at 640={p[:3]}')

# Detailed pixel comparison at key positions
print('\n=== Pixel-by-Pixel Comparison at Key Positions ===')
for name, (x, y, w, h) in wv_elements.items():
    # Sample center of each element
    cx, cy = x + w//2, y + h//2
    if cx < fw and cy < fh and cx < wv.size[0] and cy < wv.size[1]:
        p_wv = wv.getpixel((cx, cy))
        p_fl = fl.getpixel((cx, cy))
        match = 'OK' if abs(p_wv[0]-p_fl[0]) < 50 and abs(p_wv[1]-p_fl[1]) < 50 and abs(p_wv[2]-p_fl[2]) < 50 else 'DIFF'
        print(f'  {name:20s} center({cx:4d},{cy:4d}): WV={p_wv[:3]} FL={p_fl[:3]} {match}')
