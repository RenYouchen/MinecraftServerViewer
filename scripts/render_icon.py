#!/usr/bin/env python3
"""Render the app icon and write the macOS AppIcon set.

Usage: scripts/render_icon.py [rack|pulse]   (default: rack)

The pixel maps, colors and Park–Miller color sequence mirror the designs on
the "Minecraft Server Viewer App Icon" canvas, so the output matches it exactly.
Requires Pillow.
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "MinecraftServerViewer/Assets.xcassets/AppIcon.appiconset"
SS = 4  # supersampling for smooth corners and shadow
S = 1024 * SS


class Random:
    """Same sequence as the canvas JS: s = s * 16807 % (2^31 - 1)."""

    def __init__(self, seed):
        self.s = seed

    def pick(self, options):
        self.s = (self.s * 16807) % 2147483647
        return options[math.floor(self.s / 2147483647 * len(options))]


def rack():
    """Design B: stone server rack with a grass top and status lights."""
    rng = Random(21)
    rows = [
        "................",
        "..GGGGGGGGGGGG..",
        "..GgGGgGGGgGgG..",
        "..KKKKKKKKKKKK..",
        "..KSSSSSSSSSSK..",
        "..KSLLSdddddSK..",
        "..KSSSSSSSSSSK..",
        "..KKKKKKKKKKKK..",
        "..KSSSSSSSSSSK..",
        "..KSLLSdddddSK..",
        "..KSSSSSSSSSSK..",
        "..KKKKKKKKKKKK..",
        "..KSSSSSSSSSSK..",
        "..KSOLSdddddSK..",
        "..KSSSSSSSSSSK..",
        "..KKKKKKKKKKKK..",
    ]
    palette = {
        ".": lambda: None,
        "G": lambda: rng.pick(["#5D9E3A", "#6FB343", "#64A93E"]),
        "g": lambda: "#4F8A31",
        "K": lambda: "#3A3F47",
        "S": lambda: rng.pick(["#8E8E8E", "#7D7D7D", "#9C9C9C", "#868686"]),
        "L": lambda: "#5BE36B",
        "O": lambda: "#F5A524",
        "d": lambda: "#22262D",
    }
    return "#16212B", [palette[ch]() for row in rows for ch in row]


def pulse():
    """Design C: monitor showing a latency chart, on a grass block."""
    rng = Random(33)
    heights = [2, 3, 2, 4, 3, 7, 3, 3, 2, 3]
    pixels = []
    for y in range(16):
        for x in range(16):
            c = None
            if 2 <= x <= 13 and 2 <= y <= 10:
                c = "#0E1A12"
                bar = x - 3
                if 0 <= bar < len(heights) and y > 10 - heights[bar]:
                    c = "#F5A524" if heights[bar] >= 6 else "#5BE36B"
            elif 1 <= x <= 14 and 1 <= y <= 11:
                c = rng.pick(["#C9CED6", "#BCC2CB", "#D3D8DF"])
            elif y == 12 and x in (7, 8):
                c = "#9AA1AB"
            elif y == 13 and 3 <= x <= 12:
                c = rng.pick(["#5D9E3A", "#6FB343", "#4F8A31"])
            elif y >= 14 and 3 <= x <= 12:
                c = rng.pick(["#8A5A3B", "#7A4E33", "#6B4429"])
            pixels.append(c)
    return "#5B8FD9", pixels


DESIGNS = {"rack": rack, "pulse": pulse}


def rgba(hex_color, alpha=255):
    h = hex_color.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), alpha)


def px(v):
    return v * SS


def render(ground, pixels):
    body = (px(100), px(100), px(924), px(924))
    radius = px(185)

    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle(body, radius, fill=255)

    # Outer shadow: 0 12px 28px rgba(0,0,0,.32)
    shadow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (body[0], body[1] + px(12), body[2], body[3] + px(12)), radius, fill=int(255 * 0.32)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(px(14)))
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    canvas.paste((0, 0, 0, 255), (0, 0), shadow)

    inner = Image.new("RGBA", (S, S), rgba(ground))
    art_x, art_y, cell = 100 + 124, 100 + 112, 36

    def draw_art(img, dy, color=None):
        d = ImageDraw.Draw(img)
        for i, c in enumerate(pixels):
            if c is None:
                continue
            x0, y0 = px(art_x + (i % 16) * cell), px(art_y + (i // 16) * cell + dy)
            d.rectangle((x0, y0, x0 + px(cell) - 1, y0 + px(cell) - 1), fill=color or rgba(c))

    # drop-shadow(0 18px 0 rgba(0,0,0,.3))
    shade = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_art(shade, 18, (0, 0, 0, int(255 * 0.3)))
    inner = Image.alpha_composite(inner, shade)
    draw_art(inner, 0)

    # Inset 2px white at 7%
    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(ring).rounded_rectangle(body, radius, outline=(255, 255, 255, int(255 * 0.07)), width=px(2))
    inner = Image.alpha_composite(inner, ring)
    canvas.paste(inner, (0, 0), mask)

    return canvas.resize((1024, 1024), Image.LANCZOS)


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "rack"
    if name not in DESIGNS:
        sys.exit(f"Unknown design {name!r}; choose from: {', '.join(DESIGNS)}")
    master = render(*DESIGNS[name]())

    images = []
    for pt in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            size = pt * scale
            filename = f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"
            img = master if size == 1024 else master.resize((size, size), Image.LANCZOS)
            img.save(OUT / filename)
            images.append({"filename": filename, "idiom": "mac", "scale": f"{scale}x", "size": f"{pt}x{pt}"})
    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (OUT / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print(f"Wrote {len(images)} icons ({name}) to {OUT}")


if __name__ == "__main__":
    main()
