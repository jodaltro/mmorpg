"""Draws the game's icon (a glowing cell) and the sizes the web manifest needs. Run when the look changes: python tools/make_web_icons.py"""
import math
from PIL import Image, ImageDraw, ImageFilter


def cell(size: int) -> Image.Image:
    s = size * 2
    img = Image.new("RGBA", (s, s), (2, 5, 15, 255))
    px = img.load()
    cx = cy = s / 2
    for y in range(s):
        for x in range(s):
            d = math.hypot(x - cx, y - cy) / (s / 2)
            bg = max(0.0, 1.0 - d * 1.05)
            r, g, b = 2 + 10 * bg, 5 + 38 * bg, 15 + 80 * bg
            px[x, y] = (int(r), int(g), int(b), 255)
    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for k in range(6, 0, -1):
        rad = s * (0.27 + 0.045 * k)
        gd.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(50, 170, 255, 22))
    glow = glow.filter(ImageFilter.GaussianBlur(s * 0.02))
    img = Image.alpha_composite(img, glow)
    d = ImageDraw.Draw(img)
    # membrane: a slightly lumpy ring
    pts = []
    for i in range(120):
        a = i / 120 * math.tau
        rad = s * 0.285 * (1 + 0.045 * math.sin(a * 3 + 0.6) + 0.025 * math.sin(a * 5))
        pts.append((cx + math.cos(a) * rad, cy + math.sin(a) * rad))
    d.polygon(pts, fill=(14, 52, 110, 255), outline=(110, 170, 255, 255))
    d.line(pts + [pts[0]], fill=(120, 180, 255, 255), width=int(s * 0.012))
    n = s * 0.115
    d.ellipse([cx - n, cy - n, cx + n, cy + n], fill=(31, 111, 196, 255), outline=(150, 210, 255, 255), width=int(s * 0.008))
    c = s * 0.045
    d.ellipse([cx - c, cy - c, cx + c, cy + c], fill=(150, 250, 255, 255))
    return img.resize((size, size), Image.LANCZOS)


big = cell(512)
big.save("icon.png")
big.resize((192, 192), Image.LANCZOS).save("web/icon-192.png")
big.save("web/icon-512.png")
print("icons ok")
