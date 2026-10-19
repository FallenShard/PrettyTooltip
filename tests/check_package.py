"""Smoke-test a BigWigs package: python tests/check_package.py [zip-or-directory].

Checks the actual ZIP, then loads its Lua files in TOC order in the existing
WoW harness for every supported locale. It never extracts or changes the ZIP.
This checks packaging and simulated startup, not the game's taint engine.
"""

import re
import sys
from argparse import ArgumentParser
from pathlib import Path, PurePosixPath
from zipfile import BadZipFile, ZipFile

from lupa.lua51 import LuaError

import run as regression

ROOT = Path(__file__).resolve().parent.parent
ADDON = "PrettyTooltip"
TOC = f"{ADDON}.toc"
LOCALES = ("enUS", "deDE", "esES", "esMX", "frFR", "koKR", "ptBR", "ptPT", "ruRU", "zhCN", "zhTW")


def toc_entries(text: str, *, source: bool = False) -> list[str]:
    """Keep load entries and locale conditions; omit source-only debug blocks."""
    entries = []
    debug = False
    for line in text.splitlines():
        line = line.strip()
        if source and line == "#@debug@":
            debug = True
        elif source and line == "#@end-debug@":
            debug = False
        elif not debug and line and not line.startswith("#"):
            entries.append(line.replace("\\", "/"))
    return entries


def entry_path(entry: str) -> str:
    return entry.split(" [", 1)[0]


def locale_files(entries: list[str], locale: str) -> list[str]:
    files = []
    for entry in entries:
        match = re.fullmatch(r"(.+?)\s+\[AllowLoadTextLocale\s+([^\]]+)\]", entry)
        if match:
            if locale not in re.split(r"[,\s]+", match[2].strip()):
                continue
            entry = match[1]
        if "[" in entry or not entry.endswith(".lua"):
            raise ValueError(f"unsupported TOC entry: {entry}")
        files.append(entry)
    return files


def check_contents(archive: ZipFile) -> tuple[list[str], dict[str, str]]:
    names = archive.namelist()
    if len(names) != len(set(names)):
        raise ValueError("duplicate ZIP entries")
    for name in names:
        path = PurePosixPath(name)
        if (not path.parts or "\\" in name or path.is_absolute()
                or ".." in path.parts or path.parts[0] != ADDON):
            raise ValueError(f"unexpected archive path: {name}")
    damaged = archive.testzip()
    if damaged:
        raise ValueError(f"damaged ZIP entry: {damaged}")
    files = {name[len(ADDON) + 1:] for name in names if not name.endswith("/")}
    if TOC not in files:
        raise ValueError(f"missing {TOC}")
    toc = archive.read(f"{ADDON}/{TOC}").decode("utf-8-sig")
    source_toc = (ROOT / TOC).read_text(encoding="utf-8-sig")
    entries = toc_entries(toc)
    if entries != toc_entries(source_toc, source=True):
        raise ValueError("packaged TOC load order or locale conditions differ from the source release entries")
    for field in ("Interface", "Version", "X-Curse-Project-ID"):
        pattern = rf"^## {field}:\s*(.+)$"
        actual = re.search(pattern, toc, re.MULTILINE)
        expected = re.search(pattern, source_toc, re.MULTILINE)
        if not actual or not expected or actual[1].strip() != expected[1].strip():
            raise ValueError(f"packaged {field} differs from the source TOC")
    required = {TOC, "LICENSE"} | {entry_path(entry) for entry in entries}
    required |= {path.relative_to(ROOT).as_posix() for path in (ROOT / "art").glob("*.tga")}
    missing = sorted(required - files)
    if missing:
        raise ValueError("missing packaged files (case-sensitive): " + ", ".join(missing))
    for name in sorted(files):
        path = PurePosixPath(name)
        if (any(part.startswith(".") for part in path.parts)
                or path.parts[0] in {"tests", "tools", "output", "art_unused", "docs"}
                or path.suffix in {".py", ".pyc"} or path.name == "README.md"
                or name == "UI/Capture.lua"):
            raise ValueError(f"development file leaked into package: {name}")
    sources = {name: archive.read(f"{ADDON}/{name}").decode("utf-8-sig")
               for name in sorted(files) if name.endswith(".lua")}
    return entries, sources


def check_startup(entries: list[str], sources: dict[str, str]) -> None:
    lua, _, _ = regression.new_runtime()
    compile_lua = lua.eval("""function(source, name)
        local chunk, problem = loadstring(source, '@' .. name)
        return chunk ~= nil, problem
    end""")
    for name, source in sources.items():
        valid, problem = compile_lua(source, name)
        if not valid:
            raise ValueError(f"packaged Lua syntax error: {problem}")
    for locale in LOCALES:
        lua, load, harness = regression.new_runtime()
        startup = lua.eval("""function(files, sources, makeWorld, enums, locale)
            local world = makeWorld({ client = { locale = locale } }, enums, function() end)
            local ns = {}
            for _, file in ipairs(files) do
                assert(loadstring(sources[file], '@' .. file))('PrettyTooltip', ns)
            end
            PrettyTooltipDB = {}
            world.fireEvent('ADDON_LOADED', 'PrettyTooltip')
            assert(ns.Locale.supported, 'locale not enabled')
            assert(ns.Locale.features.coefficients, 'localized coefficients not enabled')
            assert(type(SlashCmdList.PRETTYTOOLTIP) == 'function', 'startup did not register commands')
            assert(ns.TooltipTypes[enums.TooltipDataType.Item], 'item type not registered')
            assert(ns.TooltipTypes[enums.TooltipDataType.Spell], 'spell type not registered')
        end""")
        files = regression.lua_table(lua, dict(enumerate(locale_files(entries, locale), 1)))
        try:
            startup(files, regression.lua_table(lua, sources), harness["wow"], regression.default_enums(load), locale)
        except LuaError as error:
            raise ValueError(f"packaged startup failed for {locale}: {error}") from error
        print(f"ok packaged startup {locale}")


def main() -> None:
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("package", nargs="?", type=Path, default=ROOT / ".release")
    args = parser.parse_args()
    paths = sorted(args.package.glob("*.zip")) if args.package.is_dir() else [args.package]
    if len(paths) != 1:
        parser.exit(1, f"FAIL package: expected exactly one ZIP in {args.package}, found {len(paths)}\n")
    try:
        with ZipFile(paths[0]) as archive:
            entries, sources = check_contents(archive)
        check_startup(entries, sources)
    except (OSError, ValueError, BadZipFile, LuaError) as error:
        parser.exit(1, f"FAIL package: {error}\n")
    print(f"ok package {paths[0].name}: contents, Lua syntax, startup in {len(LOCALES)} locales")


if __name__ == "__main__":
    main()
