from PIL import Image
import os

path = os.path.join(r'E:\AI-PRJ\shangdaren-game', 'screenshot8.png')
img = Image.open(path)
w, h = img.size
print(f"Screenshot8: {w}x{h}")

# Check if start screen is gone
teal_count = 0
for y in range(266, 486):
    for x in range(489, 835):
        r, g, b, a = img.getpixel((x, y))
        if r > 50 and r < 120 and g > 170 and g < 230 and b > 160 and b < 220:
            teal_count += 1
print(f"Teal pixels in button area: {teal_count}")

if teal_count > 10000:
    print("Start screen STILL showing!")
else:
    print("Start screen GONE - game started!")
    # Check for piao popup
    center = img.crop((int(w*0.2), int(h*0.2), int(w*0.8), int(h*0.8)))
    cp = list(center.getdata())
    dark_green = sum(1 for p in cp if p[1] > 60 and p[1] < 120 and p[0] < 40 and p[2] < 50)
    print(f"Dark green in center: {dark_green/len(cp)*100:.1f}%")
    
    # Check bottom for hand cards
    bottom = img.crop((0, int(h*0.7), w, h))
    bp = list(bottom.getdata())
    white = sum(1 for p in bp if p[0] > 200 and p[1] > 200 and p[2] > 200)
    print(f"White in bottom 30%: {white/len(bp)*100:.1f}%")
