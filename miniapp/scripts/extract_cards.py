"""
从 atlas.webp + atlas.json 裁剪出单独的卡牌图片
用于微信小程序卡牌显示
"""
import json
import os
from PIL import Image

ATLAS_DIR = r'E:\AI-PRJ\shangdaren-game\flutter_app\assets\images'
OUTPUT_DIR = r'E:\AI-PRJ\shangdaren-game\miniapp\src\assets\cards'

os.makedirs(OUTPUT_DIR, exist_ok=True)

# 加载精灵图
atlas_img = Image.open(os.path.join(ATLAS_DIR, 'atlas.webp'))
with open(os.path.join(ATLAS_DIR, 'atlas.json'), 'r', encoding='utf-8') as f:
    atlas_data = json.load(f)

frames = atlas_data['frames']
count = 0

for key, info in frames.items():
    frame = info['frame']
    rotated = info.get('rotated', False)
    src_x = frame['x']
    src_y = frame['y']
    src_w = frame['w']
    src_h = frame['h']
    
    # 裁剪区域
    crop_box = (src_x, src_y, src_x + src_w, src_y + src_h)
    sprite = atlas_img.crop(crop_box)
    
    # 如果旋转了90度，需要转回来
    if rotated:
        sprite = sprite.transpose(Image.ROTATE_270)
    
    # 替换 / 为 _ 用于文件名
    filename = key.replace('/', '_') + '.png'
    sprite.save(os.path.join(OUTPUT_DIR, filename), 'PNG')
    count += 1
    print(f'  Saved: {filename} ({sprite.width}x{sprite.height})')

print(f'\nDone! {count} sprites extracted to {OUTPUT_DIR}')
