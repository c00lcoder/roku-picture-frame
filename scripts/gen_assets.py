#!/usr/bin/env python3
"""Generate placeholder PNG icons and splash screens for the Roku channel.

No third-party deps -- writes valid PNGs by hand using zlib + struct.
Run from the repo root:  python3 scripts/gen_assets.py
"""

import os
import struct
import zlib


def write_png(path, width, height, pixel_fn):
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type: none
        for x in range(width):
            r, g, b = pixel_fn(x, y)
            raw.append(r)
            raw.append(g)
            raw.append(b)

    def chunk(chunk_type, data):
        crc = zlib.crc32(chunk_type + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", crc)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    idat = zlib.compress(bytes(raw), 9)

    with open(path, "wb") as f:
        f.write(sig)
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", idat))
        f.write(chunk(b"IEND", b""))


FRAME = (58, 42, 26)       # dark wood
MATTE = (242, 235, 221)    # cream matte
PHOTO = (62, 90, 110)      # blue-grey photo
SPLASH_BG = (15, 15, 15)   # near-black wall


def frame_motif(width, height):
    """Pixel function that draws frame > matte > photo, concentric."""
    frame_w = min(width, height) // 14
    matte_w = frame_w + min(width, height) // 18

    def pixel(x, y):
        if x < frame_w or x >= width - frame_w or y < frame_w or y >= height - frame_w:
            return FRAME
        if x < matte_w or x >= width - matte_w or y < matte_w or y >= height - matte_w:
            return MATTE
        return PHOTO

    return pixel


def centered_motif(canvas_w, canvas_h, motif_w, motif_h):
    inner = frame_motif(motif_w, motif_h)
    x0 = (canvas_w - motif_w) // 2
    y0 = (canvas_h - motif_h) // 2

    def pixel(x, y):
        lx = x - x0
        ly = y - y0
        if 0 <= lx < motif_w and 0 <= ly < motif_h:
            return inner(lx, ly)
        return SPLASH_BG

    return pixel


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..", "images")
    out_dir = os.path.normpath(out_dir)
    os.makedirs(out_dir, exist_ok=True)

    targets = [
        ("icon_focus_hd.png",  290,  218,  frame_motif(290, 218)),
        ("icon_focus_fhd.png", 336,  210,  frame_motif(336, 210)),
        ("splash_hd.png",      1280, 720,  centered_motif(1280, 720, 420, 280)),
        ("splash_fhd.png",     1920, 1080, centered_motif(1920, 1080, 620, 420)),
    ]

    for name, w, h, fn in targets:
        path = os.path.join(out_dir, name)
        write_png(path, w, h, fn)
        print(f"wrote {path} ({w}x{h})")


if __name__ == "__main__":
    main()
