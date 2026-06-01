from PIL import Image

fl = Image.open('screen_final.png')
wv = Image.open('wv_game_state.png')

print(f'Flame: {fl.size}, WebView: {wv.size}')

# Comprehensive element position comparison
elements = {
    'Left Avatar': lambda img, w, h: _find_first(img, w, h, 0, 80, 0, 100, lambda p: p[0] > 200 and p[1] > 150 and p[2] < 50),
    'Right Avatar': lambda img, w, h: _find_first(img, w, h, 0, 80, w-100, w, lambda p: p[0] > 200 and p[1] > 150 and p[2] < 50),
    'My Player': lambda img, w, h: _find_first(img, w, h, h-80, h, 0, 200, lambda p: p[0] > 200 and p[1] > 150 and p[2] < 50),
    'Deck Count': lambda img, w, h: _find_first(img, w, h, 20, 80, 100, 300, lambda p: p[0] > 200 and p[1] > 180 and p[2] < 50),
    'Hand Cards': lambda img, w, h: _find_first(img, w, h, h-200, h, 300, w-300, lambda p: p[0] > 200 and p[1] > 200 and p[2] > 200),
    'Round Info': lambda img, w, h: _find_first(img, w, h, h-30, h, w-80, w, lambda p: p[0] > 150 and p[1] > 150),
    'Time Display': lambda img, w, h: _find_first(img, w, h, 0, 30, 500, 780, lambda p: (p[0] > 150 or p[1] > 150 or p[2] > 150) and not (p[0] > 200 and p[1] > 150 and p[2] < 50)),
    'Action Buttons': lambda img, w, h: _find_first(img, w, h, h-300, h-100, 400, w-400, lambda p: (p[0] > 200 and p[1] < 100 and p[2] < 100) or (p[0] > 200 and p[1] > 150 and p[2] < 50)),
    'Zimo Badge': lambda img, w, h: _find_first(img, w, h, h-300, h-100, 400, w-400, lambda p: p[0] > 200 and p[1] > 50 and p[1] < 120 and p[2] < 80),
}

def _find_first(img, w, h, y_start, y_end, x_start, x_end, condition):
    for y in range(max(0, y_start), min(h, y_end), 3):
        for x in range(max(0, x_start), min(w, x_end), 3):
            p = img.getpixel((x, y))
            if condition(p):
                return (x, y)
    return None

print('\n=== Element Position Comparison ===')
for name, finder in elements.items():
    wv_pos = finder(wv, wv.size[0], wv.size[1])
    fl_pos = finder(fl, fl.size[0], fl.size[1])
    
    wv_str = f'({wv_pos[0]},{wv_pos[1]})' if wv_pos else 'NOT FOUND'
    fl_str = f'({fl_pos[0]},{fl_pos[1]})' if fl_pos else 'NOT FOUND'
    
    if wv_pos and fl_pos:
        dx = fl_pos[0] - wv_pos[0]
        dy = fl_pos[1] - wv_pos[1]
        diff = f'dx={dx:+d}, dy={dy:+d}'
    else:
        diff = 'N/A'
    
    print(f'  {name:15s}: WV={wv_str:15s} FL={fl_str:15s} {diff}')

# Green area comparison
print('\n=== Green Area Comparison ===')
for label, img, w, h in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    green_start = None
    green_end = None
    for x in range(0, w):
        p = img.getpixel((x, 360))
        if 5 < p[0] < 80 and 30 < p[1] < 100 and 10 < p[2] < 60:
            if green_start is None:
                green_start = x
            green_end = x
    print(f'  {label}: x={green_start}-{green_end} (width={green_end-green_start+1 if green_start else 0})')

# Top area comparison (y=0-30)
print('\n=== Top Area Detail (y=0-30) ===')
for label, img, w, h in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    print(f'  {label}:')
    for y in [0, 5, 10, 15, 20, 25]:
        p = img.getpixel((640, y))
        print(f'    (640,{y}): {p[:3]}')
