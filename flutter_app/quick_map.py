from PIL import Image

for fname in ['wv_step0_initial.png', 'wv_step1_after_start.png', 'wv_step2_dealing.png', 'wv_step3_playing.png']:
    try:
        img = Image.open(fname)
        w, h = img.size
        print(f'\n=== {fname} ({w}x{h}) ===')

        # Quick layout map
        for y in [0, 40, 80, 160, 280, 400, 520, 600, 680]:
            row = []
            for x in range(0, w, 80):
                p = img.getpixel((x, y))
                if p[0] < 30 and p[1] < 30 and p[2] < 30:
                    c = '.'
                elif p[1] > p[0] and p[1] > p[2] and p[1] > 50:
                    c = 'G'
                elif p[0] > 200 and p[1] > 200 and p[2] > 200:
                    c = 'W'
                elif p[0] > 200 and p[1] > 150 and p[2] < 100:
                    c = 'Y'
                elif p[0] > 200 and p[1] < 100 and p[2] < 100:
                    c = 'R'
                elif p[0] > 100 and p[1] > 100 and p[2] > 100:
                    c = 'L'
                else:
                    c = 'x'
                row.append(c)
            line = ' '.join(row)
            print(f'  y={y:3d}: {line}')
    except FileNotFoundError:
        print(f'\n=== {fname}: NOT FOUND ===')
