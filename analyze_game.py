from PIL import Image
import numpy as np
from scipy import ndimage

img = Image.open(r'E:\AI-PRJ\shangdaren-game\fl_game6.png')
arr = np.array(img)[:,:,:3]

print("=== Game Board Analysis ===")
print(f"Size: {img.size}")

gold_mask = (arr[:,:,0] > 200) & (arr[:,:,1] > 180) & (arr[:,:,2] < 100)
ys, xs = np.where(gold_mask)
if len(xs) > 0:
    labeled, num = ndimage.label(gold_mask)
    for i in range(1, min(num+1, 20)):
        comp_ys, comp_xs = np.where(labeled == i)
        if len(comp_xs) < 20: continue
        x0, x1 = comp_xs.min(), comp_xs.max()
        y0, y1 = comp_ys.min(), comp_ys.max()
        cx = (x0+x1)//2
        cy = (y0+y1)//2
        print(f"Gold [{i}]: ({x0},{y0})-({x1},{y1}) center=({cx},{cy}) size={x1-x0+1}x{y1-y0+1}")

dark_mask = np.all(arr < 50, axis=2)
labeled2, num2 = ndimage.label(dark_mask)
print(f"\nDark components: {num2}")
for i in range(1, min(num2+1, 20)):
    comp_ys, comp_xs = np.where(labeled2 == i)
    if len(comp_xs) < 200: continue
    x0, x1 = comp_xs.min(), comp_xs.max()
    y0, y1 = comp_ys.min(), comp_ys.max()
    cx = (x0+x1)//2
    cy = (y0+y1)//2
    print(f"Dark [{i}]: ({x0},{y0})-({x1},{y1}) center=({cx},{cy}) size={x1-x0+1}x{y1-y0+1}")

card_color_mask = (arr[:,:,0] > 180) & (arr[:,:,1] < 80) & (arr[:,:,2] < 80)
ys3, xs3 = np.where(card_color_mask)
if len(xs3) > 0:
    labeled3, num3 = ndimage.label(card_color_mask)
    print(f"\nRed components: {num3}")
    for i in range(1, min(num3+1, 20)):
        comp_ys, comp_xs = np.where(labeled3 == i)
        if len(comp_xs) < 20: continue
        x0, x1 = comp_xs.min(), comp_xs.max()
        y0, y1 = comp_ys.min(), comp_ys.max()
        print(f"Red [{i}]: ({x0},{y0})-({x1},{y1}) size={x1-x0+1}x{y1-y0+1}")

card_green_mask = (arr[:,:,0] < 80) & (arr[:,:,1] > 180) & (arr[:,:,2] < 80)
ys4, xs4 = np.where(card_green_mask)
if len(xs4) > 0:
    labeled4, num4 = ndimage.label(card_green_mask)
    print(f"\nGreen text components: {num4}")
    for i in range(1, min(num4+1, 20)):
        comp_ys, comp_xs = np.where(labeled4 == i)
        if len(comp_xs) < 20: continue
        x0, x1 = comp_xs.min(), comp_xs.max()
        y0, y1 = comp_ys.min(), comp_ys.max()
        print(f"Green [{i}]: ({x0},{y0})-({x1},{y1}) size={x1-x0+1}x{y1-y0+1}")
