"""Generate art/faction-alliance.tga and art/faction-horde.tga, the faction
watermarks on player panels, from emblem images of any size and color.

Each emblem is cropped to its visible shape, scaled so its longer side fills
the canvas less the padding, centered, and made a white silhouette that keeps
the source's edge alpha; the addon tints it. Both come out the same size, so
the addon places either one the same way:
python make_faction.py alliance.png faction-alliance.tga
python make_faction.py horde.png faction-horde.tga
"""

from argparse import ArgumentParser
from pathlib import Path

from PIL import Image

SIZE = 256
PADDING = 16


def render(source: Image.Image, size: int, padding: int) -> Image.Image:
    alpha = source.convert("RGBA").getchannel("A")
    alpha = alpha.crop(alpha.getbbox())
    scale = (size - 2 * padding) / max(alpha.size)
    fitted = alpha.resize((round(alpha.width * scale), round(alpha.height * scale)),
                          Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    mask.paste(fitted, ((size - fitted.width) // 2, (size - fitted.height) // 2))
    image = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    image.putalpha(mask)
    return image


def main() -> None:
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="emblem image with a transparent background")
    parser.add_argument("out", type=Path, help="TGA to write")
    parser.add_argument("--size", type=int, default=SIZE)
    parser.add_argument("--padding", type=int, default=PADDING)
    args = parser.parse_args()
    render(Image.open(args.source), args.size, args.padding).save(args.out)


if __name__ == "__main__":
    main()
