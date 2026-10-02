"""Copy PrettyTooltip's game files into a World of Warcraft AddOns folder."""

from argparse import ArgumentParser
from pathlib import Path
from shutil import copy2


DEFAULT_ADDONS_DIR = Path(
    r"D:\Programs\World of Warcraft\_classic_beta_\Interface\AddOns"
)
GAME_FILES = (
    "PrettyTooltip.toc",
    "PrettyTooltipOptions.lua",
    "PrettyTooltip.lua",
    "PrettyTooltipLayout.lua",
    "PrettyTooltipSpell.lua",
    "PrettyTooltipObject.lua",
    "PrettyTooltipEditor.lua",
    "PrettyTooltipCursor.lua",
    "art/band.tga",
    "art/glow.tga",
    "art/logo.tga",
    "art/stat-marker.tga",
)


def main() -> None:
    parser = ArgumentParser(description=__doc__)
    parser.add_argument(
        "--addons-dir",
        type=Path,
        default=DEFAULT_ADDONS_DIR,
        help="World of Warcraft Interface/AddOns folder",
    )
    args = parser.parse_args()

    source = Path(__file__).resolve().parent
    if not args.addons_dir.is_dir():
        parser.error(f"AddOns folder does not exist: {args.addons_dir}")

    destination = args.addons_dir / "PrettyTooltip"
    destination.mkdir(exist_ok=True)
    for name in GAME_FILES:
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        copy2(source / name, target)
        print(f"Installed {target}")


if __name__ == "__main__":
    main()
