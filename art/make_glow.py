"""Generate art/glow.tga, the soft halo drawn behind the item panel."""

from pathlib import Path

from PIL import Image

SIZE = 64
# Falloff width in texels; the addon's slice margins must match.
MARGIN = 24


def main() -> None:
    image = Image.new("RGBA", (SIZE, SIZE))
    low, high = MARGIN, SIZE - MARGIN
    for y in range(SIZE):
        for x in range(SIZE):
            cx, cy = x + 0.5, y + 0.5
            dx = max(low - cx, 0.0, cx - high)
            dy = max(low - cy, 0.0, cy - high)
            t = min(1.0, (dx * dx + dy * dy) ** 0.5 / MARGIN)
            falloff = 1.0 - t * t * (3.0 - 2.0 * t)
            image.putpixel((x, y), (255, 255, 255, round(255 * falloff * falloff)))
    image.save(Path(__file__).with_name("glow.tga"))


if __name__ == "__main__":
    main()
