"""Turn rendered PNG frames into an animated WebP for the reports.

    python cad/anim/make_webp.py "<frames glob>" <out.webp> [hold_last_ms]

The frames come from rgb_anim.m or lube_anim.m (1200 x 760 px); the WebP is 960 x 608 px at 25 frames
a second, lossy quality 72. Needs Pillow with WebP support.
"""
import glob
import os
import sys

from PIL import Image


def build(pattern, out, hold_last=0, size=(960, 608), ms=40, quality=72):
    files = sorted(glob.glob(pattern))
    frames = [Image.open(f).convert('RGB').resize(size, Image.LANCZOS) for f in files]
    durations = [ms] * len(frames)
    if hold_last:
        durations[-1] = hold_last
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=durations, loop=0,
                   quality=quality, method=4)
    print('%s: %d frames, %.2f MB' % (out, len(frames), os.path.getsize(out) / 1e6))


if __name__ == '__main__':
    build(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 0)
