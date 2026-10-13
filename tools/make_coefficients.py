"""Writes Data/SpellRanks.lua: every class spell rank's spell power
coefficients and the level it is learned at, by spell ID.

The numbers come from foreverchanges.pro's downrank calculator, which embeds
the Forever beta client's spell data (rank, spell ID, level, cast, and each
effect's coefficient) in its page; one page holds every class. Spells it has
only Classic data for are left out, as are physical abilities, which it does
not list. An effect over time gives its coefficient per tick; the table holds
the whole duration's, as the tooltip's amount covers it. EXTRA adds the
spells the calculator lacks, by hand.

python tools/make_coefficients.py            download if missing, then write
python tools/make_coefficients.py --refresh  download again
"""

import json
import re
import tempfile
import urllib.request
from argparse import ArgumentParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = Path(tempfile.gettempdir()) / "prettytooltip-coefficients"
CALCULATOR = "https://foreverchanges.pro/downrank-calculator?class=paladin&spell=holy-light"
CLASSES = ["priest", "druid", "paladin", "shaman", "mage", "warlock"]

# Spells the calculator lacks: name, class, the coefficients every rank shares
# (direct, over time), whether they are the cast time rule's estimate, and each
# rank's spell ID and learned level from foreverchanges.pro's spellbooks.
EXTRA = [
    # Instant, so 1.5 / 3.5, as the spell data confirms.
    ("Holy Shock", "paladin", .429, None, False,
     [(1311606, 30), (20473, 40), (20929, 48), (20930, 56)]),
    ("Desperate Prayer", "priest", .429, None, False,
     [(13908, 10), (19236, 18), (19238, 26), (19240, 34), (19241, 42), (19242, 50), (19243, 58)]),
    # Its damage lands after one minute: 60 / 15.
    ("Bane of Doom", "warlock", 4, None, False, [(603, 60)]),
    # The rule's estimate from each rank's own cast time.
    ("Arcane Blast", "mage", .714, None, True,
     [(400574, 20), (1239696, 30), (1239697, 40), (1239699, 50), (1239700, 60)]),
    ("Mana Burn", "priest", .857, None, True, [(8129, 24), (8131, 32), (10874, 40), (10875, 48), (10876, 56)]),
    ("Inferno", "warlock", .571, None, True, [(1122, 50)]),
    ("Light's Vigil", "paladin", .429, None, True, [(1310911, 40), (1311590, 50), (1311595, 60)]),
]


def fetch(url, name, refresh):
    path = CACHE / name
    if refresh or not path.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(url, headers={"User-Agent": "PrettyTooltip tools/make_coefficients.py"})
        with urllib.request.urlopen(request, timeout=120) as response:
            path.write_bytes(response.read())
    return path.read_text(encoding="utf-8")


def calculator_data(html):
    """The class map the page's script is given: { class: [spell, ...] }."""
    chunks = re.findall(r'self\.__next_f\.push\(\[1,"(.*?)"\]\)', html, re.S)
    payload = "".join(json.loads('"' + chunk + '"') for chunk in chunks)
    match = re.search(r'\{"(' + "|".join(CLASSES) + r')":\[', payload)
    if not match:
        raise SystemExit("no spell data in the calculator page; has the page changed?")
    # The object ends where its braces balance, strings aside.
    depth, in_string, escaped = 0, False, False
    for index in range(match.start(), len(payload)):
        char = payload[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif char in "{[":
            depth += 1
        elif char in "}]":
            depth -= 1
            if depth == 0:
                return json.loads(payload[match.start():index + 1])
    raise SystemExit("the calculator's spell data does not end; has the page changed?")


def shares(rank):
    """A rank's direct and over-time coefficients, each None where it has no
    such effect, an effect without a coefficient gaining nothing; and whether
    it scales with healing, which a text may not say, as Tranquility's
    "Regenerates" or a shield's absorb."""
    direct = periodic = None
    effects = set()
    for part in rank["parts"]:
        coefficient = part.get("coef", 0)
        effects.add(part["effect"])
        if part.get("type") == "periodic":
            periodic = round(coefficient * part.get("ticks", 1), 4)
        else:
            direct = coefficient
    return direct, periodic, "damage" not in effects


def entry(spell_id, level, direct, periodic, heals=False, estimate=False):
    flags = (", heals = true" if heals else "") + (", estimate = true" if estimate else "")
    return f"    [{spell_id}] = {{ {level}, {number(direct)}, {number(periodic)}{flags} }},"


def number(value):
    if value is None:
        return "nil"
    text = f"{value:.4f}".rstrip("0").rstrip(".")
    return text if not text.startswith("0.") else text[1:]


def main():
    parser = ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--refresh", action="store_true", help="download the calculator page again")
    args = parser.parse_args()

    data = calculator_data(fetch(CALCULATOR, "calculator.html", args.refresh))
    lines = [
        "-- Each class spell rank's spell power coefficients and the level it is",
        "-- learned at, by spell ID: { level, direct, over time }, a coefficient nil",
        "-- where the rank has no such effect. heals: it scales with healing, as a",
        "-- heal or absorb; estimate: the cast time rule's value, not the client's.",
        "-- Generated by tools/make_coefficients.py from foreverchanges.pro's downrank",
        "-- calculator, the Forever beta client's data, and its list of the spells the",
        "-- calculator lacks. Run it again when Forever changes spells.",
        "local _, ns = ...",
        "",
        "ns.spellRanks = {",
    ]
    spells, ranks, skipped, written = 0, 0, [], set()
    # Each spell's ranks in order, for what names a spell but not its ID.
    by_name = {}
    for cls in CLASSES:
        for spell in data.get(cls, []):
            forever = spell.get("forever")
            if not forever:
                skipped.append(f"{cls}: {spell['name']}")
                continue
            spells += 1
            lines.append(f"    -- {spell['name']} ({cls.capitalize()})")
            for rank in forever["ranks"]:
                ranks += 1
                direct, periodic, heals = shares(rank)
                written.add(rank["spell_id"])
                by_name.setdefault(spell["name"], {})[rank["rank"]] = rank["spell_id"]
                lines.append(entry(rank["spell_id"], rank["level"], direct, periodic, heals=heals))
    lines.append("    -- Not in the calculator: by hand, in tools/make_coefficients.py.")
    for name, cls, direct, periodic, estimate, extra_ranks in EXTRA:
        lines.append(f"    -- {name} ({cls.capitalize()})")
        for spell_id, level in extra_ranks:
            # The calculator's data wins; an extra it now has must be dropped from EXTRA.
            if spell_id in written:
                raise SystemExit(f"{name} {spell_id} is in the calculator now; remove it from EXTRA")
            spells, ranks = spells + (spell_id == extra_ranks[0][0]), ranks + 1
            by_name.setdefault(name, {})[len(by_name.get(name, {})) + 1] = spell_id
            lines.append(entry(spell_id, level, direct, periodic, estimate=estimate))
    lines += ["}", "", "-- By name, each rank's spell ID in rank order: for a spell named without its ID.",
              "ns.spellRankByName = {"]
    for name in sorted(by_name):
        ids = [by_name[name][number] for number in sorted(by_name[name])]
        lines.append(f"    [{json.dumps(name)}] = {{ {', '.join(map(str, ids))} }},")
    lines += ["}", ""]
    (ROOT / "Data" / "SpellRanks.lua").write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"{spells} spells, {ranks} ranks written to Data/SpellRanks.lua")
    if skipped:
        print(f"{len(skipped)} spells with Classic data only (left out):")
        for line in skipped:
            print("  " + line)


if __name__ == "__main__":
    main()
