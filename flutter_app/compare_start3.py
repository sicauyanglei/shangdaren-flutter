from PIL import Image
import numpy as np

wv = Image.open('wv_start_clean.png').convert('RGB')
fl = Image.open('flame_start2.png').convert('RGB')

print(f'WebView: {wv.size}, Flame: {fl.size}')

wv_arr = np.array(wv)
fl_arr = np.array(fl)

diff = np.abs(wv_arr.astype(int) - fl_arr.astype(int))
mean_diff = diff.mean()
max_diff = diff.max()
print(f'Pixel difference: mean={mean_diff:.1f}, max={max_diff}')

# Key element positions
print('\nKey element comparison:')
for label, img, w, h in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    # Cyan button
    found = None
    for y in range(0, h, 3):
        for x in range(0, w, 3):
            p = img.getpixel((x, y))
            if p[0] > 50 and p[1] > 180 and p[2] > 170 and p[0] < 150:
                found = (x, y)
                break
        if found:
            break
    print(f'  {label} Cyan button: {found}')

    # White text
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

    # Selected option button
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

# Area difference map
print('\nArea difference (by 80px blocks):')
for y in range(0, 720, 80):
    for x in range(0, 1280, 80):
        block_diff = diff[y:y+80, x:x+80, :].mean()
        if block_diff > 20:
            print(f'  ({x},{y}): diff={block_diff:.1f}')
