"""Composes the README cover art from an in-game shot of Halcyon Tower.

    python3 tools/make_cover.py SHOTS_DIR docs/store

SHOTS_DIR is where tools/store_shots.gd saved its PNGs. Needs Pillow. Writes
cover.jpg (1920x1080 key art) and header.jpg (a wide banner for the top of the README).
"""
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
TITLE_FONT = "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf"
BODY_FONT = "/usr/share/fonts/opentype/inter/InterDisplay-SemiBold.otf"
MONO_FONT = str(ROOT / "assets/art/fonts/CourierPrime-Regular.ttf")
PHOSPHOR = (102, 255, 153)
OFF_WHITE = (236, 232, 222)


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.truetype("DejaVuSans-Bold.ttf", size)


def shade(img, strength):
    """Darkens the left side (where the words go) and the edges."""
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    for x in range(w):
        t = max(0.0, 1.0 - x / (w * 0.62))
        d.line([(x, 0), (x, h)], fill=int(255 * strength * t))
    vignette = Image.new("L", (w, h), 0)
    ImageDraw.Draw(vignette).ellipse([-w * 0.25, -h * 0.35, w * 1.25, h * 1.35], fill=255)
    vignette = vignette.filter(ImageFilter.GaussianBlur(h * 0.12))
    edge = Image.eval(vignette, lambda v: int((255 - v) * 0.85))
    black = Image.new("RGB", (w, h), (4, 5, 8))
    img = Image.composite(black, img, mask)
    return Image.composite(black, img, edge)


def glow_text(base, xy, text, fnt, fill, glow, radius):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(xy, text, font=fnt, fill=glow + (200,))
    layer = layer.filter(ImageFilter.GaussianBlur(radius))
    base.alpha_composite(layer)
    ImageDraw.Draw(base).text(xy, text, font=fnt, fill=fill + (255,))


def tracked(draw, xy, text, fnt, fill, tracking):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=fnt, fill=fill)
        x += draw.textlength(ch, font=fnt) + tracking
    return x


def compose(shot, size, scale):
    w, h = size
    src = Image.open(shot).convert("RGB")
    # Fill the frame, then slide the tower right to leave night sky for the words.
    k = max(w / src.width, h / src.height)
    src = src.resize((int(src.width * k), int(src.height * k)), Image.LANCZOS)
    sky = Image.new("RGB", (w, h), src.getpixel((4, 4)))
    stars = random.Random(1997)
    sd = ImageDraw.Draw(sky)
    for _ in range(w * h // 9000):
        sx, sy, v = stars.randrange(w), stars.randrange(h), stars.randrange(90, 220)
        sd.point((sx, sy), fill=(v, v, v))
    shift = int(w * 0.24)
    top = (src.height - h) // 2
    sky.paste(src.crop((0, top, w - shift, top + h)), (shift, 0))
    img = shade(sky, 0.95).convert("RGBA")

    s = scale
    x = int(110 * s)
    title = font(TITLE_FONT, int(168 * s))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    y_title = int(h * 0.5 - 190 * s)
    tracked(ld, (x, y_title), "NULL", title, OFF_WHITE + (255,), 6 * s)
    tracked(ld, (x, y_title + int(150 * s)), "& VOID", title, OFF_WHITE + (255,), 6 * s)
    shadow = layer.filter(ImageFilter.GaussianBlur(18 * s))
    img.alpha_composite(Image.eval(shadow, lambda v: v // 2))
    img.alpha_composite(layer)

    mono = font(MONO_FONT, int(38 * s))
    y = y_title + int(345 * s)
    glow_text(img, (x + 4, y), "> SELECT * FROM exits;", mono, PHOSPHOR, PHOSPHOR, 6 * s)
    glow_text(img, (x + 4, y + int(48 * s)), "(0 rows)", mono, (70, 190, 110), PHOSPHOR, 6 * s)

    body = font(BODY_FONT, int(30 * s))
    d = ImageDraw.Draw(img)
    tracked(d, (x + 4, y + int(132 * s)), "CO-OP HORROR ESCAPE  ·  1–6 PLAYERS  ·  LEARN REAL SQL", body, (190, 186, 176, 255), 2 * s)
    return img.convert("RGB")


def main():
    shots = Path(sys.argv[1])
    out = Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    compose(shots / "cover_tower_up.png", (1920, 1080), 1.0).save(out / "cover.jpg", quality=88)
    compose(shots / "cover_tower_up.png", (1840, 690), 0.78).save(out / "header.jpg", quality=88)


if __name__ == "__main__":
    main()
