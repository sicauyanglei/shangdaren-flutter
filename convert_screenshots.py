import base64
import os

screenshots = ['screenshot1.png', 'screenshot2.png', 'screenshot3.png']
base_dir = r'E:\AI-PRJ\shangdaren-game'

for name in screenshots:
    path = os.path.join(base_dir, name)
    if not os.path.exists(path):
        continue
    with open(path, 'rb') as f:
        data = base64.b64encode(f.read()).decode()
    html = '''<!DOCTYPE html>
<html><body style="background:#000;margin:0;display:flex;justify-content:center;align-items:center;min-height:100vh">
<img src="data:image/png;base64,{}" style="max-width:100%;max-height:100vh">
</body></html>'''.format(data)
    out = os.path.join(base_dir, name.replace('.png', '.html'))
    with open(out, 'w') as f:
        f.write(html)
    print(f'Created {out}')
