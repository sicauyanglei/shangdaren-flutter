from PIL import Image
import numpy as np

wv = Image.open('wv_start_clean.png')
fl = Image.open('flame_start2.png')

print(f'WebView: {wv.size}, Flame: {fl.size}')

# Convert to numpy for comparison
wv_arr = np.array(wv)
fl_arr = np.array(fl)

# Simple pixel difference
diff = np.abs(wv_arr.astype(int) - fl_arr.astype(int))
mean_diff = diff.mean()
max_diff = diff.max()
print(f'\nPixel difference: mean={mean_diff:.1f}, max={max_diff}')

# Find areas with biggest differences
print('\nAreas with biggest differences:')
for y in range(0, 720, 40):
    row_diff = diff[y:y+40, :, :].mean()
    if row_diff > 30:
        print(f'  y={y}-{y+40}: diff={row_diff:.1f}')

# Check key element positions
print('\nKey element comparison:')

# Cyan/teal button (开始游戏)
for label, img, w, h in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    found = None
    for y in range(0, h, 3):
        for x in range(0, w, 3):
            p = img.getpixel((x, y))
            if p[0] > 50 and p[1] > 180 and p[2] > 170 and p[0] < 150:
                found = (x, y)
                break
        if found:
            break
    print(f'  {label} 开始游戏 button: {found}')

# White/light text areas
for label, img, w, h in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    found = None
    for y in range(0, h, 3):
        for x in range(0, w, 3):
            p = img.getpixel((x, y))
            if p[0] > 200 and p[1] > 200 and p[2] > 200:
                found = (x, y)
                break
        if found:
            break
    print(f'  {label} White text: {found}')

# Selected button (cyan gradient)
for label, img, w, h in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    found = None
    for y in range(200, 400, 3):
        for x in range(400, 1000, 3):
            p = img.getpixel((x, y))
            if p[0] > 50 and p[1] > 180 and p[2] > 170 and p[0] < 150:
                found = (x, y)
                break
        if found:
            break
    print(f'  {label} Selected option: {found}')
