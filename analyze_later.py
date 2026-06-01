from PIL import Image
import numpy as np
from scipy import ndimage

fl = Image.open(r'E:\AI-PRJ\shangdaren-game\fl_game_later.png')
fl_arr = np.array(fl)[:,:,:3]

print("=== Flame Game (Later) ===")
print(f"Size: {fl.size}")

gold_mask = (fl_arr[:,:,0] > 200) & (fl_arr[:,:,1] > 180) & (fl_arr[:,:,2] < 100)
ys, xs = np.where(gold_mask)
if len(xs) > 0:
    labeled, num = ndimage.label(gold_mask)
    for i in range(1, min(num+1, 30)):
        comp_ys, comp_xs = np.where(labeled == i)
        if len(comp_xs) < 20: continue
        x0, x1 = comp_xs.min(), comp_xs.max()
        y0, y1 = comp_ys.min(), comp_ys.max()
        cx = (x0+x1)//2
        cy = (y0+y1)//2
        print(f"Gold [{i}]: ({x0},{y0})-({x1},{y1}) center=({cx},{cy}) size={x1-x0+1}x{y1-y0+1}")

red_mask = (fl_arr[:,:,0] > 180) & (fl_arr[:,:,1] < 80) & (fl_arr[:,:,2] < 80)
ys2, xs2 = np.where(red_mask)
if len(xs2) > 0:
    labeled2, num2 = ndimage.label(red_mask)
    print(f"\nRed components: {num2}")
    for i in range(1, min(num2+1, 30)):
        comp_ys, comp_xs = np.where(labeled2 == i)
        if len(comp_xs) < 20: continue
        x0, x1 = comp_xs.min(), comp_xs.max()
        y0, y1 = comp_ys.min(), comp_ys.max()
        print(f"Red [{i}]: ({x0},{y0})-({x1},{y1}) size={x1-x0+1}x{y1-y0+1}")

green_text_mask = (fl_arr[:,:,0] < 80) & (fl_arr[:,:,1] > 180) & (fl_arr[:,:,2] < 80)
ys3, xs3 = np.where(green_text_mask)
if len(xs3) > 0:
    labeled3, num3 = ndimage.label(green_text_mask)
    print(f"\nGreen text components: {num3}")
    for i in range(1, min(num3+1, 30)):
        comp_ys, comp_xs = np.where(labeled3 == i)
        if len(comp_xs) < 20: continue
        x0, x1 = comp_xs.min(), comp_xs.max()
        y0, y1 = comp_ys.min(), comp_ys.max()
        print(f"Green [{i}]: ({x0},{y0})-({x1},{y1}) size={x1-x0+1}x{y1-y0+1}")

left_area = fl_arr[80:250, 10:260]
left_non_green = np.sum(np.any(left_area > 30, axis=2))
print(f"\nLeft area (melds/discards) non-green pixels: {left_non_green}")

right_area = fl_arr[80:250, 1020:1270]
right_non_green = np.sum(np.any(right_area > 30, axis=2))
print(f"Right area (melds/discards) non-green pixels: {right_non_green}")

fl_left_crop = fl.crop((10, 80, 260, 250))
fl_left_crop.save(r'E:\AI-PRJ\shangdaren-game\fl_left_cards_later.png')
fl_right_crop = fl.crop((1020, 80, 1270, 250))
fl_right_crop.save(r'E:\AI-PRJ\shangdaren-game\fl_right_cards_later.png')
print("Cropped card regions saved")
