#!/usr/bin/env python3
"""Compose App-Store-ready screenshots on branded caption canvases.

iPad (13-inch class, 2752x2064) from raw 11" captures (2388x1668):
  Reads  docs/screenshots/raw/IMG_*.PNG      (mapped in SHOTS)
  Writes docs/screenshots/appstore/NN_<slug>.png

iPhone (6.9-inch class, 2868x1320 landscape) from on-device landscape
captures (any resolution, e.g. 2622x1206 from an iPhone 17):
  Reads  docs/screenshots/raw-iphone/*.png|PNG — sorted by name, paired
         with IPHONE_SHOTS in order (drop exactly that many files)
  Writes docs/screenshots/appstore-iphone/NN_<slug>.png

Usage: python3 scripts/make_screenshots.py
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

IPHONE_RAW = ROOT / "docs/screenshots/raw-iphone"
IPHONE_OUT = ROOT / "docs/screenshots/appstore-iphone"
IPHONE_CANVAS = (2868, 1320)   # App Store 6.9-inch iPhone, landscape
IPHONE_SHOTS = [
    ("01_pocket", "The Amiga in your pocket",
     "Full classic Amiga power, now on iPhone"),
    ("02_controller", "Pair a controller and play",
     "Bluetooth gamepads with CD32 pad mode and autofire"),
    ("03_keyboard", "Every key of the real thing",
     "Virtual Amiga keyboard sized for iPhone"),
    ("04_menu", "Everything one tap away",
     "Disks, drives, machine and display — without leaving the Amiga"),
    ("05_joystick", "Touch controls when you need them",
     "Virtual joystick and keyboard overlays — or none at all"),
]

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


def compose(raw_path: Path, title: str, subtitle: str,
            canvas_size=CANVAS, caption_area=CAPTION_AREA) -> Image.Image:
    CANVAS = canvas_size
    CAPTION_AREA = caption_area
    k = canvas_size[1] / 2064          # scale captions for smaller canvases
    canvas = gradient(CANVAS).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    title_font = font(round(104 * k), bold=True)
    sub_font = font(round(56 * k))
    tw = draw.textlength(title, font=title_font)
    sw = draw.textlength(subtitle, font=sub_font)
    draw.text(((CANVAS[0] - tw) / 2, round(84 * k)), title, font=title_font,
              fill=(255, 255, 255))
    draw.text(((CANVAS[0] - sw) / 2, round(218 * k)), subtitle, font=sub_font,
              fill=(200, 200, 205))
    # accent underline
    line_w = round(160 * k)
    draw.rounded_rectangle(
        [(CANVAS[0] - line_w) / 2, round(306 * k),
         (CANVAS[0] + line_w) / 2, round(316 * k)],
        radius=5, fill=ACCENT)

    shot = Image.open(raw_path).convert("RGB")
    avail_h = CANVAS[1] - CAPTION_AREA - round(72 * k)
    scale = min(avail_h / shot.height, (CANVAS[0] - 240) / shot.width)
    shot = shot.resize((round(shot.width * scale), round(shot.height * scale)),
                       Image.LANCZOS)
    shot = rounded(shot, CORNER_RADIUS)

    x = (CANVAS[0] - shot.width) // 2
    y = CAPTION_AREA + round(24 * k)

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

    # iPhone 6.9" set: raws paired with IPHONE_SHOTS by sorted filename.
    raws = sorted(IPHONE_RAW.glob("*.png")) + sorted(IPHONE_RAW.glob("*.PNG")) \
        if IPHONE_RAW.exists() else []
    if not raws:
        print(f"iPhone: no raws in {IPHONE_RAW.relative_to(ROOT)} — skipped")
        return
    if len(raws) != len(IPHONE_SHOTS):
        print(f"iPhone: {len(raws)} raws but {len(IPHONE_SHOTS)} captions — "
              "pairing in sorted order, extras ignored")
    IPHONE_OUT.mkdir(parents=True, exist_ok=True)
    caption_area = round(340 * IPHONE_CANVAS[1] / 2064)
    for raw, (slug, title, subtitle) in zip(raws, IPHONE_SHOTS):
        img = compose(raw, title, subtitle,
                      canvas_size=IPHONE_CANVAS, caption_area=caption_area)
        assert img.size == IPHONE_CANVAS
        dest = IPHONE_OUT / f"{slug}.png"
        img.save(dest)
        print(f"wrote {dest.relative_to(ROOT)} {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main()
