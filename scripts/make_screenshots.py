#!/usr/bin/env python3
"""Compose App-Store-ready iPad screenshots (2752x2064, 13-inch class)
from raw 11-inch captures (2388x1668).

Raw shots cannot be uploaded directly: the 11" aspect (1.43:1) differs from
the required 13" canvas (4:3). Each capture is placed on a dark branded
canvas with a caption headline — also just nicer marketing.

Usage: python3 scripts/make_screenshots.py
Reads  docs/screenshots/raw/IMG_*.PNG
Writes docs/screenshots/appstore/NN_<slug>.png
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "docs/screenshots/raw"
OUT = ROOT / "docs/screenshots/appstore"

CANVAS = (2752, 2064)          # App Store 13-inch iPad, landscape
ACCENT = (215, 40, 40)         # Amigo red
BG_TOP = (24, 24, 27)
BG_BOTTOM = (14, 14, 16)
CAPTION_AREA = 340             # px reserved above the screenshot
CORNER_RADIUS = 36

SHOTS = [
    ("IMG_0016.PNG", "01_workbench", "Classic Amiga computing",
     "Full Workbench with RTG graphics — 68000 to 68060"),
    ("IMG_0020.PNG", "02_machine", "Build your dream Amiga",
     "CPU, chipset, RAM, RTG card and networking in one panel"),
    ("IMG_0019.PNG", "03_keyboard", "Every key of the real thing",
     "Virtual Amiga keyboard, plus hardware keyboards and mice"),
    ("IMG_0018.PNG", "04_configs", "Save your setups",
     "Switch machines with one tap"),
    ("IMG_0017.PNG", "05_menu", "Everything one tap away",
     "Disks, drives, machine and display — without leaving the Amiga"),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
        try:
            # Helvetica.ttc index 1 is bold
            index = 1 if (bold and path.endswith(".ttc")) else 0
            return ImageFont.truetype(path, size, index=index)
        except OSError:
            continue
    return ImageFont.load_default()


def gradient(size) -> Image.Image:
    w, h = size
    img = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        img.putpixel((0, y), tuple(
            round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM)))
    return img.resize((w, h))


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.width - 1, img.height - 1], radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def compose(raw_path: Path, title: str, subtitle: str) -> Image.Image:
    canvas = gradient(CANVAS).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    title_font = font(104, bold=True)
    sub_font = font(56)
    tw = draw.textlength(title, font=title_font)
    sw = draw.textlength(subtitle, font=sub_font)
    draw.text(((CANVAS[0] - tw) / 2, 84), title, font=title_font,
              fill=(255, 255, 255))
    draw.text(((CANVAS[0] - sw) / 2, 218), subtitle, font=sub_font,
              fill=(200, 200, 205))
    # accent underline
    line_w = 160
    draw.rounded_rectangle(
        [(CANVAS[0] - line_w) / 2, 306, (CANVAS[0] + line_w) / 2, 316],
        radius=5, fill=ACCENT)

    shot = Image.open(raw_path).convert("RGB")
    avail_h = CANVAS[1] - CAPTION_AREA - 72
    scale = min(avail_h / shot.height, (CANVAS[0] - 240) / shot.width)
    shot = shot.resize((round(shot.width * scale), round(shot.height * scale)),
                       Image.LANCZOS)
    shot = rounded(shot, CORNER_RADIUS)

    x = (CANVAS[0] - shot.width) // 2
    y = CAPTION_AREA + 24

    # soft shadow
    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x - 4, y + 10, x + shot.width + 4, y + shot.height + 26],
        radius=CORNER_RADIUS, fill=(0, 0, 0, 160))
    canvas = Image.alpha_composite(canvas, shadow.filter(
        ImageFilter.GaussianBlur(30)))
    canvas.alpha_composite(shot, (x, y))
    return canvas.convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for raw_name, slug, title, subtitle in SHOTS:
        raw = RAW / raw_name
        if not raw.exists():
            print(f"skip (missing): {raw}")
            continue
        img = compose(raw, title, subtitle)
        assert img.size == CANVAS
        dest = OUT / f"{slug}.png"
        img.save(dest)
        print(f"wrote {dest.relative_to(ROOT)} {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main()
