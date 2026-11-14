"""Checks the reader of the client's tooltip language (tools/spell_formulas.py) on small
made-up spells, without wago.tools data."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))

import spell_formulas as sf  # noqa: E402

HOLY, FROST = 2, 16
DAMAGE, HEAL, AURA, WEAPON_PERCENT = 2, 10, 6, 31


def effect(index, bp, effect_type=DAMAGE, sp=0.0, var=0.0, ap=0.0, aura=0, period=0, ppl=0.0, ppr=0.0):
    return dict(index=index, effect=effect_type, aura=aura, bp=bp, var=var, ppl=ppl, ppr=ppr, sp_raw=sp, ap=ap,
                period=period, radius=[0.0, 0.0], chain=0)


class Client:
    def __init__(self, spells, descriptions=None):
        self.spells = spells  # id -> (school, duration ms, levels, [effects])
        self.desc = descriptions or {}

    def effects(self, sid):
        return self.spells[sid][3]

    def info(self, sid):
        school, dur, levels, _ = self.spells[sid]
        return dict(school=school, dur=dur, levels=levels)


def numbers(reader, sid, template, state=None):
    """Each printed number of a template in one state: (source, Value, count)."""
    nodes = sf.parse(template)
    return [(n.source if n else None, v, c) for n, v, c in sf.printed(reader, sid, nodes, state or {})]


class Reading(unittest.TestCase):
    def setUp(self):
        self.client = Client({
            1: (HOLY, 0, None, [effect(0, 175, sp=.429, var=.08)]),
            2: (HOLY, 0, None, [effect(0, 150, HEAL, sp=.429, var=.08)]),
            3: (HOLY, 16000, None, [effect(0, 12), effect(1, 27, sp=.042)]),
            4: (FROST, 30000, None, [effect(0, 913, AURA, aura=69)]),
            5: (HOLY, 0, None, [effect(0, 70, WEAPON_PERCENT, sp=.29)]),
            9: (FROST, 0, None, [effect(0, 0), effect(1, 0), effect(2, 0)]),
            10: (1, 0, None, [effect(0, 153, var=.2)]),
            11: (32, 18000, None, [effect(0, 40, AURA, sp=.2, aura=3, period=3000)]),
        })
        self.reader = sf.Reader(self.client, {
            10: "$APR=$?a71[${0.225}][${0.25}]\r\n\n$APRatio=${$<APR>*1}",
        }, talents={9: {2: [10.0, 20.0]}})

    def test_damage_or_heal(self):
        out = numbers(self.reader, 1, "Causes $1s1 Holy damage to an enemy, or $2s1 healing to an ally.")
        self.assertEqual([c for _, _, c in out], [2, 2])
        self.assertEqual(out[0][1].terms, {"spell:Holy": .429})
        self.assertEqual(out[1][1].terms, {"heal": .429})

    def test_base_points_hide_spell_power(self):
        (_, value, _), = numbers(self.reader, 3, "${$m2*8} damage")
        self.assertEqual((value.lo, value.terms), (216, {}))
        self.assertAlmostEqual(value.hidden["spell:Holy"], .336)

    def test_weapon_percent_hides_its_bonus(self):
        (_, value, _), = numbers(self.reader, 5, "$s1% of weapon damage")
        self.assertEqual((value.lo, value.terms), (70, {}))
        self.assertAlmostEqual(value.hidden["spell:Holy"], .29)

    def test_over_time_counts_ticks(self):
        (_, value, count), = numbers(self.reader, 11, "$o1 Shadow damage over $d")[:1]
        self.assertEqual((value.lo, count), (240, 1))
        self.assertAlmostEqual(value.terms["spell:Shadow"], 1.2)

    def test_variables_by_stance(self):
        template = "${$m1+($<APRatio>*$apm)} damage"
        atoms, read = sf.read(self.reader, 10, template)
        self.assertEqual(atoms, [("atom", "a", 71)])
        ratios = {state[atoms[0]]: items[0][1].terms["ap"] for state, items in read}
        self.assertEqual(ratios, {False: .25, True: .225})

    def test_talent_rank(self):
        template = "Absorbs ${$s1+($SPFR*0.1)*($9s3/100+1)} Frost damage."
        atoms, read = sf.read(self.reader, 4, template)
        self.assertEqual(atoms, [("rank", "r", 9)])
        coefficients = [round(items[0][1].terms["spell:Frost"], 6) for _, items in read]
        self.assertEqual(coefficients, [.1, .11, .12])

    def test_literal_numbers_count(self):
        out = numbers(self.reader, 1, "Lasts 20 sec. The first 4 targets take $s1 damage.")
        self.assertEqual([src for src, _, _ in out], [None, None, "$s1"])

    def test_conditions_else_if(self):
        nodes = sf.parse("$?s1[one][$?s2[two][three]]")
        self.assertEqual(self.reader.flatten(nodes, {("atom", "s", 2): True})[0].text, "two")
        nodes = sf.parse("$?s1[one]?s2[two][three]")
        self.assertEqual(self.reader.flatten(nodes, {})[0].text, "three")
        self.assertEqual(self.reader.flatten(nodes, {("atom", "s", 1): True})[0].text, "one")

    def test_divided_reference(self):
        (_, value, _), = numbers(self.reader, 1, "$/2;1s1 damage")
        self.assertAlmostEqual(value.terms["spell:Holy"], .2145)

    def test_client_quirks(self):
        # A stray closing parenthesis, and "$*" as times.
        self.assertEqual(sf.expression("$m1/100+1)")[0], "add")
        self.assertEqual(sf.expression("$m2$*$<x>")[0], "mul")
        # An escaped sign before a token still prints the token.
        self.assertEqual(len(numbers(self.reader, 1, "by $$1s1%")), 1)

    def test_plurals_print_no_number(self):
        out = numbers(self.reader, 1, "Awards $s1 combo $lpoint:points;.")
        self.assertEqual(len(out), 1)

    def test_unreadable_spells_are_named(self):
        with self.assertRaises(sf.NonLinear):
            numbers(self.reader, 1, "${$apm*$mcrit}")
        with self.assertRaises(sf.NonLinear):
            numbers(self.reader, 1, "${100/$SPH}")
        with self.assertRaises(sf.FormulaError):
            sf.parse("${$s1 # 2}")
        with self.assertRaises(sf.FormulaError):
            sf.parse("$?s1[unclosed")


if __name__ == "__main__":
    unittest.main()
