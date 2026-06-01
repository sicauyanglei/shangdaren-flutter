from PIL import Image
import numpy as np

wv = Image.open('wv_start_clean.png').convert('RGB')
fl = Image.open('flame_start3.png').convert('RGB')

print(f'WebView: {wv.size}, Flame: {fl.size}')

wv_arr = np.array(wv)
fl_arr = np.array(fl)
diff = np.abs(wv_arr.astype(int) - fl_arr.astype(int))
mean_diff = diff.mean()
print(f'Pixel difference: mean={mean_diff:.1f}')

# Key element positions
print('\nKey element comparison:')
for label, img, w, h in [('WV', wv, wv.size[0], wv.size[1]), ('FL', fl, fl.size[0], fl.size[1])]:
    # Cyan button (开始游戏)
    found = None
    for y in range(350, 500, 3):
        for x in range(0, w, 3):
            p = img.getpixel((x, y))
            if p[0] > 50 and p[1] > 180 and p[2] > 170 and p[0] < 150:
                found = (x, y)
                break
        if found:
            break
    print(f'  {label} 开始游戏 button: {found}')

    # Selected option buttons
    found_list = []
    for y in range(200, 400, 3):
        for x in range(300, 1000, 3):
            p = img.getpixel((x, y))
            if p[0] > 50 and p[1] > 180 and p[2] > 170 and p[0] < 150:
                if not found_list or (x - found_list[-1][0]) > 20:
                    found_list.append((x, y))
    print(f'  {label} Selected options: {found_list}')

# Area difference
print('\nArea difference (by 80px blocks, only diff>30):')
for y in range(0, 720, 80):
    for x in range(0, 1280, 80):
        block_diff = diff[y:y+80, x:x+80, :].mean()
        if block_diff > 30:
            print(f'  ({x},{y}): diff={block_diff:.1f}')
