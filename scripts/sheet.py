"""Stitch the cells written by scripts/sheet.gd into one contact sheet.

Kept out of GDScript deliberately: compositing there would mean reading every
frame back into the engine, and the point of the sheet is to be looked at.
"""
import os
import sys
from PIL import Image, ImageDraw

src = sys.argv[1]
dst = sys.argv[2]
span = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
cells = sorted(f for f in os.listdir(src) if f.startswith("cell_"))
if not cells:
    raise SystemExit("no cells in " + src)

ims = [Image.open(os.path.join(src, f)).convert("RGB") for f in cells]
scale = 0.46
w, h = int(ims[0].width * scale), int(ims[0].height * scale)
cols = 6
rows = (len(ims) + cols - 1) // cols
pad, top = 6, 18
sheet = Image.new("RGB", (cols * (w + pad) + pad, rows * (h + pad + top) + pad), (24, 24, 28))
d = ImageDraw.Draw(sheet)
for i, im in enumerate(ims):
    x = pad + (i % cols) * (w + pad)
    y = pad + (i // cols) * (h + pad + top)
    d.text((x + 2, y + 3), "%d  t=%.1fs" % (i, span * (i + 1) / len(ims) if span else 0),
           fill=(210, 210, 220))
    sheet.paste(im.resize((w, h), Image.LANCZOS), (x, y + top))
sheet.save(dst)
print("wrote %s  (%d cells, %dx%d)" % (dst, len(ims), sheet.width, sheet.height))
