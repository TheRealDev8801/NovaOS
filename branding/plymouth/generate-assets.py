#!/usr/bin/env python3
"""Generate the NovaOS Plymouth theme assets.

Pure standard library — writes PNGs directly, so the build needs no Pillow,
ImageMagick or an SVG rasteriser. Run from anywhere:

    python3 branding/plymouth/generate-assets.py

Produces, inside branding/plymouth/nova-starlight/assets/:

    star.png   a soft radial blob, used both as a star point and (scaled up)
               as the nova glow behind the wordmark
    logo.png   the "NOVA OS" wordmark, with a cyan->violet gradient matching
               branding/nova-plasma/color-schemes/Nova.colors

Both are RGBA with straight alpha. The star relies on alpha falloff alone, so
the script can tint and fade it purely via SetOpacity().
"""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent / "nova-starlight" / "assets"

# Palette, matching branding/nova-plasma/color-schemes/Nova.colors
CYAN = (110, 231, 255)
VIOLET = (167, 139, 250)
TEXT = (232, 236, 248)


def _png(path: Path, width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> None:
    """Write RGBA pixels as an 8-bit PNG."""
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type 0 (None) for this scanline
        for x in range(width):
            raw.extend(pixels[y * width + x])

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def make_star(size: int = 128) -> None:
    """A soft radial blob: bright core, smooth falloff to transparent."""
    px: list[tuple[int, int, int, int]] = []
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / c  # 0 at centre, 1 at edge
            if d >= 1.0:
                px.append((0, 0, 0, 0))
                continue
            # smooth, slightly super-linear falloff for a soft dot
            a = (1.0 - d) ** 2.2
            # blend cyan core toward white at the very centre
            t = max(0.0, 1.0 - d * 1.6)
            r = int(CYAN[0] + (255 - CYAN[0]) * t)
            g = int(CYAN[1] + (255 - CYAN[1]) * t)
            b = int(CYAN[2] + (255 - CYAN[2]) * t)
            px.append((r, g, b, int(a * 255)))
    _png(OUT / "star.png", size, size, px)


# 5x7 glyphs for the letters used in "NOVA OS". Roomier than 3x5, and enough
# to read clearly at splash size without shipping a font.
GLYPHS = {
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}


def make_logo(text: str = "NOVA OS", scale: int = 12, gap: int = 1) -> None:
    """Render the wordmark with a horizontal cyan->violet gradient."""
    gw, gh = 5, 7
    cols = len(text) * (gw + gap) - gap
    width = cols * scale + scale * 4      # side padding
    height = gh * scale + scale * 4

    px: list[tuple[int, int, int, int]] = [(0, 0, 0, 0)] * (width * height)
    ox = scale * 2
    oy = scale * 2

    for ci, ch in enumerate(text):
        glyph = GLYPHS.get(ch, GLYPHS[" "])
        for gy in range(gh):
            for gx in range(gw):
                if glyph[gy][gx] != "1":
                    continue
                # gradient position across the whole wordmark
                t = ((ci * (gw + gap) + gx) / max(1, cols - 1))
                t = min(1.0, max(0.0, t))
                cr = int(CYAN[0] + (VIOLET[0] - CYAN[0]) * t)
                cg = int(CYAN[1] + (VIOLET[1] - CYAN[1]) * t)
                cb = int(CYAN[2] + (VIOLET[2] - CYAN[2]) * t)
                x0 = ox + (ci * (gw + gap) + gx) * scale
                y0 = oy + gy * scale
                for y in range(y0, y0 + scale):
                    for x in range(x0, x0 + scale):
                        px[y * width + x] = (cr, cg, cb, 255)

    _png(OUT / "logo.png", width, height, px)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    make_star()
    make_logo()
    for f in sorted(OUT.iterdir()):
        print(f"wrote {f.relative_to(OUT.parent.parent)} ({f.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
