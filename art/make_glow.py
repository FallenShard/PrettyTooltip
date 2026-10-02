"""Generate art/glow.tga, the soft halo drawn behind the item panel.

--size, --margin, --power, and --out make the falloff at other sizes and
softnesses, such as the feathered header and footer bands:
python make_glow.py --size 48 --margin 16 --power 1 --out band.tga
"""

from argparse import ArgumentParser
from pathlib import Path

from PIL import Image

SIZE = 64
# Falloff width in texels; the addon's slice margins must match.
MARGIN = 24
# The smoothstep falloff is raised to this power: 2 keeps the halo faint near
# its edge, 1 gives the bands an even ease in and out.
POWER = 2


def render(size: int, margin: int, power: float) -> Image.Image:
    image = Image.new("RGBA", (size, size))
    low, high = margin, size - margin
    for y in range(size):
        for x in range(size):
            cx, cy = x + 0.5, y + 0.5
            dx = max(low - cx, 0.0, cx - high)
            dy = max(low - cy, 0.0, cy - high)
            t = min(1.0, (dx * dx + dy * dy) ** 0.5 / margin)
            falloff = 1.0 - t * t * (3.0 - 2.0 * t)
            image.putpixel((x, y), (255, 255, 255, round(255 * falloff ** power)))
    return image


def main() -> None:
    parser = ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--size", type=int, default=SIZE, help="width and height in texels")
    parser.add_argument("--margin", type=int, default=MARGIN, help="falloff width in texels")
    parser.add_argument("--power", type=float, default=POWER, help="falloff exponent")
    parser.add_argument("--out", type=Path, default=Path(__file__).with_name("glow.tga"))
    args = parser.parse_args()
    render(args.size, args.margin, args.power).save(args.out)


if __name__ == "__main__":
    main()
