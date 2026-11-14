"""Writes Data/SpellParts.lua: every class spell rank's scaling parts, from the client's own
tables: what each number its tooltip prints scales with, and where that number stands in
each language. A report of every rank and every issue goes to .release/spell-parts/.

    python tools/make_spell_parts.py                       newest Forever build
    python tools/make_spell_parts.py --build 1.60.1.70888  a specific build
    python tools/make_spell_parts.py --offline             tables already downloaded

A part is one printed number that scales (its slot: the how-manyth number of the
description), or one effect that scales and is not printed (hidden). Coefficients come
from tools/spell_formulas.py, which reads the tooltip's own formulas and variables, so a
talent, stance or form the formula checks becomes a condition tree the addon resolves at
runtime: { "s", spellID, ifNot, ifKnown }, { "a", spellID, ifNot, ifActive },
{ "r", talentSpellID, atRank0, atRank1, ... }.
"""

import collections
import csv
import io
import json
import os
import sys
from argparse import ArgumentParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "Data" / "SpellParts.lua"
OUT = ROOT / ".release" / "spell-parts"
LOCALES = ["deDE", "frFR", "esES", "esMX", "ptBR", "koKR", "zhCN", "zhTW", "ruRU"]
EXTRA_TABLES = ["SpellXDescriptionVariables", "SpellDescriptionVariables", "TraitDefinition",
                "TraitDefinitionEffectPoints", "TraitNodeEntry", "TraitNodeXTraitNodeEntry", "CurvePoint"]
PERIODIC_AURAS = {3, 8, 53}
PERIODIC_TRIGGER = 23
WEAPON_EFFECTS = {17, 31, 58, 121}
WEAPON_PERCENT = 31

# What the client leaves to server scripts or says only in prose, by ability. alt: printed
# parts (1-based, in print order) of which a cast lands one; label: captions by part;
# skip: no exact reading; dummy: why the rank's server-script effects add nothing.
CHANNEL_TEMPLATE = "The channel's area aura carries 0.03 on every rank; the tick spell has the real coefficient."
SEAL_OF_FURY = "Base points match the seal's and its Judgement's, printed nowhere: not damage (threat, likely)."
CUSTOM = {
    "Holy Shock": dict(alt=[(1, 2)]),
    "Penance": dict(alt=[(1, 2)]),
    "Death Mark": dict(skip="Its cap multiplies attack power by critical strike chance."),
    "Seal of Command": dict(label={1: "proc", 2: "judgement", 3: "judgementStunned"}),
    "Seal of Righteousness": dict(label={1: "perSwingFast", 2: "perSwingSlow", 3: "judgement"},
                                  dummy="A copy of the per-swing pool; the tooltip reads the Judgement's."),
    "Judgement of Righteousness": dict(dummy="Seal of Righteousness's per-swing pool, read by its tooltip ($20286s3)."),
    "Seal of Fury": dict(label={1: "proc", 2: "judgement"}, dummy=SEAL_OF_FURY),
    "Judgement of Fury": dict(dummy=SEAL_OF_FURY),
    "Consecration": dict(label={2: "firstTargets"}),
    "Hurricane": dict(dummy=CHANNEL_TEMPLATE),
    "Blizzard": dict(dummy=CHANNEL_TEMPLATE),
    "Rain of Fire": dict(dummy=CHANNEL_TEMPLATE),
    "Volley": dict(dummy=CHANNEL_TEMPLATE),
    "Firebolt": dict(dummy="A copy of the damage effect."),
}


def load_localized(fs, build, table, locale, offline):
    """A table in one language, cached beside forever_spells' tables."""
    path = os.path.join(fs.CACHE, build, f"{table}.{locale}.csv")
    if os.path.exists(path):
        data = open(path, "rb").read()
    else:
        if offline:
            raise FileNotFoundError(f"{path} is not downloaded (run without --offline)")
        print(f"  downloading {table} {build} {locale}", file=sys.stderr)
        data = fs.get(f"{fs.WAGO}/db2/{table}/csv?build={build}&locale={locale}")
        if not data.strip() or data.lstrip()[:1] == b"<":
            raise ValueError(f"wago.tools returned no {table} for {locale} at {build}")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path + ".part", "wb") as f:
            f.write(data)
        os.replace(path + ".part", path)
    return list(csv.DictReader(io.StringIO(data.decode("utf-8-sig"))))


def talent_data(tables):
    """{talent spell: {effect index: [value per rank]}} and {talent spell: trait node ID}."""
    defs = {r["ID"]: int(r["SpellID"]) for r in tables["TraitDefinition"] if r.get("SpellID") not in (None, "", "0")}
    curves = collections.defaultdict(list)
    for r in tables["CurvePoint"]:
        curves[r["CurveID"]].append((float(r["Pos_0"]), float(r["Pos_1"])))
    values, ranked = collections.defaultdict(dict), set()
    for r in tables["TraitDefinitionEffectPoints"]:
        sid, points = defs.get(r["TraitDefinitionID"]), sorted(curves.get(r["CurveID"], []))
        if sid and points and r["OperationType"] == "0":
            values[sid][int(r["EffectIndex"])] = [v for _, v in points]
            ranked.add(r["TraitDefinitionID"])
    # A talent can have several definitions (Frost Warding has two); its node is the one
    # whose definition carries the rank values.
    entries = {r["ID"]: r["TraitDefinitionID"] for r in tables["TraitNodeEntry"]}
    nodes = {}
    for r in tables["TraitNodeXTraitNodeEntry"]:
        definition = entries.get(r["TraitNodeEntryID"])
        sid = defs.get(definition)
        if sid and (definition in ranked or sid not in nodes):
            nodes[sid] = int(r["TraitNodeID"])
    return dict(values), nodes


def condition_tree(atoms, mapping):
    """A value that depends on conditions as nested { kind, id, value per domain value },
    branches that agree collapsed. mapping: {tuple of atom values: value}."""
    def build(i, fixed):
        reachable = {v for key, v in mapping.items() if key[:i] == fixed}
        if len(reachable) == 1:
            return reachable.pop()
        domain = sorted({key[i] for key in mapping if key[:i] == fixed})
        subs = [build(i + 1, fixed + (d,)) for d in domain]
        if all(s == subs[0] for s in subs):
            return subs[0]
        atom = atoms[i]
        return (atom[1], atom[2]) + tuple(subs)
    return build(0, ())


def rounded(value):
    return round(value, 6) if isinstance(value, float) else value


def count_of(node, value):
    """How many numbers a printed node shows: a reference with a spread shows "low to high",
    divided or multiplied ($/2;20966s1) too."""
    expr = node.expr
    if expr[0] in ("div", "mul") and expr[1][0] == "ref" and expr[2][0] == "num":
        expr = expr[1]
    if expr[0] == "ref" and expr[2] in "so" and value.hi - value.lo >= 1:
        return 2
    return 1


def layout(sf, reader, sid, nodes, state, desc):
    """[(node or None, value or None, first number, how many)] in print order."""
    out, pos = [], 0
    for node, value, _ in sf.printed(reader, sid, nodes, state):
        count = 1 if node is None else count_of(node, value)
        out.append((node, value, pos + 1, count))
        pos += count
    return out, pos


def category(reader, refs):
    """damage, heal, absorb or weapon for the effects a number reads."""
    kinds = set()
    for sid, index in refs:
        e = next((x for x in reader.client.effects(sid) if x["index"] == index), None)
        if not e:
            continue
        if e["effect"] == WEAPON_PERCENT:
            kinds.add("weapon")
        elif e["effect"] == 10 or e["aura"] == 8:
            kinds.add("heal")
        elif e["aura"] == 69:
            kinds.add("absorb")
        elif e["effect"] in (2, 9) or e["effect"] in WEAPON_EFFECTS or e["aura"] in (3, 15, 43, 53):
            kinds.add("damage")
    for kind in ("weapon", "absorb", "heal", "damage"):
        if kind in kinds:
            return kind
    return None


def weapon_effect(reader, refs):
    """The weapon damage effect a number reads, if any."""
    for sid, index in refs:
        e = next((x for x in reader.client.effects(sid) if x["index"] == index), None)
        if e and e["effect"] in WEAPON_EFFECTS:
            return e
    return None


def periodic(reader, refs, own):
    """(period, ticks) of an amount over time; also a spell the rank fires every tick
    (Arcane Missiles' missile)."""
    for sid, index in refs:
        e = next((x for x in reader.client.effects(sid) if x["index"] == index), None)
        if e and e["aura"] in PERIODIC_AURAS and e["period"]:
            dur = reader.client.info(sid)["dur"]
            return e["period"], (dur // e["period"] if dur else None)
    for e in reader.client.effects(own):
        if e["aura"] == PERIODIC_TRIGGER and e["period"] and any(sid == e["trigger"] for sid, _ in refs):
            dur = reader.client.info(own)["dur"]
            return e["period"], (dur // e["period"] if dur else None)
    return None


def stat_fields(terms, own_school):
    """Coefficient fields of a printed or hidden value: sp, heal, ap, rap; school if not the spell's."""
    fields, school, odd = {}, None, []
    for stat, coefficient in terms.items():
        if stat.startswith("spell"):
            fields["sp"] = coefficient
            name = stat.split(":", 1)[1] if ":" in stat else None
            if name and name != own_school:
                school = name
        elif stat in ("heal", "ap", "rap"):
            fields[stat] = coefficient
        else:
            odd.append(stat)
    return fields, school, odd


def build_spell(sf, fs, reader, record, descs, issues):
    """One rank's entry: {level, parts, numbers, slots by locale}, or None."""
    sid, name = record["id"], record["name"]
    custom = CUSTOM.get(record.get("ability") or name, {})
    if custom.get("skip"):
        issues["custom: skipped"].append(f"{name} {sid}: {custom['skip']}")
        return None
    english = reader.client.desc.get(sid, "")
    atoms, _ = sf.read(reader, sid)
    nodes = sf.parse(english)
    states = list(sf.states(atoms, reader.talents))
    own_school = record.get("school")

    # The printed numbers that scale in some state, or are weapon damage, by their source
    # token, in print order.
    per_state = []
    for state in states:
        items, total = layout(sf, reader, sid, nodes, state, english)
        per_state.append((state, items, total))
    # A damage or heal amount that gains nothing (Fireball's burn) is kept too, as 0.
    order, seen = [], set()
    for _, items, _ in per_state:
        for node, value, _, _ in items:
            if node is None or value is None or node.source in seen or node.kind != "amount":
                continue
            if value.scales or weapon_effect(reader, value.refs) or category(reader, value.refs):
                seen.add(node.source)
                order.append(node.source)

    # A talent's "known" and "has its aura" checks follow from its rank, so trees branch on
    # the rank alone.
    ranked = {a[2] for a in atoms if a[0] == "rank"}
    tree_atoms = [a for a in atoms if not (a[0] == "atom" and a[1] in "sa" and a[2] in ranked)]

    def key(state):
        return tuple(state[a] for a in tree_atoms)

    parts, printed_refs, order_refs = [], set(), []
    for source in order:
        coefficient, slot, count, refs = {}, {}, {}, set()
        for state, items, _ in per_state:
            match = next((x for x in items if x[0] is not None and x[0].source == source), None)
            if match is None:
                coefficient[key(state)] = None
                slot[key(state)] = None
                continue
            node, value, first, many = match
            refs |= value.refs
            shown, s1, odd1 = stat_fields(value.terms, own_school)
            unshown, s2, odd2 = stat_fields(value.hidden, own_school)
            if odd1 or odd2:
                issues["stat the addon cannot read"].append(f"{name} {sid} {source}: {odd1 + odd2}")
            # The game prints base points ($m) with their effect's spell power in: Frostbolt's
            # 45 to 51 shows as 62 to 68 at 30 spell damage. A formula that prints a stat
            # itself ($m1 + $bh*$bc) already counts it, and a weapon percent leaves its flat
            # bonus out.
            percent = (weapon_effect(reader, value.refs) or {}).get("effect") == WEAPON_PERCENT
            if shown:
                unshown = {}
            elif not percent:
                shown, unshown = unshown, {}
            add = not shown and bool(unshown)
            coefficient[key(state)] = (tuple(sorted((k, rounded(v)) for k, v in (unshown if add else shown).items())),
                                       s1 or s2, add)
            slot[key(state)] = first
            count[key(state)] = many
        printed_refs |= refs
        order_refs.append(frozenset(refs))
        part = {"kind": category(reader, refs) or "damage"}
        weapon = weapon_effect(reader, refs)
        if weapon:
            # Weapon damage: a percent of it (Holy Strike's $m2%), or a flat bonus on top
            # (Sinister Strike's $s1), at the weapon's speed or a normalized one.
            part["kind"] = "weapon"
            part["pct" if weapon["effect"] == WEAPON_PERCENT else "flat"] = True
            if weapon["effect"] == 121:
                part["normalized"] = True
        tree = condition_tree(tree_atoms, slot)
        part["slot"] = tree
        if any(c == 2 for c in count.values()):
            part["n"] = 2
        trees = {}
        for field in ("sp", "heal", "ap", "rap"):
            mapping = {k: (dict(v[0]).get(field, 0) if v else 0) for k, v in coefficient.items()}
            if any(mapping.values()):
                trees[field] = condition_tree(tree_atoms, mapping)
        part.update(trees)
        school = next((v[1] for v in coefficient.values() if v and v[1]), None)
        if school:
            part["school"] = school
        if any(v and v[2] for v in coefficient.values()):
            part["add"] = True
        tick = periodic(reader, refs, sid)
        if tick:
            part["every"] = tick[0] / 1000
            source_kind = source.lstrip("$")[-2:-1] if source.startswith("$") else ""
            if tick[1] and ("o" in source or "${" in source):
                part["ticks"] = tick[1]
            elif source_kind == "s":
                part["perTick"] = True
        if not category(reader, refs) and "heal" in part and "sp" not in part:
            part["kind"] = "heal"  # a server-script effect (Prayer of Mending) that scales with healing
        parts.append(part)

    # "${$m1+...} to ${$M1+...}": two printed numbers that are one amount's low and high.
    merged, merged_order, merged_refs = [], [], []
    for part, source, refs in zip(parts, order, order_refs):
        if merged:
            last = merged[-1]
            same = {k: v for k, v in last.items() if k not in ("slot", "n")} == \
                {k: v for k, v in part.items() if k not in ("slot", "n")}
            if (same and refs == merged_refs[-1] and "n" not in last and "n" not in part
                    and isinstance(last["slot"], int) and part["slot"] == last["slot"] + 1):
                last["n"] = 2
                continue
        merged.append(part)
        merged_order.append(source)
        merged_refs.append(refs)
    parts, order, order_refs = merged, merged_order, merged_refs

    # A printed amount whose effect scales only by Blizzard's notes (Thorns) takes the
    # noted coefficient, as an estimate. One that gains nothing is shown only beside one
    # that does.
    fields = ("sp", "heal", "ap", "rap")
    noted = {(p["spell"], p["effectIndex"]): p for p in record.get("parts", []) if p.get("sp") or p.get("ap")}
    for part, refs in zip(parts, order_refs):
        if part["kind"] == "weapon" or any(f in part for f in fields):
            continue
        found = [noted[r] for r in refs if r in noted]
        ticks = part.get("ticks") or 1
        if len(found) == 1 and found[0].get("sp"):
            part["heal" if part["kind"] in ("heal", "absorb") else "sp"] = rounded(found[0]["sp"] * ticks)
        if len(found) == 1 and found[0].get("ap"):
            part["ap"] = rounded(found[0]["ap"] * ticks)
        if len(found) == 1:
            part["est"] = True
        else:
            part["heal" if part["kind"] in ("heal", "absorb") else "sp"] = 0
    scaling = any(p.get(f) for p in parts for f in fields)
    kept = [i for i, p in enumerate(parts) if scaling or p["kind"] == "weapon"]
    parts, order, order_refs = [parts[i] for i in kept], [order[i] for i in kept], [order_refs[i] for i in kept]
    printed_refs = set().union(*order_refs) if order_refs else set()

    # Effects that scale and print nowhere: hidden parts, with what the base at a level needs.
    for p in record.get("parts", []):
        if not (p.get("sp") or p.get("ap")) or (p["spell"], p["effectIndex"]) in printed_refs:
            continue
        spell = p["spell"]
        e = next(x for x in reader.client.effects(spell) if x["index"] == p["effectIndex"])
        lv = reader.client.info(spell)["levels"] or {}
        part = {"kind": "weapon" if e["effect"] == WEAPON_PERCENT else (p.get("category") or "damage"),
                "hidden": True, "spell": spell}
        if p.get("sp"):
            part["heal" if p.get("category") in ("heal", "absorb") else "sp"] = rounded(p["sp"])
        if p.get("ap"):
            part["ap"] = rounded(p["ap"])
        part.update(base=e["bp"], perLevel=e["ppl"] or None, baseLevel=lv.get("base") or None,
                    maxLevel=lv.get("max") or None, variance=round(e["var"], 6) or None)
        if p.get("ticks"):
            part["ticks"], part["every"] = p["ticks"], (p.get("periodMs") or 0) / 1000
        if p.get("relation") == "separateAbility" and reader.client.names.get(spell, "").startswith("Judgement"):
            part["label"] = "judgement"
        if p.get("kind") == "dummy":
            if custom.get("dummy"):
                issues["server-script (dummy) coefficient explained"].append(f"{name} {sid} {spell}:{p['effectIndex']}")
                continue
            # A server-script effect: shown only when nothing else scales, as an estimate.
            if any(not x.get("est") for x in parts) or any(q.get("kind") != "dummy" and (q.get("sp") or q.get("ap"))
                                                          for q in record.get("parts", [])):
                issues["server-script (dummy) coefficient not shown"].append(
                    f"{name} {sid} {spell}:{p['effectIndex']} sp {p.get('sp')}")
                continue
            part["est"] = True
            issues["server-script (dummy) parts shown as estimates"].append(f"{name} {sid} {spell}:{p['effectIndex']}")
        parts.append({k: v for k, v in part.items() if v is not None})

    for group in custom.get("alt", []):
        for index in group:
            if index <= len(parts):
                parts[index - 1]["alt"] = group[0]
    for index, label in custom.get("label", {}).items():
        if index <= len(parts):
            parts[index - 1]["label"] = label
    if record.get("hitsPerCast", 1) > 1:
        for part in parts:
            part["hits"] = record["hitsPerCast"]

    # Where each printed part stands in every language, and how many numbers each prints.
    english_total = per_state[0][2]
    slots, totals = {}, {}
    for locale, desc in descs.items():
        text = desc.get(sid)
        if not text:
            continue
        try:
            local_nodes = sf.parse(text)
            items, total = layout(sf, reader, sid, local_nodes, {}, text)
        except sf.FormulaError as error:
            issues["language template the reader cannot parse"].append(f"{locale} {name} {sid}: {error}")
            slots[locale] = False
            continue
        firsts = {node.source: first for node, _, first, _ in items if node is not None}
        # A language can word a number with other tokens ($s1 for ${$m1*2}): then it is the
        # number that reads the same effects.
        by_refs = collections.defaultdict(list)
        for node, value, first, _ in items:
            if node is not None and value is not None and value.refs:
                by_refs[value.refs].append(first)
        local = []
        for source, refs in zip(order, order_refs):
            if source in firsts:
                local.append(firsts[source])
            elif len(by_refs.get(refs, [])) == 1:
                local.append(by_refs[refs][0])
            else:
                local = None
                issues["language template without an English token"].append(f"{locale} {name} {sid} {source}")
                break
        english_slots = [p["slot"] for p in parts if not p.get("hidden")]
        if local is None:
            slots[locale] = False
        elif local != [s if isinstance(s, int) else None for s in english_slots]:
            if all(isinstance(s, int) for s in english_slots):
                slots[locale] = local
            else:
                slots[locale] = False
                issues["slot depends on a condition and differs by language"].append(f"{locale} {name} {sid}")
        if total != english_total:
            totals[locale] = total

    if not parts and any((p.get("sp") or p.get("ap")) and not (p.get("kind") == "dummy" and custom.get("dummy"))
                         for p in record.get("parts", [])):
        issues["scales but no part found"].append(f"{name} {sid}")
    if any(not isinstance(p.get("slot", 0), int) for p in parts):
        issues["slot depends on a condition"].append(f"{name} {sid}")
    level = (record.get("levels") or {}).get("spell") or (record.get("levels") or {}).get("base") or 0
    return {"name": name, "rank": record.get("rank"), "level": level, "parts": parts, "numbers": english_total,
            "slots": slots, "numbersByLocale": totals, "atoms": [list(a) for a in atoms]}


# ------------------------------------------------------------------------------------------ output

def lua_value(value):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int) or (isinstance(value, float) and value.is_integer()):
        return str(int(value))
    if isinstance(value, float):
        text = f"{value:.6g}"
        return text[1:] if text.startswith("0.") else ("-" + text[2:] if text.startswith("-0.") else text)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, tuple):  # a condition tree
        return "{ " + ", ".join(lua_value(v) for v in value) + " }"
    if isinstance(value, list):
        return "{ " + ", ".join(lua_value(v) for v in value) + " }"
    if isinstance(value, dict):
        return "{ " + ", ".join(f"{k} = {lua_value(v)}" for k, v in value.items()) + " }"
    raise TypeError(value)


PART_ORDER = ["kind", "slot", "n", "pct", "flat", "normalized", "sp", "heal", "ap", "rap", "school", "add", "ticks", "every", "perTick", "hits",
              "alt", "label", "hidden", "spell", "base", "perLevel", "baseLevel", "maxLevel", "variance", "est"]


def render_lua(build, spells, talent_nodes, by_name):
    lines = ["-- Every class spell rank's scaling parts, by spell ID: { level learned, how many numbers",
             "-- its description prints, part, ... }. A part is one printed number that scales (slot:",
             "-- the how-manyth number; n = 2 for a range's low and high) or one effect that scales",
             "-- and prints nowhere (hidden). sp, heal, ap, rap: the coefficient of the number as",
             "-- printed; add: the printed number leaves that bonus out. A value can depend on the",
             "-- player: { \"s\", spell known, no, yes }, { \"a\" or \"p\", aura, no, yes },",
             "-- { \"r\", talent, at rank 0, 1, ... }.",
             f"-- Generated by tools/make_spell_parts.py from WoW Forever's client tables (build {build}).",
             "-- Forever only: retail's .toc leaves this file out.",
             "local _, ns = ...", "", "ns.spellParts = {"]
    for ability in sorted({s["name"] for s in spells.values()}):
        ids = sorted((sid for sid, s in spells.items() if s["name"] == ability), key=lambda i: (spells[i]["level"], i))
        lines.append(f"    -- {ability}")
        for sid in ids:
            s = spells[sid]
            parts = []
            for part in s["parts"]:
                ordered = {k: part[k] for k in PART_ORDER if k in part}
                kind = ordered.pop("kind")
                body = ", ".join([lua_value(kind)] + [f"{k} = {lua_value(v)}" for k, v in ordered.items()])
                parts.append("{ " + body + " }")
            lines.append(f"    [{sid}] = {{ {s['level']}, {s['numbers']}, " + ", ".join(parts) + " },")
    lines += ["}", "", "-- Where a language prints a rank's numbers otherwise than English: { how many, slot of each",
              "-- printed part }; false where its wording cannot be matched to the parts.",
              "local SLOTS = {"]
    by_locale = collections.defaultdict(list)
    for sid, s in sorted(spells.items()):
        for locale in LOCALES:
            slots, total = s["slots"].get(locale), s["numbersByLocale"].get(locale)
            if slots is False:
                by_locale[locale].append(f"[{sid}] = false")
            elif slots or total:
                by_locale[locale].append(f"[{sid}] = {{ {total or s['numbers']}" + ("".join(f", {x}" for x in slots) if slots else "") + " }")
    for locale in LOCALES:
        if by_locale[locale]:
            lines.append(f"    {locale} = {{ " + ", ".join(by_locale[locale]) + " },")
    lines += ["}", "ns.spellSlots = SLOTS[GetLocale()] or {}",
              "", "-- The trait node of each talent a rank's numbers depend on, for its rank.", "ns.spellTalentNodes = {"]
    used = sorted({a[2] for s in spells.values() for a in s["atoms"] if a[0] == "rank"})
    for talent in used:
        if talent in talent_nodes:
            lines.append(f"    [{talent}] = {talent_nodes[talent]},")
    lines += ["}", "", "-- By English name, each rank's spell ID in rank order: for a spell named without its ID.",
              "ns.spellPartsByName = {"]
    for name in sorted(by_name):
        lines.append(f"    [{json.dumps(name)}] = {{ {', '.join(map(str, by_name[name]))} }},")
    lines += ["}", ""]
    return "\n".join(lines)


def render_report(build, spells, issues, failures):
    def coefficient_text(part):
        out = []
        for field in ("sp", "heal", "ap", "rap"):
            if field in part:
                value = part[field]
                out.append(f"{field} {value if not isinstance(value, tuple) else 'by ' + str(value[0]) + ' ' + str(value[1])}")
        return ", ".join(out)

    lines = [f"# Spell parts, build {build}", "",
             f"{len(spells)} class ranks read, {len(failures)} not. Generated by tools/make_spell_parts.py.", ""]
    counts = collections.Counter(len(s["parts"]) for s in spells.values())
    lines += ["Parts per rank: " + ", ".join(f"{k}: {v}" for k, v in sorted(counts.items())), ""]
    lines += ["## Issues", ""]
    for title, entries in sorted(issues.items()):
        lines.append(f"### {title} ({len(entries)})")
        lines += [f"- {e}" for e in entries[:60]] + ([f"- ... {len(entries) - 60} more"] if len(entries) > 60 else []) + [""]
    if failures:
        lines += ["### Not read", ""] + [f"- {f}" for f in failures] + [""]
    lines += ["## Ranks", "", "| Spell | Rank | ID | Parts |", "| --- | --- | --- | --- |"]
    for sid, s in sorted(spells.items(), key=lambda kv: (kv[1]["name"], kv[1]["level"])):
        described = []
        for part in s["parts"]:
            where = "hidden" if part.get("hidden") else f"#{part['slot'] if isinstance(part['slot'], int) else 'varies'}"
            extras = [x for x in ("add", "perTick", "est") if part.get(x)] + ([f"{part['ticks']} ticks"] if part.get("ticks") else [])
            described.append(f"{part.get('label') or part['kind']} {where}: {coefficient_text(part)}"
                             + (f" ({', '.join(extras)})" if extras else ""))
        lines.append(f"| {s['name']} | {s['rank'] or ''} | {sid} | {'<br>'.join(described) or '-'} |")
    return "\n".join(lines) + "\n"


def main():
    parser = ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--build", help="Forever build, e.g. 1.60.1.70888 (default: newest on wago.tools)")
    parser.add_argument("--offline", action="store_true", help="use only tables already downloaded")
    args = parser.parse_args()
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import forever_spells as fs
    import spell_formulas as sf

    build = args.build or fs.newest_builds()[0]
    print(f"Forever build {build}")
    db = fs.database(build, no_era=True, offline=args.offline)
    tables = fs.load_tables(fs.FOREVER_TABLES, build, fs.CACHE, args.offline)
    for name in EXTRA_TABLES:
        tables[name] = fs.load_table(name, build, fs.CACHE, args.offline)
    client = fs.Client(build, tables)
    variable_sets = {r["ID"]: r["Variables"] for r in tables["SpellDescriptionVariables"]}
    variables = {int(r["SpellID"]): variable_sets.get(r["SpellDescriptionVariablesID"], "")
                 for r in tables["SpellXDescriptionVariables"]}
    talents, talent_nodes = talent_data(tables)
    reader = sf.Reader(client, variables, talents)
    descs = {locale: {int(r["ID"]): r.get("Description_lang") or ""
                      for r in load_localized(fs, build, "Spell", locale, args.offline)} for locale in LOCALES}

    spells, failures, issues, by_name = {}, [], collections.defaultdict(list), {}
    for cls, abilities in db["abilities"].items():
        for ability, ids in abilities.items():
            for sid in ids:
                record = dict(db["spells"][str(sid)], ability=ability)
                try:
                    entry = build_spell(sf, fs, reader, record, descs, issues)
                except sf.FormulaError as error:
                    failures.append(f"{cls} {ability} {sid}: {type(error).__name__}: {error}")
                    continue
                if entry:
                    entry["class"] = cls
                    spells[sid] = entry
            # Every rank, so a rank's number still finds its ID.
            if any(spells.get(sid, {}).get("parts") for sid in ids):
                by_name[ability] = list(ids)
    for warning in sorted(reader.warnings):
        issues["client quirk"].append(warning)

    OUT.mkdir(parents=True, exist_ok=True)
    DATA.write_text(render_lua(build, spells, talent_nodes, by_name), encoding="utf-8", newline="\n")
    (OUT / "report.md").write_text(render_report(build, spells, issues, failures), encoding="utf-8", newline="\n")
    (OUT / "spell-parts.json").write_text(json.dumps({"build": build, "spells": spells, "issues": issues,
                                                      "failures": failures}, indent=1, ensure_ascii=False,
                                                     default=list), encoding="utf-8")
    print(f"{len(spells)} ranks, {sum(len(s['parts']) for s in spells.values())} parts, {len(failures)} not read; "
          f"{sum(len(v) for v in issues.values())} issues. Wrote {DATA.relative_to(ROOT)} and {OUT}")


if __name__ == "__main__":
    main()
