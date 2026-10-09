"""Generate the leading markers for magical effects on items.

marker-sword.tga marks a chance on hit, and marker-sparkle.tga an enchant:
32 x 32 white shapes, lit from the top left, which the addon tints. They are
drawn at eight times the size and scaled down, for smooth edges at the
11 px they are shown at.
"""

import math
from argparse import ArgumentParser
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 32
SCALE = 8
CANVAS = SIZE * SCALE


def rotate(points, degrees, center):
    angle = math.radians(degrees)
    cos, sin = math.cos(angle), math.sin(angle)
    cx, cy = center
    return [(cx + x * cos - y * sin, cy + x * sin + y * cos) for x, y in points]


def sword() -> Image.Image:
    """A sword pointing up and to the right: blade, crossguard, grip, pommel."""
    mask = Image.new("L", (CANVAS, CANVAS))
    draw = ImageDraw.Draw(mask)
    center = (CANVAS / 2, CANVAS / 2)
    # Drawn pointing up around the origin, then turned 45 degrees.
    blade = [(0, -150), (19, -112), (19, 36), (-19, 36), (-19, -112)]
    guard = [(-58, 36), (58, 36), (58, 64), (-58, 64)]
    grip = [(-14, 64), (14, 64), (14, 116), (-14, 116)]
    for shape in (blade, guard, grip):
        draw.polygon(rotate(shape, 45, center), fill=255)
    pommel = rotate([(0, 136)], 45, center)[0]
    draw.ellipse((pommel[0] - 22, pommel[1] - 22, pommel[0] + 22, pommel[1] + 22), fill=255)
    return mask


def star(draw, cx, cy, outer, inner):
    """A four-pointed star, its points up, down, left, and right."""
    points = []
    for index in range(8):
        radius = outer if index % 2 == 0 else inner
        angle = math.radians(index * 45 - 90)
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    draw.polygon(points, fill=255)


def sparkle() -> Image.Image:
    """A large star and a small one."""
    mask = Image.new("L", (CANVAS, CANVAS))
    draw = ImageDraw.Draw(mask)
    star(draw, 108, 144, 108, 32)
    star(draw, 204, 60, 52, 18)
    return mask


def shade(mask: Image.Image) -> Image.Image:
    """White lit from the top left, down to 70 percent at the bottom right."""
    light = Image.new("L", (CANVAS, CANVAS))
    pixels = light.load()
    for y in range(CANVAS):
        for x in range(CANVAS):
            pixels[x, y] = round(255 * (1.0 - 0.3 * (x + y) / (2 * CANVAS)))
    image = Image.merge("RGBA", (light, light, light, mask))
    return image.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    for name, mask in (("marker-sword.tga", sword()), ("marker-sparkle.tga", sparkle())):
        target = args.out_dir / name
        shade(mask).save(target)
        print(f"Wrote {target}")


if __name__ == "__main__":
    main()
