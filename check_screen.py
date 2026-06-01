from PIL import Image
img = Image.open(r'E:\AI-PRJ\shangdaren-game\screen.png')
w, h = img.size
sx, sy = w/1280, h/720

print('Screen: %dx%d, scale: %.3f, %.3f' % (w, h, sx, sy))

# Player 0 AI hand: design x=9.6, y=126
p0x = int(9.6 * sx)
p0y = int(126 * sy)
print('Player0 hand area: (%d,%d)' % (p0x, p0y))

# Scan Player 0 AI hand area
print('=== Player 0 (left) AI hand cards ===')
for y in range(p0y - 5, p0y + int(70 * sy), 5):
    row = []
    for x in range(p0x, p0x + int(340 * sx), int(4 * sx)):
        r, g, b, a = img.getpixel((x, y))
        if r > 100 or b > 100:
            row.append('C')
        elif g > 80 and r > 15:
            row.append('B')
        elif g > 50:
            row.append('g')
        else:
            row.append('.')
    print('y=%d: %s' % (y, ''.join(row[:70])))

# Player 2 AI hand: design x=1280-9.6
p2x_start = int((1280 - 9.6) * sx)
print()
print('=== Player 2 (right) AI hand cards ===')
for y in range(p0y - 5, p0y + int(70 * sy), 5):
    row = []
    for x in range(p2x_start, p2x_start - int(280 * sx), -int(4 * sx)):
        r, g, b, a = img.getpixel((x, y))
        if r > 100 or b > 100:
            row.append('C')
        elif g > 80 and r > 15:
            row.append('B')
        elif g > 50:
            row.append('g')
        else:
            row.append('.')
    print('y=%d: %s' % (y, ''.join(row[:55])))

# Check card back image colors
print()
print('=== Card back pixel samples ===')
for label, px, py in [('P0 card', p0x + 5, p0y + 10), ('P0 inner', p0x + 10, p0y + 20),
                       ('P2 card', p2x_start - 30, p0y + 10), ('P2 inner', p2x_start - 20, p0y + 20)]:
    if 0 <= px < w and 0 <= py < h:
        r, g, b, a = img.getpixel((px, py))
        print('%s (%d,%d): (%d,%d,%d)' % (label, px, py, r, g, b))
