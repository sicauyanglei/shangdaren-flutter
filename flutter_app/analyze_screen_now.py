from PIL import Image
img = Image.open(r"e:/AI-PRJ/shangdaren-game/flutter_app/screen_now.png")
print(f"size={img.size}, mode={img.mode}")
px = img.load()
w, h = img.size

# Count gold-ish pixels (R>200, G>180, B<100)
gold_count = 0
for y in range(h):
    for x in range(w):
        r, g, b, *a = px[x, y]
        if r > 200 and g > 180 and b < 100:
            gold_count += 1
print(f"gold-ish pixels: {gold_count} out of {w*h} ({gold_count*100/(w*h):.2f}%)")

# Sample some card areas - bottom center of screen (player hand)
print("
Sampling card area (y=800-1000, x=200-600):")
for y in range(800, 1000, 50):
    for x in range(200, 600, 100):
        r, g, b, *a = px[x, y]
        print(f"  ({x},{y}): R={r} G={g} B={b}")

# Sample center area (discard pile)
print("
Sampling center area (y=400-600, x=200-500):")
for y in range(400, 600, 50):
    for x in range(200, 500, 100):
        r, g, b, *a = px[x, y]
        print(f"  ({x},{y}): R={r} G={g} B={b}")
