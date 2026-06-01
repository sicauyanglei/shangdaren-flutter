"""
Atlas Packer - 将上大人字牌的PNG打包为Atlas.webp + atlas.json
竖牌旋转90度横放存储，运行时再旋转回来，节省Atlas空间
用法: python pack_atlas.py
依赖: pip install Pillow
"""
import os
import json
from PIL import Image

Image.MAX_IMAGE_PIXELS = 300_000_000

IMAGES_DIR = r"E:\AI-PRJ\shangdaren-game\flutter_app\assets\html\images"
OUTPUT_DIR = r"E:\AI-PRJ\shangdaren-game\flutter_app\assets\images"

CHARACTERS = [
    "shang", "da", "ren", "qiu", "yi", "ji", "hua", "san", "qian",
    "qi", "shi", "tu", "er", "xiao", "sheng", "ba", "jiu", "zi",
    "jia", "zuo", "wang", "fu", "lu", "shou"
]

def collect_images():
    entries = []
    for name in ["back", "mcard"] + CHARACTERS:
        path = os.path.join(IMAGES_DIR, f"{name}.png")
        if os.path.exists(path):
            entries.append((name, path))

    for name in CHARACTERS:
        for suffix in ["", "C"]:
            path = os.path.join(IMAGES_DIR, "s", f"{name}{suffix}.png")
            if os.path.exists(path):
                entries.append((f"s/{name}{suffix}", path))
    for fn in os.listdir(os.path.join(IMAGES_DIR, "s")):
        if fn.endswith("F.png"):
            path = os.path.join(IMAGES_DIR, "s", fn)
            key = f"s/{fn[:-4]}"
            if not any(k == key for k, _ in entries):
                entries.append((key, path))

    for name in ["back"] + CHARACTERS:
        path = os.path.join(IMAGES_DIR, "v", f"{name}.png")
        if os.path.exists(path):
            entries.append((f"v/{name}", path))

    return entries

def pack_atlas(entries, padding=2, scale=0.5):
    """Pack images into atlas with optional scaling.
    
    Args:
        entries: List of (key, path) tuples
        padding: Padding between sprites
        scale: Scale factor for images (0.5 = half size, 1.0 = original)
    """
    images = []
    for key, path in entries:
        img = Image.open(path).convert("RGBA")
        rotated = False
        if img.height > img.width * 2:
            img = img.rotate(-90, expand=True)
            rotated = True
        # Scale down if needed
        if scale != 1.0:
            new_w = int(img.width * scale)
            new_h = int(img.height * scale)
            if new_w > 0 and new_h > 0:
                img = img.resize((new_w, new_h), Image.LANCZOS)
        images.append((key, img, rotated))

    images.sort(key=lambda x: (-x[1].height, -x[1].width))

    atlas_width = 1024
    best_height = float('inf')
    best_layout = None

    for w in range(512, 4097, 128):  # 最大宽度4096，避免OpenGL纹理限制
        positions = []
        x = padding
        y = padding
        row_height = 0

        for key, img, rotated in images:
            if x + img.width + padding > w:
                x = padding
                y += row_height + padding
                row_height = 0

            positions.append((key, img, rotated, x, y))
            x += img.width + padding
            row_height = max(row_height, img.height)

        total_h = y + row_height + padding
        if total_h < best_height:
            best_height = total_h
            best_layout = (w, list(positions))

    atlas_width, positions = best_layout
    atlas_height = ((best_height + 63) // 64) * 64

    atlas = Image.new("RGBA", (atlas_width, atlas_height), (0, 0, 0, 0))
    frames = {}

    for key, img, rotated, x, y in positions:
        atlas.paste(img, (x, y))
        # Source size is the original display size (before rotation)
        src_w, src_h = (img.height, img.width) if rotated else (img.width, img.height)
        # If scaled, record the scaled source size
        frames[key] = {
            "frame": {"x": x, "y": y, "w": img.width, "h": img.height},
            "rotated": rotated,
            "trimmed": False,
            "spriteSourceSize": {"x": 0, "y": 0, "w": src_w, "h": src_h},
            "sourceSize": {"w": src_w, "h": src_h}
        }

    return atlas, frames

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    entries = collect_images()
    print(f"Collected {len(entries)} images")

    atlas, frames = pack_atlas(entries, scale=0.25)
    print(f"Atlas size: {atlas.width}x{atlas.height}")

    atlas_path = os.path.join(OUTPUT_DIR, "atlas.webp")
    atlas.save(atlas_path, "WEBP", lossless=True, method=6)
    print(f"Saved {atlas_path} ({os.path.getsize(atlas_path)} bytes)")

    json_data = {
        "meta": {
            "image": "atlas.webp",
            "size": {"w": atlas.width, "h": atlas.height},
            "scale": 1
        },
        "frames": frames
    }
    json_path = os.path.join(OUTPUT_DIR, "atlas.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(json_data, f, indent=2, ensure_ascii=False)
    print(f"Saved {json_path}")

if __name__ == "__main__":
    main()
