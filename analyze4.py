from PIL import Image
import os

path = os.path.join(r'E:\AI-PRJ\shangdaren-game', 'screenshot4.png')
if os.path.exists(path):
    img = Image.open(path)
    w, h = img.size
    print(f"Screenshot4: {w}x{h}")
    
    # Check various regions
    # Bottom area for hand cards
    bottom = img.crop((0, int(h*0.7), w, h))
    bp = list(bottom.getdata())
    white = sum(1 for p in bp if p[0] > 200 and p[1] > 200 and p[2] > 200)
    print(f"White in bottom 30%: {white/len(bp)*100:.1f}%")
    
    # Center for buttons/start screen
    center = img.crop((int(w*0.3), int(h*0.3), int(w*0.7), int(h*0.7)))
    cp = list(center.getdata())
    white_c = sum(1 for p in cp if p[0] > 200 and p[1] > 200 and p[2] > 200)
    gold_c = sum(1 for p in cp if p[0] > 200 and p[1] > 180 and p[2] < 100)
    green_c = sum(1 for p in cp if p[1] > 80 and p[1] > p[0] and p[1] > p[2])
    print(f"Center: white={white_c/len(cp)*100:.1f}%, gold={gold_c/len(cp)*100:.1f}%, green={green_c/len(cp)*100:.1f}%")
    
    # Check for red pixels (start button)
    red_c = sum(1 for p in cp if p[0] > 180 and p[1] < 80 and p[2] < 80)
    print(f"Center red pixels: {red_c/len(cp)*100:.1f}%")
    
    # Top area for time
    top = img.crop((0, 0, 300, 50))
    tp = list(top.getdata())
    light = sum(1 for p in tp if p[0] > 150 and p[1] > 150 and p[2] > 150)
    print(f"Light in top-left: {light/len(tp)*100:.1f}%")
    
    # Sample specific pixel colors at key locations
    print(f"Pixel at (640,360): {img.getpixel((640,360))}")
    print(f"Pixel at (640,500): {img.getpixel((640,500))}")
    print(f"Pixel at (640,600): {img.getpixel((640,600))}")
    print(f"Pixel at (640,680): {img.getpixel((640,680))}")
    print(f"Pixel at (100,360): {img.getpixel((100,360))}")
    print(f"Pixel at (1180,360): {img.getpixel((1180,360))}")
