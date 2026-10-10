"""Run PrettyTooltip's tests outside the game.

Every fixture in tests/fixtures (a tooltip captured with /ptip capture) is run
through the addon as the game would, in Lua 5.1, and the model its reader
makes and what its renderer draws are compared against the expected outputs in
tests/outputs. Every file in tests/unit holds checks against parts of the addon
loaded on their own.

python tests/run.py              run everything
python tests/run.py -k frost     only tests whose name holds "frost"
python tests/run.py --update     accept the current output as the expected
python tests/run.py --notes      also list what each fixture lacked an answer for
python tests/run.py --coverage   also report which lines and functions the tests ran
python tests/run.py --profile    also count the frame calls each fixture's read and render make
"""

import difflib
import re
import sys
from argparse import ArgumentParser
from pathlib import Path

try:
    from lupa import lua51
except ImportError:
    sys.exit("The tests need lupa, a Lua runtime for Python: pip install -r tests/requirements.txt")

TESTS = Path(__file__).resolve().parent
ROOT = TESTS.parent
HARNESS = TESTS / "harness"
FIXTURES = TESTS / "fixtures"
OUTPUTS = TESTS / "outputs"
UNIT = TESTS / "unit"

# Lines run by any test, by file, while --coverage is given.
COVERAGE: dict[str, set[int]] | None = None


def addon_files() -> list[str]:
    """The addon's Lua files, in the order its .toc loads them."""
    files = []
    for line in (ROOT / "PrettyTooltip.toc").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and line.endswith(".lua"):
            files.append(line.replace("\\", "/"))
    return files


def new_runtime():
    """A fresh Lua 5.1 with the harness loaded, so no test sees another's state."""
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    load = lua.eval("function(source, name) return assert(loadstring(source, '@' .. name))() end")
    harness = {name: load((HARNESS / f"{name}.lua").read_text(encoding="utf-8"), f"harness/{name}.lua")
               for name in ("serialize", "wow", "main")}
    if COVERAGE is not None:
        harness["hits"] = lua.table()
        harness["main"].track(harness["hits"])
    return lua, load, harness


def collect_coverage(harness) -> None:
    if COVERAGE is None:
        return
    for source, lines in harness["hits"].items():
        COVERAGE.setdefault(source.lstrip("@"), set()).update(int(line) for line in lines.keys())


def lua_table(lua, mapping):
    table = lua.table()
    for key, value in mapping.items():
        table[key] = value
    return table


def sources_table(lua, files):
    return lua_table(lua, {name: (ROOT / name).read_text(encoding="utf-8") for name in files})


def default_enums(load):
    path = HARNESS / "enums.lua"
    if not path.exists():
        return None
    return load(path.read_text(encoding="utf-8"), "harness/enums.lua")


def show_diff(expected: str, got: str, name: str) -> None:
    diff = difflib.unified_diff(expected.splitlines(), got.splitlines(), f"outputs/{name}.txt", "now",
                                lineterm="", n=2)
    for line in diff:
        print("    " + line)


def run_fixture(path: Path, files, update: bool, show_notes: bool, profile: bool = False) -> bool:
    name = path.stem
    lua, load, harness = new_runtime()
    fixture = load(path.read_text(encoding="utf-8"), f"fixtures/{path.name}")
    enums = fixture.enums or default_enums(load)
    if enums is None:
        print(f"FAIL {name}: no enums; capture it again with the current /ptip capture, then import it")
        return False
    try:
        options = lua_table(lua, {"profile": profile})
        text, notes, profile_text = harness["main"].fixture(
            fixture, enums, lua_table(lua, dict(enumerate(files, 1))), sources_table(lua, files),
            harness["serialize"], harness["wow"], options)
    except Exception as error:  # A Lua error, with its traceback.
        print(f"FAIL {name}: {error}")
        return False
    collect_coverage(harness)
    notes = list(notes.values())
    expected_path = OUTPUTS / f"{name}.txt"
    if update or not expected_path.exists():
        expected_path.parent.mkdir(exist_ok=True)
        expected_path.write_text(text, encoding="utf-8", newline="\n")
        print(f"{'updated' if update else 'new'} {name}")
        ok = True
    else:
        expected = expected_path.read_text(encoding="utf-8")
        ok = expected == text
        print(f"{'ok' if ok else 'FAIL'} {name}")
        if not ok:
            show_diff(expected, text, name)
    if show_notes or not ok:
        for note in notes:
            print(f"    note {note}")
    if profile and profile_text:
        print("    " + profile_text.replace("\n", "\n    "))
    return ok


def run_unit(path: Path, files, show_notes: bool) -> bool:
    lua, load, harness = new_runtime()
    try:
        results, notes = harness["main"].unit(path.read_text(encoding="utf-8"), f"unit/{path.name}",
                                                sources_table(lua, files), harness["serialize"], harness["wow"])
    except Exception as error:
        print(f"FAIL unit/{path.stem}: {error}")
        return False
    collect_coverage(harness)
    all_ok = True
    for result in results.values():
        if result.ok:
            continue
        all_ok = False
        print(f"FAIL unit/{path.stem}: {result.name}")
        print("    expected: " + result.expected.replace("\n", "\n              "))
        print("    got:      " + result.got.replace("\n", "\n              "))
    if all_ok:
        print(f"ok unit/{path.stem} ({len(results)} checks)")
    if show_notes:
        for note in notes.values():
            print(f"    note {note}")
    return all_ok


# Lines that hold no statement of their own: blank, comments, and the closing
# words and brackets of blocks and tables.
NOT_CODE = re.compile(r"^\s*(--.*)?$|^\s*(end|else|do|then|repeat)?[\s,;)}\]]*(--.*)?$")
DEFINITION = re.compile(r"^(?:local\s+)?function\s+([\w.:]+)|^local\s+(\w+)\s*=\s*function\b")


def report_coverage(files) -> None:
    """Each file's share of code lines the tests ran, and its top-level
    functions no test entered. Code lines are counted from the text, so the
    share is close, not exact."""
    print("\nCoverage (code lines run by any test):")
    total_run = total_code = 0
    untouched = []
    for name in files:
        lines = (ROOT / name).read_text(encoding="utf-8").splitlines()
        hit = COVERAGE.get(name, set())
        code = [number for number, text in enumerate(lines, 1) if not NOT_CODE.match(text)]
        run = [number for number in code if number in hit]
        total_run += len(run)
        total_code += len(code)
        print(f"  {name:32} {100 * len(run) / max(1, len(code)):5.1f}%  ({len(run)} of {len(code)})")
        # A top-level function runs to the next one; it was entered when any
        # line after its first ran.
        starts = [(number, match.group(1) or match.group(2)) for number, text in enumerate(lines, 1)
                  if (match := DEFINITION.match(text))]
        for index, (start, function) in enumerate(starts):
            stop = starts[index + 1][0] if index + 1 < len(starts) else len(lines) + 1
            body = [number for number in code if start < number < stop]
            if body and not any(number in hit for number in body):
                untouched.append(f"{name}:{start} {function} ({len(body)} lines)")
    print(f"  {'all':32} {100 * total_run / max(1, total_code):5.1f}%  ({total_run} of {total_code})")
    if untouched:
        print("\nTop-level functions no test entered:")
        for line in untouched:
            print("  " + line)


def main() -> None:
    parser = ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("-k", dest="pattern", default="", help="only tests whose name holds this")
    parser.add_argument("--update", action="store_true", help="accept the current output as the expected")
    parser.add_argument("--notes", action="store_true", help="list what each fixture lacked an answer for")
    parser.add_argument("--coverage", action="store_true", help="report which lines and functions the tests ran")
    parser.add_argument("--profile", action="store_true", help="count the frame calls each read and render make")
    args = parser.parse_args()
    global COVERAGE
    if args.coverage:
        COVERAGE = {}

    files = addon_files()
    passed = failed = 0
    for path in sorted(UNIT.glob("*.lua")):
        if args.pattern in path.stem:
            if run_unit(path, files, args.notes):
                passed += 1
            else:
                failed += 1
    for path in sorted(FIXTURES.glob("*.lua")):
        if args.pattern in path.stem:
            if run_fixture(path, files, args.update, args.notes, args.profile):
                passed += 1
            else:
                failed += 1
    print(f"\n{passed} passed, {failed} failed")
    if COVERAGE is not None:
        report_coverage(files)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
