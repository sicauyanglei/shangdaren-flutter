from PIL import Image
import numpy as np

img = Image.open(r'E:\AI-PRJ\shangdaren-game\fl_start2.png')
arr = np.array(img)[:,:,:3]

for y in range(420, 520, 10):
    for x in range(550, 900, 25):
        px = arr[y, x]
        is_teal = px[0] > 50 and px[0] < 100 and px[1] > 160 and px[2] > 150 and px[2] < 220
        is_white = px[0] > 200 and px[1] > 200 and px[2] > 200
        if is_teal or is_white:
            label = "TEAL" if is_teal else "WHITE"
            print(f'({x},{y}): {px} {label}')
