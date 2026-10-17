#!/usr/bin/env python3
"""Build a JSON database of WoW: Forever class spells, keyed by spell ID, from the game's own client tables.

    python3 tools/forever_spells.py                          newest Forever beta build, compared with newest Classic Era
    python3 tools/forever_spells.py --build 1.60.1.70425     a specific build
    python3 tools/forever_spells.py --previous old.json      also report what changed since an earlier output
    python3 tools/forever_spells.py --offline                use only tables already downloaded

How it works: asks wago.tools for the newest build, downloads about 15 DB2 tables as CSV
(https://wago.tools/db2/<Table>/csv?build=<version>), and joins them. Which spells belong to a class comes from
SkillLineAbility; an ability's damage is followed through the spells it triggers and the spells its tooltip reads
from. Standard library only. Downloads are cached in the temp folder (prettytooltip-wago/<build>/), since a build's
tables never change. tools/make_coefficients.py builds the database with this, for Data/SpellRanks.lua.

Limits: wago.tools serves tables as the build shipped, without later hotfixes. A few scaling values exist only
on Blizzard's servers; the ones Blizzard has stated in its beta notes are in SERVER_SCALING below, and are used
only where the client carries no value of its own.
"""
import argparse
import collections
import csv
import datetime
import io
import json
import os
import re
import sys
import tempfile
import time
import urllib.error
import urllib.request

WAGO = 'https://wago.tools'
USER_AGENT = 'forever-spells/1.0 (+spell coefficient export)'
NOTES_URL = 'https://us.forums.blizzard.com/en/wow/t/2360696'
CACHE = os.path.join(tempfile.gettempdir(), 'prettytooltip-wago')

FOREVER_TABLES = ['SpellName', 'Spell', 'SpellEffect', 'SpellMisc', 'SpellLevels', 'SpellCooldowns', 'SpellPower',
                  'SpellCastTimes', 'SpellDuration', 'SpellRadius', 'SpellRange', 'SkillLine', 'SkillLineAbility',
                  'TraitDefinition', 'SpellItemEnchantment']
ERA_TABLES = ['SpellName', 'SpellEffect', 'SpellMisc', 'SpellCastTimes', 'SpellDuration']
OPTIONAL_TABLES = {'SpellRange', 'SpellRadius', 'TraitDefinition', 'SpellItemEnchantment'}

CLASS_BITS = dict(warrior=1, paladin=2, hunter=4, rogue=8, priest=16, shaman=64, mage=128, warlock=256, druid=1024)
WARLOCK_PETS = {'Imp', 'Voidwalker', 'Succubus', 'Felhunter', 'Felguard', 'Infernal', 'Doomguard'}
SKIP_LINES = {'Engraving', 'Runes', 'Mounts', 'Companions'}  # class-category skill lines that teach no class spells
SCHOOLS = {1: 'Physical', 2: 'Holy', 4: 'Fire', 8: 'Nature', 16: 'Frost', 32: 'Shadow', 64: 'Arcane'}
POWER = {0: 'mana', 1: 'rage', 2: 'focus', 3: 'energy', -2: 'health'}

# Effect and aura ids
E_DAMAGE, E_DUMMY, E_AURA, E_LEECH, E_HEAL, E_TRIGGER = 2, 3, 6, 9, 10, 64
E_WEAPON = {17, 31, 58, 121}
A_DOT, A_DUMMY, A_HOT, A_SHIELD, A_PTRIGGER, A_PROC = 3, 4, 8, 15, 23, 42
A_PROC_DAMAGE, A_LEECH, A_ABSORB, A_PDUMMY, A_PTRIGGER_VALUE = 43, 53, 69, 226, 227
AMOUNT_EFFECTS = {E_DAMAGE, E_LEECH, E_HEAL} | E_WEAPON
AMOUNT_AURAS = {A_DOT, A_HOT, A_LEECH, A_ABSORB, A_SHIELD, A_PROC_DAMAGE}
FOLLOW_AURAS = {A_PTRIGGER, A_PROC, A_PTRIGGER_VALUE}
PERIODIC_AURAS = {A_DOT, A_HOT, A_LEECH}
EFFECT_NAMES = {2: 'SCHOOL_DAMAGE', 3: 'DUMMY', 6: 'APPLY_AURA', 9: 'HEALTH_LEECH', 10: 'HEAL', 17: 'WEAPON_DAMAGE_NOSCHOOL',
                24: 'CREATE_ITEM', 27: 'PERSISTENT_AREA_AURA', 28: 'SUMMON', 30: 'ENERGIZE', 31: 'WEAPON_PERCENT_DAMAGE',
                35: 'APPLY_AREA_AURA_PARTY', 36: 'LEARN_SPELL', 58: 'WEAPON_DAMAGE', 64: 'TRIGGER_SPELL', 65: 'APPLY_AREA_AURA_RAID',
                77: 'SCRIPT_EFFECT', 121: 'NORMALIZED_WEAPON_DMG', 179: 'CREATE_AREATRIGGER'}
AURA_NAMES = {3: 'PERIODIC_DAMAGE', 4: 'DUMMY', 8: 'PERIODIC_HEAL', 15: 'DAMAGE_SHIELD', 23: 'PERIODIC_TRIGGER_SPELL',
              42: 'PROC_TRIGGER_SPELL', 43: 'PROC_TRIGGER_DAMAGE', 53: 'PERIODIC_LEECH', 69: 'SCHOOL_ABSORB',
              226: 'PERIODIC_DUMMY', 227: 'PERIODIC_TRIGGER_SPELL_WITH_VALUE'}
A_OVERRIDE_SPELL = 332  # a talent swaps one spell for another: basePoints = the new spell, misc = the old one
ENCHANT_EFFECTS = {53, 54, 360}  # enchant a weapon; misc = SpellItemEnchantment id (360: Forever's weapon imbues)
ACQUIRE_NEVER_LEARNED = '3'  # SkillLineAbility.AcquireMethod: on the skill line but not learned from it
ATTR0_PASSIVE = 0x40
ATTR1_CHANNELED = 0x4 | 0x40
TARGET_CASTER = 1
HITS_PER_CAST = {'Penance': 3}  # the tooltip says: on cast, then every tick

# Scaling Blizzard states in its beta development notes that the client does not carry. Used only where the
# client's own value is 0. (class, ability, effect or aura id it sits on, 'sp' or 'ap', value, date, note)
SERVER_SCALING = [
    ('druid', 'Thorns', ('aura', A_SHIELD), 'sp', 0.06, '2026-10-08', 'Thorns uses 6% of the caster\'s spell power (was 13.3%).'),
    ('paladin', 'Retribution Aura', ('aura', A_SHIELD), 'sp', 0.06, '2026-10-08', 'Retribution Aura uses 6% of the Paladin\'s spell power (was 13.3%).'),
    ('druid', 'Swipe', ('effect', E_DAMAGE), 'ap', 0.03, '2026-10-01', 'Swipe gains 3% of the Druid\'s attack power.'),
    ('warrior', 'Bloodthirst', ('effect', E_DAMAGE), 'ap', 0.45, '2026-10-01', 'Bloodthirst\'s attack power ratio is 45% (was 35%).'),
    ('warlock', 'Sacrifice', ('aura', A_ABSORB), 'sp', 0.10, '2026-09-24', 'Voidwalker Sacrifice scales with 10% of the Warlock\'s spell healing.'),
]
TEXT_NOTES = [
    ('mage', 'Arcane Wrath', '2026-10-15', 'Also deals damage as if the Mage had extra spell power equal to 5% of maximum mana.'),
    ('mage', 'Arcane Blast', '2026-10-15', 'Each cast grants 15% of Intellect as spell damage for 15 sec, stacking 4 times.'),
    ('mage', 'Cone of Cold', '2026-10-15', 'Each Winter\'s Chill stack gives the next Cone of Cold an extra 7% of your spell damage, up to 5 stacks.'),
    ('paladin', 'Seal of Righteousness', '2026-10-15', 'A bug giving the seal almost twice the intended spell damage benefit was fixed; no value published.'),
    ('hunter', 'Immolation Trap', '2026-10-15', 'Fire traps now scale with attack power; no ratio published.'),
    ('hunter', 'Explosive Trap', '2026-10-15', 'Fire traps now scale with attack power; no ratio published.'),
]


# --------------------------------------------------------------------------------------------- downloads

def version_key(v):
    return tuple(int(p) for p in v.split('.') if p.isdigit())


def get(url, retries=3):
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read()
        except (urllib.error.URLError, TimeoutError) as e:
            if attempt == retries - 1 or (isinstance(e, urllib.error.HTTPError) and e.code in (400, 403, 404)):
                raise
            time.sleep(2 * (attempt + 1))


def newest_builds():
    """(newest Forever build, newest Classic Era build) listed on wago.tools. Forever is 1.6x.x, Era is 1.15.x."""
    products = json.loads(get(f'{WAGO}/api/builds'))
    def newest(pred, prefer):
        found = [b['version'] for p, bs in products.items() if p in prefer for b in bs if pred(b['version'])]
        if not found:
            found = [b['version'] for bs in products.values() for b in bs if pred(b['version'])]
        return max(found, key=version_key) if found else None
    forever = newest(lambda v: re.match(r'1\.6\d\.', v), ('wow_classic_beta',))
    era = newest(lambda v: v.startswith('1.15.'), ('wow_classic_era',))
    return forever, era


def load_table(name, build, cache, offline):
    path = os.path.join(cache, build, f'{name}.csv')
    if os.path.exists(path):
        data = open(path, 'rb').read()
    else:
        if offline:
            raise FileNotFoundError(f'{path} is not downloaded (run without --offline)')
        print(f'  downloading {name} {build}', file=sys.stderr)
        data = get(f'{WAGO}/db2/{name}/csv?build={build}')
        if not data.strip() or data.lstrip()[:1] == b'<' or b',' not in data.split(b'\n', 1)[0]:
            raise ValueError(f'wago.tools returned no CSV for {name} at {build}')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path + '.part', 'wb') as f:
            f.write(data)
        os.replace(path + '.part', path)
    return list(csv.DictReader(io.StringIO(data.decode('utf-8-sig'))))


def load_tables(names, build, cache, offline):
    out = {}
    for n in names:
        try:
            out[n] = load_table(n, build, cache, offline)
        except Exception as e:
            if n not in OPTIONAL_TABLES:
                raise
            print(f'  {n} unavailable ({e}); continuing without it', file=sys.stderr)
            out[n] = []
    return out


# --------------------------------------------------------------------------------------------- client model

def num(v, default=0.0):
    try:
        return float(v) if v not in (None, '') else default
    except ValueError:
        return default


def n(v):
    return int(num(v))


def rd(x, nd=4):
    if x is None:
        return None
    y = round(float(x), nd)
    return int(y) if y == int(y) else y


class Client:
    def __init__(self, build, t):
        self.build = build
        base = lambda rows: [r for r in rows if n(r.get('DifficultyID')) == 0]
        self.names = {n(r['ID']): r['Name_lang'] for r in t['SpellName']}
        spell = {n(r['ID']): r for r in t.get('Spell', [])}
        self.rank = {k: (r.get('NameSubtext_lang') or '') for k, r in spell.items()}
        self.desc = {k: (r.get('Description_lang') or '') for k, r in spell.items()}
        self.fx = collections.defaultdict(list)
        for r in base(t['SpellEffect']):
            self.fx[n(r['SpellID'])].append(r)
        self.misc = {n(r['SpellID']): r for r in base(t['SpellMisc'])}
        self.levels = {n(r['SpellID']): r for r in base(t.get('SpellLevels', []))}
        self.cds = {n(r['SpellID']): r for r in base(t.get('SpellCooldowns', []))}
        self.power = collections.defaultdict(list)
        for r in t.get('SpellPower', []):
            self.power[n(r['SpellID'])].append(r)
        self.cast = {r['ID']: n(r['Base']) for r in t['SpellCastTimes']}
        self.dur = {r['ID']: n(r['Duration']) for r in t['SpellDuration']}
        self.radius = {r['ID']: num(r['Radius']) for r in t.get('SpellRadius', [])}
        self.range = {r['ID']: (num(r.get('RangeMin_0')), num(r.get('RangeMax_0'))) for r in t.get('SpellRange', [])}
        self.enchant_spells = {}  # enchantment id -> the spells it casts or applies
        for r in t.get('SpellItemEnchantment', []):
            arg = [n(r.get(f'EffectArg_{i}')) for i in range(3) if r.get(f'Effect_{i}') in ('1', '3') and n(r.get(f'EffectArg_{i}'))]
            if arg:
                self.enchant_spells[n(r['ID'])] = arg
        self.overrides = {}  # new spell -> (old spell, the talent that swaps them)
        for r in base(t['SpellEffect']):
            if n(r['EffectAura']) == A_OVERRIDE_SPELL and num(r.get('EffectBasePointsF', r.get('EffectBasePoints'))):
                self.overrides[int(num(r.get('EffectBasePointsF', r.get('EffectBasePoints'))))] = (n(r.get('EffectMiscValue_0')), n(r['SpellID']))
        self.talents = None  # spell ids a talent tree teaches; None when TraitDefinition is unavailable
        if t.get('TraitDefinition'):
            self.talents = {n(r.get(k)) for r in t['TraitDefinition'] for k in ('SpellID', 'OverridesSpellID', 'VisibleSpellID') if n(r.get(k))}
        self._fx, self._info = {}, {}

    def has(self, sid):
        return sid in self.fx

    def effects(self, sid):
        if sid not in self._fx:
            out = []
            for r in sorted(self.fx.get(sid, []), key=lambda r: n(r['EffectIndex'])):
                forever = 'EffectDieSides' not in r  # Era rows roll basePoints + 1 .. basePoints + dieSides
                bp = num(r['EffectBasePointsF']) if forever else num(r.get('EffectBasePoints'))
                dice = 0 if forever else n(r.get('EffectDieSides'))
                out.append(dict(
                    index=n(r['EffectIndex']), effect=n(r['Effect']), aura=n(r['EffectAura']), bp=bp, dice=dice,
                    var=num(r.get('Variance')) if forever else 0.0, ppl=num(r.get('EffectRealPointsPerLevel')),
                    ppr=num(r.get('EffectPointsPerResource')), sp_raw=num(r.get('EffectBonusCoefficient')),
                    ap=num(r.get('BonusCoefficientFromAP')), pvp=num(r.get('PvpMultiplier'), 1.0), amplitude=num(r.get('EffectAmplitude')),
                    period=n(r.get('EffectAuraPeriod')), trigger=n(r.get('EffectTriggerSpell')), chain=n(r.get('EffectChainTargets')),
                    chain_amp=num(r.get('EffectChainAmplitude'), 1.0), mechanic=n(r.get('EffectMechanic')),
                    misc=[n(r.get('EffectMiscValue_0')), n(r.get('EffectMiscValue_1'))],
                    radius=[self.radius.get(r.get('EffectRadiusIndex_0'), 0.0), self.radius.get(r.get('EffectRadiusIndex_1'), 0.0)],
                    targets=[n(r.get('ImplicitTarget_0')), n(r.get('ImplicitTarget_1'))], attributes=n(r.get('EffectAttributes')),
                    mask=[n(r.get(f'EffectSpellClassMask_{i}')) for i in range(4)]))
            self._fx[sid] = out
        return self._fx[sid]

    def info(self, sid):
        if sid not in self._info:
            m, lv, cd = self.misc.get(sid), self.levels.get(sid), self.cds.get(sid, {})
            attr = [n(m.get(f'Attributes_{i}')) for i in range(17)] if m else []
            dur = self.dur.get(m.get('DurationIndex'), 0) if m else 0
            rng = self.range.get(m.get('RangeIndex')) if m else None
            costs = []
            for p in sorted(self.power.get(sid, []), key=lambda p: n(p.get('OrderIndex'))):
                c = dict(power=POWER.get(n(p.get('PowerType')), n(p.get('PowerType'))), amount=n(p.get('ManaCost')),
                         perLevel=n(p.get('ManaCostPerLevel')), pctOfBaseMana=rd(num(p.get('PowerCostPct'))), perSecond=n(p.get('ManaPerSecond')))
                if c['amount'] or c['pctOfBaseMana'] or c['perSecond']:
                    costs.append(c)
            self._info[sid] = dict(
                known=bool(m), school=n(m.get('SchoolMask')) if m else 0, cast=self.cast.get(m.get('CastingTimeIndex'), 0) if m else None,
                dur=dur if dur > 0 else 0, channeled=bool(len(attr) > 1 and attr[1] & ATTR1_CHANNELED),
                passive=bool(attr and attr[0] & ATTR0_PASSIVE), attr=attr,
                levels=dict(spell=n(lv.get('SpellLevel')), base=n(lv.get('BaseLevel')), max=n(lv.get('MaxLevel'))) if lv else None,
                cd=n(cd.get('RecoveryTime')), ccd=n(cd.get('CategoryRecoveryTime')), gcd=n(cd.get('StartRecoveryTime')) or None,
                range=dict(min=rng[0], max=rng[1]) if rng else None, speed=num(m.get('Speed')) if m else 0, costs=costs)
        return self._info[sid]

    def refs(self, sid):
        """Spells whose effects the tooltip reads ($12345s1, $12345m2, $12345o1): {spell: {effect index}}. Only those
        effects count, as a tooltip may borrow a mere count from another rank ("the first $10161s3 targets")."""
        out = collections.defaultdict(set)
        for spell, index in re.findall(r'\$(\d{3,})[smoSMO](\d)', self.desc.get(sid, '')):
            out[int(spell)].add(int(index) - 1)
        return out


def coef_is_real(effect, aura, sp, school):
    """The client stores 1.0 both as a real value (a 3.5 sec cast) and as 'unset'. Keep 1.0 only on a spell-school
    effect that carries an amount and is not a per-tick value."""
    if not sp:
        return False
    if abs(sp - 1) > 1e-6:
        return True
    if effect in E_WEAPON or aura in PERIODIC_AURAS:
        return False
    return (effect in AMOUNT_EFFECTS or aura in AMOUNT_AURAS) and bool(school) and school != 1


def kind_of(e):
    """(group, category, label) of one effect."""
    t, a, self_hit = e['effect'], e['aura'], e['targets'][0] == TARGET_CASTER
    if t == E_DAMAGE:
        return ('self', 'damage', 'Damage to self') if self_hit else ('direct', 'damage', 'Direct damage')
    if t in E_WEAPON:
        return 'direct', 'damage', 'Weapon damage'
    if t == E_HEAL:
        return 'direct', 'heal', 'Direct heal'
    if t == E_LEECH:
        return 'direct', 'damage', 'Drain'
    if a == A_DOT:
        return ('self', 'damage', 'Damage to self over time') if self_hit else ('periodic', 'damage', 'Damage over time')
    if a == A_HOT:
        return 'periodic', 'heal', 'Heal over time'
    if a == A_LEECH:
        return 'periodic', 'damage', 'Drain over time'
    if a == A_ABSORB:
        return 'direct', 'absorb', 'Absorb'
    if a == A_SHIELD:
        return 'direct', 'damage', 'Damage shield (per hit taken)'
    if a == A_PROC_DAMAGE:
        return 'direct', 'damage', 'Proc damage'
    if t == E_DUMMY or a in (A_DUMMY, A_PDUMMY):
        return 'dummy', None, 'Dummy effect (server script)'
    return 'other', None, f'Effect {t}' + (f', aura {a}' if a else '')


def parts_of(c, sid, parent=None, rel=None, depth=0, seen=None, hint=None, only=None):
    """The effects that carry an ability's scaling: its own, and those of the spells it triggers or its tooltip
    reads from. hint = (period, ticks) when the parent lands a triggered spell on a timer; only = the effect
    indices a tooltip reads, when that is how the spell was reached."""
    seen = seen if seen is not None else set()
    if sid in seen or depth > 3 or not c.has(sid):
        return []
    seen.add(sid)
    info = c.info(sid)
    ref = info if info['known'] or not parent else parent
    school = info['school'] or (parent or {}).get('school', 0)
    dur = info['dur']
    effs = c.effects(sid)
    # A tooltip may name an effect the spell lacks (Contingency Plan's $1277460o2); then all of them count.
    if only is not None and not any(e['index'] in only for e in effs):
        only = None
    own_period = next((e['period'] for e in effs if e['aura'] in (A_PDUMMY, A_PTRIGGER) and e['period']), 0)
    out = []
    for e in effs:
        group, cat, label = kind_of(e)
        sp = e['sp_raw'] if coef_is_real(e['effect'], e['aura'], e['sp_raw'], school) else 0.0
        ap = e['ap'] if e['ap'] and not (e['effect'] in E_WEAPON and abs(e['ap'] - 1) < 1e-6) else 0.0
        # A spell reached through its tooltip counts the effects the tooltip reads; what it triggers still counts.
        if (only is None or e['index'] in only) and ((cat and group != 'other') or sp or ap):
            ticks = period = None
            if group == 'periodic' and e['period']:
                period, ticks = e['period'], (dur // e['period'] if dur else None)
            elif group == 'direct' and rel in ('triggered', 'tooltipLinked') and hint:
                period, ticks = hint
                group = 'periodic'
                label = {'Direct damage': 'Damage per tick', 'Direct heal': 'Heal per tick'}.get(label, label + ' (per tick)')
            out.append(dict(spell=sid, effectIndex=e['index'], label=label, kind=group, category=cat, sp=rd(sp), ap=rd(ap),
                            ticks=ticks, periodMs=period, relation=rel, school=SCHOOLS.get(school)))
        t = e['trigger']
        if t and t != sid and c.has(t) and (e['effect'] == E_TRIGGER or e['aura'] in FOLLOW_AURAS):
            h = (e['period'], dur // e['period']) if e['aura'] in (A_PTRIGGER, A_PTRIGGER_VALUE) and e['period'] and dur else None
            out += parts_of(c, t, ref, 'triggered', depth + 1, seen, h)
        if e['effect'] in ENCHANT_EFFECTS:
            for t in getattr(c, 'enchant_spells', {}).get(e['misc'][0], []):
                out += parts_of(c, t, ref, 'triggered', depth + 1, seen)
    for r, indices in c.refs(sid).items():
        if r != sid and r not in seen:
            h = (own_period, dur // own_period) if own_period and dur else None
            out += parts_of(c, r, ref, 'tooltipLinked', depth + 1, seen, h, indices)
    return out


def effect_record(c, sid, e, levels, school, dur):
    usable = coef_is_real(e['effect'], e['aura'], e['sp_raw'], school)
    carries = e['effect'] in AMOUNT_EFFECTS or e['aura'] in AMOUNT_AURAS
    ticks = dur // e['period'] if e['period'] and dur and e['aura'] in (A_DOT, A_HOT, A_LEECH, A_PTRIGGER, A_PDUMMY, A_PTRIGGER_VALUE) else None
    rec = dict(index=e['index'], effect=e['effect'], effectName=EFFECT_NAMES.get(e['effect']), aura=e['aura'] or None,
               auraName=AURA_NAMES.get(e['aura']), basePoints=rd(e['bp']), variance=rd(e['var'], 6), pointsPerLevel=rd(e['ppl']),
               pointsPerComboPoint=rd(e['ppr']) or None, spCoef=rd(e['sp_raw']) if usable else 0,
               spCoefRaw=rd(e['sp_raw']) if e['sp_raw'] and not usable else None, apCoef=rd(e['ap']), coefSource='client',
               periodMs=e['period'] or None, ticks=ticks,
               chainTargets=e['chain'] if e['chain'] > 1 else None, chainAmplitude=rd(e['chain_amp']) if e['chain'] > 1 else None,
               pvpMultiplier=rd(e['pvp']) if e['pvp'] != 1 else None,
               radiusYards=dict(min=e['radius'][0], max=e['radius'][1]) if any(e['radius']) else None,
               triggerSpell=e['trigger'] or None, miscValue=e['misc'] if any(e['misc']) else None, mechanic=e['mechanic'] or None,
               implicitTargets=e['targets'], effectAttributes=e['attributes'] or None,
               affectsSpells=dict(mask=e['mask']) if any(e['mask']) else None, carriesAmount=carries or None)
    if e['dice']:  # Era: base points + 1 .. base points + die sides
        rec.update(basePoints=rd(e['bp'] + 1), basePointsMax=rd(e['bp'] + e['dice']))
    if carries and e['bp']:
        mean = e['bp']
        if e['ppl'] and levels and levels['base'] and levels['max']:
            mean += e['ppl'] * max(0, min(60, levels['max']) - levels['base'])
        spread = abs(e['bp']) * e['var'] / 2
        rec['atLevel60'] = dict(min=rd(mean - spread, 2), mean=rd(mean, 2), max=rd(mean + spread, 2))
    return {k: v for k, v in rec.items() if v is not None}


def describe(c, sid, depth=0):
    """The tooltip with its $-tokens filled in for a level-60 caster (best effort)."""
    text = c.desc.get(sid, '')
    if not text:
        return ''

    def amount(s, idx, kind):
        e = next((x for x in c.effects(s) if x['index'] == idx - 1), None)
        if not e:
            return None
        info, v = c.info(s), e['bp']
        lv = info['levels']
        if e['ppl'] and lv and lv['base'] and lv['max']:
            v += e['ppl'] * max(0, min(60, lv['max']) - lv['base'])
        if kind in 'oO' and e['period'] and info['dur']:
            v *= info['dur'] // e['period']
        if kind in 'sS' and e['var']:
            lo, hi = v - abs(e['bp']) * e['var'] / 2, v + abs(e['bp']) * e['var'] / 2
            if round(lo) != round(hi):
                return (lo, hi)
        return v

    def value(ref, kind, idx):
        s = int(ref) if ref else sid
        if kind in 'sSmMoO':
            return amount(s, int(idx or 1), kind)
        if kind in 'dD':
            d = c.info(s)['dur']
            return d / 1000 if d else None
        if kind in 'tT':
            e = next((x for x in c.effects(s) if x['index'] == int(idx or 1) - 1), None)
            return e['period'] / 1000 if e and e['period'] else None
        return None

    def fmt(v):
        if isinstance(v, tuple):
            return f'{round(v[0])} to {round(v[1])}'
        return '?' if v is None else (f'{round(v)}' if abs(v) >= 10 else f'{round(v, 1):g}')

    tok = re.compile(r'\$(?:/(\d+);)?(\d{3,})?([a-zA-Z])(\d?)')

    def tok_value(m):
        v = value(m.group(2), m.group(3), m.group(4))
        if v is not None and m.group(1):
            d = int(m.group(1))
            v = (v[0] / d, v[1] / d) if isinstance(v, tuple) else v / d
        return v

    def expr(m):
        bad = []
        def sub(mm):
            v = tok_value(mm)
            if v is None:
                bad.append(1)
                return '0'
            return str((v[0] + v[1]) / 2 if isinstance(v, tuple) else v)
        py = tok.sub(sub, m.group(1))
        if bad or not re.fullmatch(r'[\d.+\-*/() ]+', py):
            return '?'
        try:
            return fmt(eval(py, {'__builtins__': {}}))
        except Exception:
            return '?'

    def plain(m):
        v = tok_value(m)
        if v is None:
            return '?'
        return f'{v:g} sec' if m.group(3) in 'dD' else (f'{v:g}' if m.group(3) in 'tT' else fmt(v))

    text = re.sub(r'\$@spelldesc(\d+)', lambda m: describe(c, int(m.group(1)), depth + 1) if depth < 2 else '', text)
    text = re.sub(r'\$@spellicon\d+', '', text)
    text = re.sub(r'\$\?[!a-z0-9&|()]+\[([^\]]*)\]\[([^\]]*)\]', lambda m: m.group(2), text)
    text = re.sub(r'\$\?[!a-z0-9&|()]+\[([^\]]*)\]', '', text)
    text = re.sub(r'\$[lL]([^:;]*):([^;]*);', lambda m: m.group(2), text)
    text = re.sub(r'\$[gG]([^:;]*):([^;]*);', lambda m: m.group(1), text)
    text = re.sub(r'\*?\$<[a-z0-9_]+>', '', text)
    text = re.sub(r'\$\{([^}]*)\}(?:\.\d)?', expr, text)
    return re.sub(r'\s+\n', '\n', tok.sub(plain, text)).strip()


# --------------------------------------------------------------------------------------------- the database

def class_spells(t, c):
    """(class, spell id) -> skill line name, from SkillLineAbility rows on the class skill lines, and the set of those
    the client marks "never learned". An unranked "never learned" spell is kept only when a talent teaches it (the
    rest are leftovers such as Season of Discovery runes); a ranked one stays, and loses to a learnable spell of the
    same rank later. Spells a learned talent swaps in are added beside the talent."""
    lines = {r['ID']: r for r in t['SkillLine'] if r.get('CategoryID') == '7' and r['DisplayName_lang'] not in SKIP_LINES}
    owner = collections.defaultdict(collections.Counter)  # a line's class, from its rows that name one
    for r in t['SkillLineAbility']:
        if r['SkillLine'] in lines and n(r['ClassMask']):
            for cls, bit in CLASS_BITS.items():
                if n(r['ClassMask']) & bit:
                    owner[r['SkillLine']][cls] += 1
    if c.talents is None:
        print('  TraitDefinition unavailable: keeping spells the client marks as never learned', file=sys.stderr)
    out, acquire = {}, {}  # acquire: 0 = trainer, 1 = automatic, 2 = never learned
    for r in t['SkillLineAbility']:
        line = lines.get(r['SkillLine'])
        if not line:
            continue
        never = r.get('AcquireMethod') == ACQUIRE_NEVER_LEARNED
        ranked = (c.rank.get(n(r['Spell'])) or '').startswith('Rank ')
        if never and not ranked and c.talents is not None and n(r['Spell']) not in c.talents:
            continue
        acquire[n(r['Spell'])] = min(acquire.get(n(r['Spell']), 9), {'0': 0, '1': 1, '2': 1, '4': 1}.get(r.get('AcquireMethod'), 2))
        name = line['DisplayName_lang']
        mask = n(r['ClassMask'])
        classes = [cls for cls, bit in CLASS_BITS.items() if mask & bit]
        if name.startswith('Pet - '):
            classes = classes or ['warlock' if name[6:] in WARLOCK_PETS else 'hunter']
            name = 'Pet: ' + name[6:]
        elif not classes and owner[r['SkillLine']]:
            classes = [owner[r['SkillLine']].most_common(1)[0][0]]
        for cls in classes:
            out.setdefault((cls, n(r['Spell'])), name)
    # A spell a talent swaps in belongs to the class only if that talent does; one whose talent is not learnable
    # here (a Season of Discovery rune) is a leftover.
    member_ids = {sid for (_, sid) in out}
    for (cls, sid), name in list(out.items()):
        old, talent = c.overrides.get(sid, (0, 0))
        if talent and talent not in member_ids and acquire.get(sid) == 2:
            del out[(cls, sid)]
    for new, (old, talent) in c.overrides.items():
        for (cls, sid), name in list(out.items()):
            if sid == talent:
                out.setdefault((cls, new), name)
                acquire.setdefault(new, acquire.get(talent, 0))
    return out, acquire


def totals(parts, hits):
    t = collections.defaultdict(lambda: [0.0, 0.0])
    for p in parts:
        if not p['inTotal']:
            continue
        mult = p['ticks'] if p['kind'] == 'periodic' and p.get('ticks') else (hits if p['kind'] == 'direct' else 1)
        t[p['category']][0] += (p['sp'] or 0) * mult
        t[p['category']][1] += (p['ap'] or 0) * mult
    return {k: dict(sp=rd(v[0]), ap=rd(v[1])) for k, v in t.items() if v[0] or v[1]}


def build(fc, ft, era):
    members, acquire = class_spells(ft, fc)
    member_ids = {sid for (_, sid) in members}
    rows = {}
    for (cls, sid), tree in members.items():
        if not fc.has(sid):
            continue
        parts = parts_of(fc, sid)
        if parts:
            name = fc.names.get(sid, str(sid))
            old, talent = fc.overrides.get(sid, (0, 0))
            if old and talent in member_ids and fc.names.get(old) == name and fc.names.get(talent) and fc.names[talent] != name:
                name = f'{name} ({fc.names[talent]})'  # the version a talent swaps in, e.g. Exorcism (Exorcist)
            rows[(cls, sid)] = dict(cls=cls, id=sid, tree=tree, name=name, parts=parts)

    # A seal's judgement is its own ability: give it a row, so the seal shows it without counting it.
    for r in list(rows.values()):
        for p in r['parts']:
            name = fc.names.get(p['spell'], '')
            if p['spell'] != r['id'] and name.startswith('Judgement of ') and (r['cls'], p['spell']) not in rows:
                rows[(r['cls'], p['spell'])] = dict(cls=r['cls'], id=p['spell'], tree=r['tree'], name=name, parts=parts_of(fc, p['spell']))

    # Where a rank has several candidate spells, keep the one a trainer teaches, else one learned automatically.
    by_rank = collections.defaultdict(list)
    for key, r in rows.items():
        rank = fc.rank.get(r['id']) or ''
        if rank.startswith('Rank '):
            by_rank[(r['cls'], r['name'], rank)].append(key)
    for keys in by_rank.values():
        best = min(acquire.get(k[1], 0) for k in keys)
        for k in keys:
            if acquire.get(k[1], 0) > best:
                del rows[k]

    # Drop rows that only restate another row's parts: "X Effect" pieces of X, a spell of the same name that
    # another rank triggers, and passive talents that only point at abilities.
    covered = collections.defaultdict(lambda: collections.defaultdict(set))
    for r in rows.values():
        for p in r['parts']:
            if p['spell'] != r['id']:
                covered[r['cls']][p['spell']].add(r['name'])
    ids_by_class = collections.defaultdict(set)
    for (cls, sid) in rows:
        ids_by_class[cls].add(sid)
    for key, r in list(rows.items()):
        by = covered[r['cls']].get(r['id'], set())
        if any(r['name'].startswith(x) for x in by):
            del rows[key]
        elif fc.info(r['id'])['passive'] and all(p['spell'] != r['id'] and p['spell'] in ids_by_class[r['cls']] for p in r['parts']):
            del rows[key]
    names_by_class = collections.defaultdict(set)
    for r in rows.values():
        names_by_class[r['cls']].add(r['name'])

    for r in rows.values():
        hits = HITS_PER_CAST.get(r['name'], 1)
        totem = r['name'].endswith('Totem')
        for p in r['parts']:
            linked = fc.names.get(p['spell'], '')
            if p['spell'] != r['id'] and linked != r['name'] and linked in names_by_class[r['cls']]:
                p['relation'] = 'separateAbility'  # a seal's judgement: shown, not added to the seal's total
            if totem and p['spell'] != r['id'] and p['kind'] in ('direct', 'periodic') and not p.get('ticks'):
                p['kind'] = 'periodic'
                p['label'] = {'damage': 'Damage per pulse', 'heal': 'Heal per pulse'}.get(p['category'], p['label'])
            p['inTotal'] = p['kind'] in ('direct', 'periodic') and bool(p['category']) and p['relation'] != 'separateAbility'
        r['hits'] = hits

    # Scaling the client lacks but Blizzard's notes state.
    notes = collections.defaultdict(list)
    server = {}
    for cls, name, (where, ident), field, value, date, text in SERVER_SCALING:
        for r in rows.values():
            if r['cls'] != cls or r['name'] != name:
                continue
            for p in r['parts']:
                e = next((x for x in fc.effects(p['spell']) if x['index'] == p['effectIndex']), None)
                if e and (e['aura'] if where == 'aura' else e['effect']) == ident and not p[field]:
                    p[field] = value
                    p['inTotal'] = True
                    server[(p['spell'], p['effectIndex'])] = (field, value, f'notes-{date}')
                    notes[r['id']].append(dict(source=f'notes-{date}', text=text))
                    break
    for cls, name, date, text in TEXT_NOTES:
        for r in rows.values():
            if r['cls'] == cls and r['name'] == name:
                notes[r['id']].append(dict(source=f'notes-{date}', text=text))

    # Assemble the spells, keyed by id.
    spells = {}
    part_of = collections.defaultdict(set)
    for r in rows.values():
        for p in r['parts']:
            if p['spell'] != r['id']:
                part_of[p['spell']].add(r['id'])

    def era_record(sid):
        if not era or not era.has(sid):
            return None
        info = era.info(sid)
        effs = [effect_record(era, sid, e, info['levels'], info['school'], info['dur']) for e in era.effects(sid)]
        ps = parts_of(era, sid)
        for p in ps:
            p['inTotal'] = p['kind'] in ('direct', 'periodic') and bool(p['category'])
        t = totals(ps, 1)
        sp = next((t[k]['sp'] for k in ('damage', 'heal', 'absorb') if k in t and t[k]['sp']), 0)
        keep = ('index', 'effect', 'aura', 'basePoints', 'basePointsMax', 'pointsPerLevel', 'spCoef', 'apCoef', 'periodMs')
        return dict(build=era.build, perCastSp=sp, effects=[{k: e[k] for k in keep if k in e} for e in effs])

    def record(sid):
        info = fc.info(sid)
        rank = fc.rank.get(sid) or None
        m = re.search(r'(\d+)', rank or '')
        rec = dict(id=sid, name=fc.names.get(sid), rank=rank, rankNumber=int(m.group(1)) if m and rank.startswith('Rank') else None,
                   roles=[], dataSource=f'client-{fc.build}', school=SCHOOLS.get(info['school'], 'Multi' if info['school'] else None),
                   schoolMask=info['school'] or None, levels=info['levels'], castTimeMs=info['cast'], channeled=info['channeled'],
                   durationMs=info['dur'] or None, cooldownMs=info['cd'], categoryCooldownMs=info['ccd'], gcdMs=info['gcd'],
                   rangeYards=info['range'], projectileSpeed=rd(info['speed']) or None, costs=info['costs'])
        effs = []
        for e in fc.effects(sid):
            er = effect_record(fc, sid, e, info['levels'], info['school'] or 0, info['dur'])
            if (sid, e['index']) in server:
                field, value, src = server[(sid, e['index'])]
                key = 'spCoef' if field == 'sp' else 'apCoef'
                er['coefClient'] = er.get(key, 0)
                er[key] = value
                er['coefSource'] = src
            effs.append(er)
        rec['effects'] = effs
        desc = describe(fc, sid)
        rec['description'] = desc or None
        rec['descriptionTemplate'] = fc.desc.get(sid) or None
        rec['attributes'] = info['attr'] or None
        return rec

    for r in sorted(rows.values(), key=lambda r: r['id']):
        sid = r['id']
        rec = spells.get(sid) or record(sid)
        rec['roles'].append('ability')
        rec.update({'class': r['cls'], 'ability': r['name'], 'tree': r['tree']})
        parts = [{k: v for k, v in p.items() if v is not None and k != 'school'} for p in r['parts']]
        rec['parts'] = parts
        rec['perCast'] = totals(r['parts'], r['hits'])
        rec['perCastIsPerTick'] = any(p['kind'] == 'periodic' and not p.get('ticks') and p['inTotal'] and (p['sp'] or p['ap']) for p in r['parts'])
        rec['hitsPerCast'] = r['hits'] if r['hits'] > 1 else None
        scripted = [p['sp'] for p in r['parts'] if p['kind'] == 'dummy' and p['sp'] and p['spell'] == sid]
        if scripted and not rec['perCast'] and not any(p['category'] for p in r['parts']):
            rec['scriptedCoefficient'] = max(scripted)
        rec['notes'] = notes.get(sid) or None
        spells[sid] = rec
    for sid, parents in part_of.items():
        rec = spells.get(sid) or record(sid)
        if 'ability' not in rec['roles']:
            rec['roles'].append('part')
        rec['partOf'] = sorted(parents)
        spells[sid] = rec
    for sid, rec in spells.items():
        rec['era'] = era_record(sid)

    order = ['id', 'name', 'rank', 'rankNumber', 'roles', 'class', 'ability', 'tree', 'dataSource', 'school', 'schoolMask', 'levels',
             'castTimeMs', 'channeled', 'durationMs', 'cooldownMs', 'categoryCooldownMs', 'gcdMs', 'rangeYards', 'projectileSpeed', 'costs',
             'perCast', 'perCastIsPerTick', 'hitsPerCast', 'scriptedCoefficient', 'parts', 'partOf', 'effects', 'description',
             'descriptionTemplate', 'notes', 'era', 'attributes']
    out = {}
    for sid in sorted(spells):
        rec = spells[sid]
        row = {k: rec.get(k) for k in order}
        out[str(sid)] = {k: v for k, v in row.items() if v is not None and v != '' and v != []}

    abilities = collections.defaultdict(lambda: collections.defaultdict(list))
    for sid, rec in out.items():
        if 'ability' in rec['roles']:
            abilities[rec['class']][rec['ability']].append(int(sid))
    abilities = {cls: {a: sorted(ids, key=lambda i: (out[str(i)].get('rankNumber') or 0, (out[str(i)].get('levels') or {}).get('base', 0), i))
                       for a, ids in sorted(v.items())} for cls, v in sorted(abilities.items())}
    return out, abilities


def changes(old, new):
    """What moved between two outputs: added and removed ability ranks, and changed numbers per effect."""
    o, nw = old.get('spells', {}), new
    lines = []
    for sid in sorted(set(nw) | set(o), key=int):
        a, b = o.get(sid), nw.get(sid)
        label = (b or a).get('name', sid) + (f" {(b or a).get('rank')}" if (b or a).get('rank') else '') + f' ({sid})'
        if a is None:
            if 'ability' in b.get('roles', []):
                lines.append(f'new: {label}')
            continue
        if b is None:
            if 'ability' in a.get('roles', []):
                lines.append(f'removed: {label}')
            continue
        ea = {e['index']: e for e in a.get('effects', [])}
        for e in b.get('effects', []):
            p = ea.get(e['index'])
            if not p:
                continue
            for k in ('spCoef', 'apCoef', 'basePoints', 'variance', 'pointsPerLevel', 'periodMs'):
                if p.get(k) != e.get(k):
                    lines.append(f"{label} effect {e['index']} {k}: {p.get(k)} -> {e.get(k)}")
        for k in ('castTimeMs', 'durationMs', 'cooldownMs', 'categoryCooldownMs'):
            if a.get(k) != b.get(k):
                lines.append(f'{label} {k}: {a.get(k)} -> {b.get(k)}')
        ca, cb = [c.get('amount') for c in a.get('costs', [])], [c.get('amount') for c in b.get('costs', [])]
        if ca != cb:
            lines.append(f'{label} cost: {ca} -> {cb}')
        if a.get('levels') != b.get('levels'):
            lines.append(f"{label} levels: {a.get('levels')} -> {b.get('levels')}")
    return lines


META_FIELDS = {
    'spells': 'Keyed by spell ID. Every class ability rank, and every spell an ability hands its damage or healing to.',
    'roles': '"ability": a rank a player learns. "part": a spell another ability triggers or its tooltip reads from.',
    'parts': 'The effects that carry an ability\'s scaling: {spell, effectIndex} points into spells[spell].effects. relation: absent = '
             'the spell itself, "triggered", "tooltipLinked", or "separateAbility" (another ability, e.g. a seal\'s judgement). '
             'inTotal says whether perCast counts it.',
    'perCast': '{damage|heal|absorb: {sp, ap}}: parts with inTotal summed, periodic parts times ticks, direct parts times hitsPerCast. '
               'perCastIsPerTick = a periodic part has no tick count in the data (totem pulses).',
    'basePoints': 'The effect amount at levels.base, before variance. Era rows give basePoints..basePointsMax instead of variance.',
    'variance': 'Total spread as a fraction of basePoints: a roll lands in mean +/- basePoints * variance / 2.',
    'pointsPerLevel': 'Added per caster level above levels.base, up to levels.max.',
    'spCoef': 'Spell power coefficient as used: 0 where the client\'s 1.0 means "unset" (spCoefRaw then keeps it).',
    'apCoef': 'Attack power coefficient.',
    'coefSource': '"client", or "notes-<date>" for a value from Blizzard\'s beta development notes the client lacks (coefClient keeps the client value).',
    'atLevel60': 'Base amount for a level-60 caster: {min, mean, max}, before spell power and modifiers.',
    'ticks': 'durationMs // periodMs for periodic auras.',
    'implicitTargets': 'ImplicitTarget A and B: 1 = caster, 6 = enemy target, 22/15 = area around the caster, 87/16 = area at a location.',
    'attributes': 'SpellMisc.Attributes[0..16], raw bitfields.',
}
FORMULA = dict(
    perEffect=['levelsGained = clamp(min(casterLevel, levels.max) - levels.base, 0)',
               'mean = basePoints + pointsPerLevel * levelsGained',
               'roll = uniform(mean - basePoints * variance / 2, mean + basePoints * variance / 2)',
               'amount = roll + spCoef * spellPower(school) + apCoef * attackPower',
               'then talents, buffs and target modifiers, then critical strike, then round to a whole number'],
    healing='Spell power for healing is bonus healing, which in Forever includes one third of bonus spell damage.',
    periodic='Run per tick; ticks = durationMs // periodMs.', chain='Each jump multiplies by chainAmplitude.',
    unknowns=['Where rounding happens.', 'Whether variance spreads the unscaled basePoints or the grown mean.',
              'Which of levels.spell and levels.base growth counts from where they differ.',
              'The downranking penalty on spell power for ranks far below your level (confirmed in the Oct 1 notes, formula unpublished).',
              'Server-scripted effects (dummy effects, seals, area target caps).'],
)


def database(build_v=None, era_v=None, no_era=False, cache=CACHE, offline=False, previous=None):
    """The database as a dict {meta, abilities, spells}: the newest builds on wago.tools unless given."""
    if not build_v or (not era_v and not no_era):
        if offline:
            cached = sorted(os.listdir(cache), key=version_key) if os.path.isdir(cache) else []
            build_v = build_v or next((b for b in reversed(cached) if re.match(r'1\.6\d\.', b)), None)
            era_v = era_v or next((b for b in reversed(cached) if b.startswith('1.15.')), None)
        else:
            newest_f, newest_e = newest_builds()
            build_v, era_v = build_v or newest_f, era_v or newest_e
    if not build_v:
        sys.exit('No Forever build found. Pass --build.')
    print(f'Forever build {build_v}' + ('' if no_era or not era_v else f', Classic Era {era_v}'), file=sys.stderr)

    ft = load_tables(FOREVER_TABLES, build_v, cache, offline)
    fc = Client(build_v, ft)
    era = None
    if not no_era and era_v:
        era = Client(era_v, load_tables(ERA_TABLES, era_v, cache, offline))
    spells, abilities = build(fc, ft, era)

    ranks = sum(1 for s in spells.values() if 'ability' in s['roles'])
    meta = dict(title='WoW Forever spell metadata', generated=datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds'),
                clientBuild=build_v, eraBuild=era_v if era else None, hotfixes='not included (wago.tools serves tables as shipped)',
                counts=dict(spells=len(spells), abilityRanks=ranks, partsOnly=len(spells) - ranks,
                            abilities=sum(len(v) for v in abilities.values())),
                sources={'client': f'{WAGO}/db2?build={build_v}', 'era': f'{WAGO}/db2?build={era_v}' if era else None,
                         'notes': NOTES_URL},
                fields=META_FIELDS, formula=FORMULA)
    if previous and os.path.exists(previous):
        old = json.load(open(previous, encoding='utf-8'))
        diff = changes(old, spells)
        meta['changesSincePrevious'] = dict(previousBuild=old.get('meta', {}).get('clientBuild'), changes=diff)
        print(f'{len(diff)} changes since {previous}' + ''.join(f'\n  {d}' for d in diff[:40]) +
              (f'\n  ... and {len(diff) - 40} more (see meta.changesSincePrevious)' if len(diff) > 40 else ''), file=sys.stderr)
    return dict(meta={k: v for k, v in meta.items() if v is not None}, abilities=abilities, spells=spells)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--build', help='Forever build, e.g. 1.60.1.70425 (default: newest on wago.tools)')
    ap.add_argument('--era-build', help='Classic Era build to compare with (default: newest on wago.tools)')
    ap.add_argument('--no-era', action='store_true', help='skip the Classic Era comparison')
    ap.add_argument('--cache', default=CACHE, help=f'download cache directory (default: {CACHE})')
    ap.add_argument('--offline', action='store_true', help='use only cached tables')
    ap.add_argument('--previous', help='an earlier output to compare with')
    ap.add_argument('--out', default='forever_spells.json')
    args = ap.parse_args()

    result = database(args.build, args.era_build, args.no_era, args.cache, args.offline, args.previous)
    with open(args.out + '.part', 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=1, ensure_ascii=False)
    os.replace(args.out + '.part', args.out)
    counts = result['meta']['counts']
    print(f"Wrote {args.out}: {counts['abilities']} abilities, {counts['abilityRanks']} ranks, {counts['spells']} spells", file=sys.stderr)


if __name__ == '__main__':
    main()
