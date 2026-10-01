"""Generate art/logo.tga, the addon list icon: a miniature of the item panel."""

from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 64
# Drawn large and scaled down so edges stay smooth at the list's ~20 px.
SCALE = 8

GOLD = (214, 170, 92, 255)
GOLD_DARK = (150, 112, 58, 255)
EPIC_TOP = (138, 82, 214)
EPIC_BOTTOM = (62, 34, 104)
CARD_TOP = (30, 24, 38)
CARD_BOTTOM = (12, 10, 16)
TITLE = (238, 226, 255, 255)
# The stat colors from PrettyTooltip.lua: primary teal, attack orange.
TEAL = (12, 210, 157, 255)
ORANGE = (255, 131, 87, 255)


def px(value: float) -> int:
    return round(value * SCALE)


def box(x0: float, y0: float, x1: float, y1: float) -> tuple[int, int, int, int]:
    return px(x0), px(y0), px(x1), px(y1)


def diamond(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill) -> None:
    draw.polygon([(px(cx), px(cy - r)), (px(cx + r), px(cy)),
                  (px(cx), px(cy + r)), (px(cx - r), px(cy))], fill=fill)


def gradient(top, bottom, height: int) -> Image.Image:
    image = Image.new("RGBA", (1, height))
    for y in range(height):
        t = y / max(1, height - 1)
        image.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
    return image


def main() -> None:
    big = SIZE * SCALE
    image = Image.new("RGBA", (big, big))

    # The card: gold rim, dark body, rounded like the panel's backdrop.
    mask = Image.new("L", (big, big))
    ImageDraw.Draw(mask).rounded_rectangle(box(2, 2, 62, 62), radius=px(9), fill=255)
    body = gradient(CARD_TOP, CARD_BOTTOM, big).resize((big, big))
    header = gradient(EPIC_TOP, EPIC_BOTTOM, px(22)).resize((big, px(22)))
    body.paste(header, (0, px(2)))
    rim = Image.new("RGBA", (big, big), GOLD)
    inner = Image.new("L", (big, big))
    ImageDraw.Draw(inner).rounded_rectangle(box(4.5, 4.5, 59.5, 59.5), radius=px(7), fill=255)
    card = Image.composite(body, rim, inner)
    image.paste(card, (0, 0), mask)

    draw = ImageDraw.Draw(image)
    # Title text, as a bar.
    draw.rounded_rectangle(box(11, 11, 46, 16), radius=px(2.5), fill=TITLE)
    # The ornamented divider.
    draw.rectangle(box(9, 29.4, 25, 30.6), fill=GOLD_DARK)
    draw.rectangle(box(39, 29.4, 55, 30.6), fill=GOLD_DARK)
    diamond(draw, 32, 30, 5, GOLD)
    # Two stat rows: marker, then the stat in its category color.
    for y, color, end in ((41, TEAL, 50), (51, ORANGE, 42)):
        diamond(draw, 13.5, y, 3, GOLD)
        draw.rounded_rectangle(box(20, y - 2.5, end, y + 2.5), radius=px(2.5), fill=color)

    image.resize((SIZE, SIZE), Image.LANCZOS).save(Path(__file__).with_name("logo.tga"))


if __name__ == "__main__":
    main()
