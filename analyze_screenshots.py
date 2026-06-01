from PIL import Image
import sys

def analyze_screenshot(path, name):
    img = Image.open(path)
    w, h = img.size
    print(f"\n=== {name} ({w}x{h}) ===")
    
    # Check if mostly black (blank screen)
    pixels = list(img.getdata())
    total = len(pixels)
    dark_count = sum(1 for p in pixels if p[0] < 30 and p[1] < 30 and p[2] < 30)
    dark_pct = dark_count / total * 100
    print(f"Dark pixels: {dark_pct:.1f}%")
    
    if dark_pct > 95:
        print("WARNING: Screen appears mostly black/blank!")
        return
    
    # Check for green background (game table)
    green_count = sum(1 for p in pixels if p[1] > 80 and p[1] > p[0] and p[1] > p[2])
    green_pct = green_count / total * 100
    print(f"Green pixels: {green_pct:.1f}%")
    
    # Check for gold/yellow (borders, buttons)
    gold_count = sum(1 for p in pixels if p[0] > 200 and p[1] > 180 and p[2] < 100)
    gold_pct = gold_count / total * 100
    print(f"Gold/yellow pixels: {gold_pct:.1f}%")
    
    # Check bottom area for hand cards (white cards)
    bottom_region = img.crop((0, int(h*0.7), w, h))
    bottom_pixels = list(bottom_region.getdata())
    white_count = sum(1 for p in bottom_pixels if p[0] > 200 and p[1] > 200 and p[2] > 200)
    white_pct = white_count / len(bottom_pixels) * 100
    print(f"White pixels in bottom 30%: {white_pct:.1f}%")
    
    # Check center area for played card
    center_region = img.crop((int(w*0.3), 0, int(w*0.7), int(h*0.15)))
    center_pixels = list(center_region.getdata())
    center_white = sum(1 for p in center_pixels if p[0] > 200 and p[1] > 200 and p[2] > 200)
    center_white_pct = center_white / len(center_pixels) * 100
    print(f"White pixels in center top: {center_white_pct:.1f}%")
    
    # Check top-left for time display
    top_region = img.crop((0, 0, 200, 40))
    top_pixels = list(top_region.getdata())
    light_count = sum(1 for p in top_pixels if p[0] > 150 and p[1] > 150 and p[2] > 150)
    light_pct = light_count / len(top_pixels) * 100
    print(f"Light pixels in top-left: {light_pct:.1f}%")
    
    # Sample specific regions
    # Player 1 avatar area (left side)
    avatar_region = img.crop((0, int(h*0.5), 80, int(h*0.9)))
    avatar_pixels = list(avatar_region.getdata())
    avatar_color = [0, 0, 0]
    for p in avatar_pixels[:100]:
        avatar_color[0] += p[0]
        avatar_color[1] += p[1]
        avatar_color[2] += p[2]
    n = min(100, len(avatar_pixels))
    if n > 0:
        avatar_color = [c // n for c in avatar_color]
    print(f"Player1 avatar avg color: RGB({avatar_color[0]}, {avatar_color[1]}, {avatar_color[2]})")

base_dir = r'E:\AI-PRJ\shangdaren-game'
for name in ['screenshot1.png', 'screenshot2.png', 'screenshot3.png']:
    import os
    path = os.path.join(base_dir, name)
    if os.path.exists(path):
        analyze_screenshot(path, name)
