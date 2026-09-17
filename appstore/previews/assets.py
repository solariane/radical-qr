#!/usr/bin/env python3
"""Static layers for the App Preview composite (886x1920): background with the
phone, the rounded screen mask, and one transparent PNG per caption."""
import json, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 886, 1920
HERE = os.path.dirname(os.path.abspath(__file__))
POST = os.path.join(os.environ.get("PREVIEW_WORK", "/tmp/radicalqr-previews"), "layers")
BOLD = "/Library/Fonts/SF-Pro-Display-Bold.otf"
# Phone geometry: screen keeps the capture's 1320x2868 aspect.
SCREEN_H = 1452
SCREEN_W = round(SCREEN_H * 1320 / 2868)       # 668
BEZEL = 14
PHONE_W, PHONE_H = SCREEN_W + 2 * BEZEL, SCREEN_H + 2 * BEZEL
PHONE_X, PHONE_Y = (W - PHONE_W) // 2, 380
SCREEN_X, SCREEN_Y = PHONE_X + BEZEL, PHONE_Y + BEZEL
SCREEN_R, PHONE_R = 92, 106

def gradient():
    img = Image.new("RGB", (W, H))
    a, b = (0x66, 0x7e, 0xea), (0x76, 0x4b, 0xa2)
    px = img.load()
    for y in range(H):
        for x in range(W):
            t = (x / W + y / H) / 2
            px[x, y] = tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))
    return img

def background():
    bg = gradient().convert("RGBA")
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [PHONE_X, PHONE_Y + 16, PHONE_X + PHONE_W, PHONE_Y + PHONE_H + 16], PHONE_R, fill=(0, 0, 0, 110))
    bg = Image.alpha_composite(bg, shadow.filter(ImageFilter.GaussianBlur(22)))
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle([PHONE_X, PHONE_Y, PHONE_X + PHONE_W, PHONE_Y + PHONE_H], PHONE_R, fill=(15, 15, 24, 255))
    bg.convert("RGB").save(f"{POST}/bg.png")

def mask():
    m = Image.new("L", (SCREEN_W, SCREEN_H), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, SCREEN_W - 1, SCREEN_H - 1], SCREEN_R, fill=255)
    m.save(f"{POST}/mask.png")

def fit(lines, max_w, start=70):
    size = start
    while size > 30:
        f = ImageFont.truetype(BOLD, size)
        if all(f.getlength(l) <= max_w for l in lines):
            return f, size
        size -= 2
    return ImageFont.truetype(BOLD, size), size

def caption(lines, out):
    img = Image.new("RGBA", (W, 380), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f, size = fit(lines, W - 90)
    step = round(size * 1.18)
    y0 = 208 - step * len(lines) / 2
    for i, line in enumerate(lines):
        w = f.getlength(line)
        d.text(((W - w) / 2, y0 + i * step), line, font=f, fill=(255, 255, 255, 255 if i == 0 else 235))
    img.save(out)

if __name__ == "__main__":
    os.makedirs(POST, exist_ok=True)
    background(); mask()
    caps = json.load(open(f"{HERE}/captions.json"))
    os.makedirs(f"{POST}/cap", exist_ok=True)
    for sb, langs in caps.items():
        for lang, beats in langs.items():
            for beat, lines in beats.items():
                caption(lines, f"{POST}/cap/{sb}_{lang}_{beat}.png")
    print("SCREEN", SCREEN_X, SCREEN_Y, SCREEN_W, SCREEN_H)
