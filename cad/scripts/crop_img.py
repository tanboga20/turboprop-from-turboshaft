"""Clean the CATIA screen captures for the reports: blank the specification tree, the compass and the
axis triad, then crop to the part with a margin.

    python cad/scripts/crop_img.py cad/img/case_iso.jpg [more files]      (needs Pillow)

Each file is overwritten with a PNG of the same name (case_iso.jpg -> case_iso.png).
Source: Phase 2 report, Section 2.9.
"""
import os
import sys

from PIL import Image, ImageChops


def clean(path, margin=24):
    im = Image.open(path).convert('RGB')
    w, h = im.size
    white = (255, 255, 255)
    for box in [(0, 0, 300, 160), (w - 220, 0, w, 200), (w - 110, h - 80, w, h)]:
        im.paste(white, box)
    bg = Image.new('RGB', im.size, white)
    diff = ImageChops.difference(im, bg).convert('L').point(lambda v: 255 if v > 18 else 0)
    bbox = diff.getbbox()
    if bbox:
        x0, y0, x1, y1 = bbox
        im = im.crop((max(0, x0 - margin), max(0, y0 - margin), min(w, x1 + margin), min(h, y1 + margin)))
    out = os.path.splitext(path)[0] + '.png'
    im.save(out)
    return out


if __name__ == '__main__':
    for p in sys.argv[1:]:
        print(clean(p))
