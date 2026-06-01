from PIL import Image
import os

path = os.path.join(r'E:\AI-PRJ\shangdaren-game', 'screenshot5.png')
img = Image.open(path)
w, h = img.size
print(f"Screenshot5: {w}x{h}")

# Check bottom area for hand cards (white cards)
bottom = img.crop((0, int(h*0.7), w, h))
bp = list(bottom.getdata())
white = sum(1 for p in bp if p[0] > 200 and p[1] > 200 and p[2] > 200)
print(f"White in bottom 30%: {white/len(bp)*100:.1f}%")

# Check for teal (start button still visible?)
teal_count = 0
for y in range(250, 500):
    for x in range(400, 900):
        r, g, b, a = img.getpixel((x, y))
        if r > 50 and r < 120 and g > 170 and g < 230 and b > 160 and b < 220:
            teal_count += 1
print(f"Teal pixels in center: {teal_count}")

# Check for gold/yellow (discard pulse effect)
gold_count = 0
for y in range(0, h, 4):
    for x in range(0, w, 4):
        r, g, b, a = img.getpixel((x, y))
        if r > 200 and g > 180 and b < 100:
            gold_count += 1
print(f"Gold/yellow pixels (sampled): {gold_count}")

# Check top area for time
top = img.crop((0, 0, 300, 50))
tp = list(top.getdata())
light = sum(1 for p in tp if p[0] > 150 and p[1] > 150 and p[2] > 150)
print(f"Light in top-left: {light/len(tp)*100:.1f}%")

# Check for card-like regions (white rectangles)
# Sample the bottom center where hand cards should be
print(f"Pixel at (640,680): {img.getpixel((640,680))}")
print(f"Pixel at (640,650): {img.getpixel((640,650))}")
print(f"Pixel at (640,600): {img.getpixel((640,600))}")
print(f"Pixel at (640,500): {img.getpixel((640,500))}")
print(f"Pixel at (640,400): {img.getpixel((640,400))}")
print(f"Pixel at (640,300): {img.getpixel((640,300))}")
print(f"Pixel at (640,200): {img.getpixel((640,200))}")
print(f"Pixel at (640,100): {img.getpixel((640,100))}")

# Check for piao selection popup
piao_area = img.crop((int(w*0.3), int(h*0.3), int(w*0.7), int(h*0.7)))
pp = list(piao_area.getdata())
piao_white = sum(1 for p in pp if p[0] > 200 and p[1] > 200 and p[2] > 200)
piao_green = sum(1 for p in pp if p[1] > 80 and p[0] < 100 and p[2] < 50)
print(f"Center: white={piao_white/len(pp)*100:.1f}%, dark_green={piao_green/len(pp)*100:.1f}%")

# Check for countdown timer (red circle)
red_count = 0
for y in range(0, h, 4):
    for x in range(0, w, 4):
        r, g, b, a = img.getpixel((x, y))
        if r > 200 and g < 80 and b < 80:
            red_count += 1
print(f"Red pixels (sampled): {red_count}")
