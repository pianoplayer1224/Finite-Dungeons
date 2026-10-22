"""Build assets/sprites/hero.png from the artist's preview sheet, tools/art/Sprite Sheet Hero.png
(tools/art/ has a .gdignore, so Godot neither imports nor exports the source art).

The preview is a labelled layout on a lossy green background, so the game cannot use it directly.
This keys out the green (unmixing each pixel against it and snapping to the hero's palette, which
also removes the compression noise; a pixel only just opaque that touches the background is blur
and is dropped too) and repacks it: one row per animation, uniform 56x36 cells,
feet on each cell's bottom row and the hero where the artist placed it in every frame, so the
animations line up with each other. Row order and frame counts must match SpriteAnim.HERO_ANIMS;
the script checks that first and prints the table to paste in when they differ.

    python3 -I tools/make_hero_sheet.py [path/to/Sprite Sheet Hero.png]
"""
import pathlib
import re
import sys
import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "tools/art/Sprite Sheet Hero.png"
DST = ROOT / "assets/sprites/hero.png"
BG = np.array([107, 190, 48.0])
PALETTE = np.array([
    [34, 30, 34],     # outline, eyes, blade
    [255, 255, 255],  # body
    [197, 190, 185],  # body shade
    [170, 22, 22],    # scarf
    [84, 22, 16],     # scarf shade
], dtype=float)
CELL = (56, 36)
# name, top, bottom, first x, frame pitch, frames: measured on the preview. Each animation is a
# strip of equal-width frames (the pitch differs per animation); the bottom row is where the feet stand.
ANIMS = [
    ("idle",       16, 47,  16, 32, 16),
    ("walk",       64, 95,  16, 32, 4),
    ("jump",       112, 143, 16, 32, 4),
    ("fall",       112, 143, 160, 32, 3),
    ("attack1",    160, 191, 16, 36, 5),
    ("attack2",    208, 239, 16, 42, 5),
    ("air_attack", 208, 239, 240, 42, 5),
    ("attack3",    256, 287, 16, 48, 8),
    ("attack4",    316, 351, 16, 56, 7),
    ("death",      368, 399, 16, 48, 7),
]
# Opacity a pixel needs to be kept; one kept by less than EDGE_ALPHA that touches the background
# is background blurred into the art (e.g. the gap between the legs) and is dropped as well.
KEEP_ALPHA = 0.5
EDGE_ALPHA = 0.56

# SpriteAnim plays rows by HERO_ANIMS ([row, frames] per name), so it must list ANIMS in order.
gd = (ROOT / "scripts/ui/sprite_anim.gd").read_text()
table = re.search(r"HERO_ANIMS := \{(.*?)\}", gd, re.S).group(1)
have = [(k, int(r), int(n)) for k, r, n in re.findall(r'"(\w+)": \[(\d+), (\d+)\]', table)]
want = [(name, r, n) for r, (name, *_, n) in enumerate(ANIMS)]
if have != want:
    sys.exit("SpriteAnim.HERO_ANIMS does not match ANIMS; it should be:\n    "
             + ", ".join('"%s": [%d, %d]' % w for w in want))

src = np.array(Image.open(SRC).convert("RGB")).astype(float)
# Unmix every pixel against the green: p = bg + a * (C - bg) for the best palette colour C.
d = src[:, :, None, :] - BG                       # H W 1 3
cb = PALETTE - BG                                  # K 3
a = np.clip((d * cb).sum(-1) / (cb ** 2).sum(-1), 0.0, 1.0)   # H W K
err = ((d - a[..., None] * cb) ** 2).sum(-1)
best = err.argmin(-1)
alpha = np.take_along_axis(a, best[..., None], -1)[..., 0]
rgba = np.zeros(src.shape[:2] + (4,), np.uint8)
rgba[..., :3] = PALETTE[best].astype(np.uint8)
keep = alpha >= KEEP_ALPHA
while True:
    clear = np.zeros_like(keep)
    clear[1:-1, 1:-1] = ~(keep[:-2, 1:-1] & keep[2:, 1:-1] & keep[1:-1, :-2] & keep[1:-1, 2:])
    drop = keep & (alpha < EDGE_ALPHA) & clear
    if not drop.any():
        break
    keep &= ~drop
rgba[..., 3] = np.where(keep, 255, 0)

cols = max(n for *_, n in ANIMS)
out = np.zeros((CELL[1] * len(ANIMS), CELL[0] * cols, 4), np.uint8)
for r, (name, top, bottom, x0, pitch, n) in enumerate(ANIMS):
    h = bottom - top + 1
    for f in range(n):
        cell = rgba[top:bottom + 1, x0 + f * pitch: x0 + (f + 1) * pitch]
        oy = r * CELL[1] + CELL[1] - h
        ox = f * CELL[0]
        out[oy:oy + h, ox:ox + pitch] = cell
Image.fromarray(out).save(DST, optimize=True)
print("wrote %s: %s" % (DST.relative_to(ROOT), ", ".join("%s %d" % (a[0], a[-1]) for a in ANIMS)))
