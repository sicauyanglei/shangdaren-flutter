from PIL import Image
import numpy as np
from scipy import ndimage

print("=== WebView Game Board ===")
wv = Image.open(r'E:\AI-PRJ\shangdaren-game\wv_game.png')
wv_arr = np.array(wv)[:,:,:3]
print(f"Size: {wv.size}")

gold_mask_wv = (wv_arr[:,:,0] > 200) & (wv_arr[:,:,1] > 180) & (wv_arr[:,:,2] < 100)
ys, xs = np.where(gold_mask_wv)
if len(xs) > 0:
    labeled, num = ndimage.label(gold_mask_wv)
    for i in range(1, min(num+1, 20)):
        comp_ys, comp_xs = np.where(labeled == i)
        if len(comp_xs) < 20: continue
        x0, x1 = comp_xs.min(), comp_xs.max()
        y0, y1 = comp_ys.min(), comp_ys.max()
        cx = (x0+x1)//2
        cy = (y0+y1)//2
        print(f"WV Gold [{i}]: ({x0},{y0})-({x1},{y1}) center=({cx},{cy}) size={x1-x0+1}x{y1-y0+1}")

dark_mask_wv = np.all(wv_arr < 50, axis=2)
labeled2, num2 = ndimage.label(dark_mask_wv)
print(f"\nWV Dark components (>200px): {num2}")
for i in range(1, min(num2+1, 20)):
    comp_ys, comp_xs = np.where(labeled2 == i)
    if len(comp_xs) < 200: continue
    x0, x1 = comp_xs.min(), comp_xs.max()
    y0, y1 = comp_ys.min(), comp_ys.max()
    cx = (x0+x1)//2
    cy = (y0+y1)//2
    print(f"WV Dark [{i}]: ({x0},{y0})-({x1},{y1}) center=({cx},{cy}) size={x1-x0+1}x{y1-y0+1}")

print("\n=== Flame Game Board ===")
fl = Image.open(r'E:\AI-PRJ\shangdaren-game\fl_game6.png')
fl_arr = np.array(fl)[:,:,:3]

gold_mask_fl = (fl_arr[:,:,0] > 200) & (fl_arr[:,:,1] > 180) & (fl_arr[:,:,2] < 100)
ys, xs = np.where(gold_mask_fl)
if len(xs) > 0:
    labeled, num = ndimage.label(gold_mask_fl)
    for i in range(1, min(num+1, 20)):
        comp_ys, comp_xs = np.where(labeled == i)
        if len(comp_xs) < 20: continue
        x0, x1 = comp_xs.min(), comp_xs.max()
        y0, y1 = comp_ys.min(), comp_ys.max()
        cx = (x0+x1)//2
        cy = (y0+y1)//2
        print(f"FL Gold [{i}]: ({x0},{y0})-({x1},{y1}) center=({cx},{cy}) size={x1-x0+1}x{y1-y0+1}")

dark_mask_fl = np.all(fl_arr < 50, axis=2)
labeled3, num3 = ndimage.label(dark_mask_fl)
print(f"\nFL Dark components (>200px): {num3}")
for i in range(1, min(num3+1, 20)):
    comp_ys, comp_xs = np.where(labeled3 == i)
    if len(comp_xs) < 200: continue
    x0, x1 = comp_xs.min(), comp_xs.max()
    y0, y1 = comp_ys.min(), comp_ys.max()
    cx = (x0+x1)//2
    cy = (y0+y1)//2
    print(f"FL Dark [{i}]: ({x0},{y0})-({x1},{y1}) center=({cx},{cy}) size={x1-x0+1}x{y1-y0+1}")

print("\n=== Small Card Region Comparison ===")
wv_left = wv_arr[80:200, 10:260]
fl_left = fl_arr[80:200, 10:260]
wv_left_var = np.var(wv_left.astype(float))
fl_left_var = np.var(fl_left.astype(float))
print(f"WV left region variance: {wv_left_var:.1f}")
print(f"FL left region variance: {fl_left_var:.1f}")
print(f"Higher variance = more detail/sharpness")

wv_right = wv_arr[80:200, 1020:1270]
fl_right = fl_arr[80:200, 1020:1270]
wv_right_var = np.var(wv_right.astype(float))
fl_right_var = np.var(fl_right.astype(float))
print(f"WV right region variance: {wv_right_var:.1f}")
print(f"FL right region variance: {fl_right_var:.1f}")
