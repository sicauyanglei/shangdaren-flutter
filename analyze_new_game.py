from PIL import Image
import numpy as np
from scipy import ndimage

fl = Image.open(r'E:\AI-PRJ\shangdaren-game\fl_new_game.png')
fl_arr = np.array(fl)[:,:,:3]

print("=== Flame Game (New Build) ===")
print(f"Size: {fl.size}")

teal_mask = (fl_arr[:,:,0] > 50) & (fl_arr[:,:,0] < 100) & (fl_arr[:,:,1] > 160) & (fl_arr[:,:,2] > 150) & (fl_arr[:,:,2] < 220)
print(f"Teal pixels: {teal_mask.sum()}")

gold_mask = (fl_arr[:,:,0] > 200) & (fl_arr[:,:,1] > 180) & (fl_arr[:,:,2] < 100)
ys, xs = np.where(gold_mask)
if len(xs) > 0:
    labeled, num = ndimage.label(gold_mask)
    for i in range(1, min(num+1, 30)):
        comp_ys, comp_xs = np.where(labeled == i)
        if len(comp_xs) < 20: continue
        x0, x1 = comp_xs.min(), comp_xs.max()
        y0, y1 = comp_ys.min(), comp_ys.max()
        print(f"Gold [{i}]: ({x0},{y0})-({x1},{y1}) size={x1-x0+1}x{y1-y0+1}")

dark_mask = np.all(fl_arr < 50, axis=2)
labeled2, num2 = ndimage.label(dark_mask)
print(f"\nDark components (>200px): {num2}")
for i in range(1, min(num2+1, 20)):
    comp_ys, comp_xs = np.where(labeled2 == i)
    if len(comp_xs) < 200: continue
    x0, x1 = comp_xs.min(), comp_xs.max()
    y0, y1 = comp_ys.min(), comp_ys.max()
    print(f"Dark [{i}]: ({x0},{y0})-({x1},{y1}) size={x1-x0+1}x{y1-y0+1}")

red_mask = (fl_arr[:,:,0] > 180) & (fl_arr[:,:,1] < 80) & (fl_arr[:,:,2] < 80)
ys2, xs2 = np.where(red_mask)
if len(xs2) > 0:
    labeled3, num3 = ndimage.label(red_mask)
    print(f"\nRed components: {num3}")
    for i in range(1, min(num3+1, 40)):
        comp_ys, comp_xs = np.where(labeled3 == i)
        if len(comp_xs) < 10: continue
        x0, x1 = comp_xs.min(), comp_xs.max()
        y0, y1 = comp_ys.min(), comp_ys.max()
        print(f"Red [{i}]: ({x0},{y0})-({x1},{y1}) size={x1-x0+1}x{y1-y0+1}")

green_mask = (fl_arr[:,:,0] < 80) & (fl_arr[:,:,1] > 180) & (fl_arr[:,:,2] < 80)
ys3, xs3 = np.where(green_mask)
if len(xs3) > 0:
    labeled4, num4 = ndimage.label(green_mask)
    print(f"\nGreen components: {num4}")
    for i in range(1, min(num4+1, 40)):
        comp_ys, comp_xs = np.where(labeled4 == i)
        if len(comp_xs) < 10: continue
        x0, x1 = comp_xs.min(), comp_xs.max()
        y0, y1 = comp_ys.min(), comp_ys.max()
        print(f"Green [{i}]: ({x0},{y0})-({x1},{y1}) size={x1-x0+1}x{y1-y0+1}")

settings_icon_mask = (fl_arr[:,:,0] > 100) & (fl_arr[:,:,0] < 180) & (fl_arr[:,:,1] > 100) & (fl_arr[:,:,1] < 180) & (fl_arr[:,:,2] > 100) & (fl_arr[:,:,2] < 180)
top_right = fl_arr[0:50, 1230:1280]
print(f"\nTop-right area (settings icon check): non-green pixels = {np.sum(np.any(top_right > 30, axis=2))}")
