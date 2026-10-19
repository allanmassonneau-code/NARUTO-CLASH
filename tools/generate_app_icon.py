#!/usr/bin/env python3
"""Generates the app icon (Uzumaki spiral) as PNG + Windows ICO.
    python3 tools/generate_app_icon.py   (needs Pillow)
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
S = 1024  # supersampled canvas


def spiral_points(cx, cy, turns, r_max, steps=900):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        a = t * turns * 2 * math.pi - math.pi / 2
        r = 18 + t * r_max
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def main():
    os.makedirs(OUT, exist_ok=True)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Rounded dark tile with an orange rim.
    d.rounded_rectangle((24, 24, S - 24, S - 24), radius=210, fill=(24, 18, 32, 255), outline=(255, 140, 30, 255), width=34)
    # Soft glow.
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((170, 170, S - 170, S - 170), fill=(255, 120, 20, 120))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(70)))
    d = ImageDraw.Draw(img)
    # Uzumaki spiral.
    pts = spiral_points(S / 2, S / 2, 2.6, 300)
    for r, color in ((37, (255, 155, 40, 255)), (13, (255, 210, 120, 255))):
        for x, y in pts:
            d.ellipse((x - r, y - r, x + r, y + r), fill=color)
    d.ellipse((S / 2 - 46, S / 2 - 46, S / 2 + 46, S / 2 + 46), fill=(255, 155, 40, 255))
    big = img.resize((256, 256), Image.LANCZOS)
    big.save(os.path.join(OUT, "icon.png"))
    big.save(os.path.join(OUT, "icon.ico"), sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])
    print("wrote assets/icon/icon.png and icon.ico")


if __name__ == "__main__":
    main()
