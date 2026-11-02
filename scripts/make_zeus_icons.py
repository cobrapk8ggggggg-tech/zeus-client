#!/usr/bin/env python3
"""Derive clean, text-free Zeus branding images from assets/branding/zeus-logo.png.

Deterministic pipeline:
1. Kill ONLY neutral-gray text pixels (white anti-aliased letters) in the lower
   text band — gold bolt pixels (r-b large) are preserved.
2. Segment the golden bolt with a feathered luminance alpha mask.
3. Composite onto new canvases:
     - assets/branding/app_icon.png   (1024x1024, navy bg  -> launcher/web/desktop icon source)
     - assets/icons/dark_icon.png     (655x655,  black bg  -> in-app dark-surface logo)
     - assets/icons/light_icon.png    (655x655,  white bg  -> in-app light-surface logo)
Idempotent: always re-derives from zeus-logo.png.
"""
from PIL import Image, ImageFilter
import numpy as np
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "branding", "zeus-logo.png")

img = Image.open(SRC).convert("RGB")
a = np.asarray(img).astype(np.float64)
h, w, _ = a.shape

# ---- 1. Erase neutral-gray text pixels in the lower text band (y >= 740) ----
r, g, b = a[..., 0], a[..., 1], a[..., 2]
lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
neutral = (np.abs(r - b) < 30) & (np.abs(r - g) < 30) & (np.abs(g - b) < 30)
text_band = np.zeros_like(neutral)
text_band[740:, :] = True
kill = neutral & text_band & (lum > 35)
# dilate the kill mask to swallow anti-aliased fringes
km = Image.fromarray((kill * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7))
kill = np.asarray(km) > 0
kill[735:, :] = kill[735:, :]  # keep band restriction
kill[:740, :] = False
print(f"kill pixels: {kill.sum()}")

# fill killed pixels with same-row background sample (x=1005 is text-free margin)
for y in range(h):
    if kill[y].any():
        a[y, kill[y]] = a[y, 1005]
img_clean = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))

# ---- 2. Bolt bounding box via gold mask (recomputed AFTER text removal) ----
r, g, b = a[..., 0], a[..., 1], a[..., 2]
gold = (r > 120) & (r - b > 40) & (g > 70)
ys, xs = np.where(gold)
y0, y1, x0, x1 = int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())
print(f"bolt bbox: x {x0}..{x1}, y {y0}..{y1}")

crop = img_clean.crop((x0, y0, x1 + 1, y1 + 1))
ca = np.asarray(crop).astype(np.float64)

# ---- 3. Feathered alpha from luminance (bolt bright, bg dark navy) ----
cl = 0.2126 * ca[..., 0] + 0.7152 * ca[..., 1] + 0.0722 * ca[..., 2]
lo, hi = 55.0, 110.0
alpha = np.clip((cl - lo) / (hi - lo), 0.0, 1.0)
alpha_img = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
bolt = crop.convert("RGBA")
bolt.putalpha(alpha_img)


def composite_centered(canvas: Image.Image, glyph: Image.Image, scale: float) -> Image.Image:
    cw, ch = canvas.size
    target = int(min(cw, ch) * scale)
    gw, gh = glyph.size
    s = target / max(gw, gh)
    g2 = glyph.resize((max(1, int(gw * s)), max(1, int(gh * s))), Image.LANCZOS)
    canvas.paste(g2, ((cw - g2.width) // 2, (ch - g2.height) // 2), g2)
    return canvas


NAVY_TOP = (15, 22, 36)
NAVY_BOTTOM = (6, 9, 17)

grad = np.repeat(np.linspace(0, 1, 1024).reshape(-1, 1, 1), 1024, axis=1)  # (1024,1024,1)
top = np.array(NAVY_TOP, dtype=np.float64)
bot = np.array(NAVY_BOTTOM, dtype=np.float64)
canvas_np = top * (1 - grad) + bot * grad
app_icon = Image.fromarray(np.clip(canvas_np, 0, 255).astype(np.uint8))
app_icon = composite_centered(app_icon, bolt, 0.78)
assert app_icon.size == (1024, 1024)
app_icon.save(os.path.join(ROOT, "assets", "branding", "app_icon.png"))

# ---- in-app dark/light icons: TRANSPARENT background.
# ImageIcon tints fully-opaque images solid-color, so these must carry real alpha.
dark_icon = Image.new("RGBA", (655, 655), (0, 0, 0, 0))
dark_icon = composite_centered(dark_icon, bolt, 0.84)
dark_icon.save(os.path.join(ROOT, "assets", "icons", "dark_icon.png"))

light_icon = Image.new("RGBA", (655, 655), (0, 0, 0, 0))
light_icon = composite_centered(light_icon, bolt, 0.84)
light_icon.save(os.path.join(ROOT, "assets", "icons", "light_icon.png"))

for p in ("app_icon.png",):
    im = Image.open(os.path.join(ROOT, "assets", "branding", p))
    print(p, im.size, im.mode)
print("OK done")
