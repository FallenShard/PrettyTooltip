"""The client's tooltip language, read exactly: a spell's description template and its
variables, parsed without eval, and each number the tooltip prints as a range plus
spell power, attack power or weapon terms, per talent and stance branch.

Tokens: $s1 $m1 $M1 $o1 $b1 $t1 $a1 $x1 $d $n $u $i $r, optionally after a spell ID
($25912s1), divided or multiplied ($/2;20467s1, $*3;s1); ${expression}, with .N for
decimals; $<variable>; stat symbols ($SPH, $SPFR, $apm, $rap, $bh, $bc, $mcrit, $PL,
$MW ...); conditions $?s123[then][else], with a, p and c atoms, !, &, |, parentheses and
else-if ($?s1[..]?s2[..][..]); plurals and genders ($lone:many;, $gmale:female;); and
$@spelldesc / $@spellname / $@spellicon.

$s and $o print an effect's amount with its spell power and attack power share
included. $m and $M name its base points, and a weapon percent its percent: what their
effect adds is kept apart as hidden terms. tools/make_spell_parts.py decides which of
those the game prints in (base points' share: yes, checked on Frostbolt in game). A talent's value ($11189s3) is
its rank's, from the trait curves, so it is a condition on the player's rank. A value that
is not linear in the stats (a stat times a stat, a stat in a divisor) raises NonLinear, so
a spell this cannot read exactly is named, never guessed.
"""

import itertools
import re

LEVEL = 60
EPSILON = 1e-9

# Stat symbols a formula can name, longest first, and what each stands for.
STATS = {
    'SPFI': 'spell:Fire', 'SPFR': 'spell:Frost', 'SPN': 'spell:Nature', 'SPS': 'spell:Shadow',
    'SPA': 'spell:Arcane', 'SPH': 'spell:Holy', 'SP': 'spell', 'sph': 'spell:Holy', 'sps': 'spell:Shadow',
    'AP': 'ap', 'apm': 'ap', 'RAP': 'rap', 'rap': 'rap', 'bh': 'heal', 'mcrit': 'crit',
    'MWS': 'weaponSpeed', 'MWB': 'weaponBaseMax', 'mwb': 'weaponBaseMin', 'MW': 'weaponMax', 'mw': 'weaponMin',
}
STAT_NAMES = sorted(STATS, key=len, reverse=True)
SCHOOLS = {1: 'Physical', 2: 'Holy', 4: 'Fire', 8: 'Nature', 16: 'Frost', 32: 'Shadow', 64: 'Arcane'}
# Effects and auras whose amount scales with bonus healing rather than spell damage.
HEAL_EFFECTS, HEAL_AURAS = {10}, {8, 69}
WEAPON_PERCENT = 31
REF_KINDS = 'smMobtaxdnuir'


class FormulaError(ValueError):
    pass


class NonLinear(FormulaError):
    pass


def _merge(a, b, scale=1.0):
    out = dict(a)
    for k, v in b.items():
        out[k] = out.get(k, 0) + v * scale
    return out


class Value:
    """lo..hi, a constant range, plus terms {stat: coefficient} the printed number includes,
    hidden terms it does not, and refs: the effects it read."""
    __slots__ = ('lo', 'hi', 'terms', 'hidden', 'refs')

    def __init__(self, lo, hi=None, terms=None, refs=(), hidden=None):
        self.lo = float(lo)
        self.hi = float(lo if hi is None else hi)
        self.terms = {k: v for k, v in (terms or {}).items() if abs(v) > EPSILON}
        self.hidden = {k: v for k, v in (hidden or {}).items() if abs(v) > EPSILON}
        self.refs = frozenset(refs)

    @property
    def is_scalar(self):
        return abs(self.hi - self.lo) < EPSILON and not self.terms and not self.hidden

    @property
    def scales(self):
        return bool(self.terms or self.hidden)

    @property
    def is_range(self):
        return abs(self.hi - self.lo) >= EPSILON

    def __add__(self, other):
        other = lift(other)
        return Value(self.lo + other.lo, self.hi + other.hi, _merge(self.terms, other.terms),
                     self.refs | other.refs, _merge(self.hidden, other.hidden))

    def __neg__(self):
        return Value(-self.hi, -self.lo, _merge({}, self.terms, -1), self.refs, _merge({}, self.hidden, -1))

    def __sub__(self, other):
        return self + -lift(other)

    def __mul__(self, other):
        other = lift(other)
        refs = self.refs | other.refs
        for a, b in ((self, other), (other, self)):
            if a.is_scalar:
                k = a.lo
                lo, hi = sorted((b.lo * k, b.hi * k))
                return Value(lo, hi, _merge({}, b.terms, k), refs, _merge({}, b.hidden, k))
        if self.scales or other.scales:
            raise NonLinear('a stat times a range or another stat')
        products = [x * y for x in (self.lo, self.hi) for y in (other.lo, other.hi)]
        return Value(min(products), max(products), None, refs)

    def __truediv__(self, other):
        other = lift(other)
        if not other.is_scalar:
            raise NonLinear('a divisor that is a range or a stat')
        if abs(other.lo) < EPSILON:
            raise FormulaError('division by zero')
        return self * Value(1 / other.lo, refs=other.refs)

    def mean(self):
        return (self.lo + self.hi) / 2

    def __repr__(self):
        terms = ''.join(f' + {v:g}*{k}' for k, v in sorted(self.terms.items()))
        terms += ''.join(f' (+ {v:g}*{k} unprinted)' for k, v in sorted(self.hidden.items()))
        span = f'{self.lo:g}' if not self.is_range else f'{self.lo:g}..{self.hi:g}'
        return f'Value({span}{terms})'


def lift(value):
    return value if isinstance(value, Value) else Value(value)


# ------------------------------------------------------------------------------------------ parsing

class Text:
    __slots__ = ('text',)

    def __init__(self, text):
        self.text = text


class Number:
    """A token that prints a number: an effect reference, an expression, or a variable."""
    __slots__ = ('source', 'expr', 'decimals', 'kind')

    def __init__(self, source, expr, kind, decimals=None):
        self.source, self.expr, self.kind, self.decimals = source, expr, kind, decimals


class Cond:
    __slots__ = ('cond', 'then', 'other')

    def __init__(self, cond, then, other):
        self.cond, self.then, self.other = cond, then, other


class Choice:
    """$lone:many; or $gmale:female;: a word, never a number."""
    __slots__ = ('options',)

    def __init__(self, options):
        self.options = options


class Include:
    """$@spelldesc123: another spell's description, in place."""
    __slots__ = ('what', 'spell')

    def __init__(self, what, spell):
        self.what, self.spell = what, spell


REF = re.compile(r'(\d+)?([a-zA-Z])(\d)?')


def _ref(text, pos):
    """An effect or spell reference at pos (after the $): (node expression, end) or None."""
    m = REF.match(text, pos)
    if not m or m.group(2) not in REF_KINDS:
        return None
    spell, kind, index = m.group(1), m.group(2), m.group(3)
    # $10436r takes no index; a run of ASCII letters is a stat or a word, not a reference
    # ("$s1의" in Korean is one).
    nxt = text[m.end():m.end() + 1]
    if nxt.isascii() and nxt.isalpha():
        return None
    return ('ref', int(spell) if spell else None, kind, int(index) if index else None), m.end()


def _word(char):
    return char.isascii() and char.isalnum()


def _stat(text, pos):
    for name in STAT_NAMES:
        if text.startswith(name, pos) and not _word(text[pos + len(name):pos + len(name) + 1]):
            return ('stat', STATS[name]), pos + len(name)
    for name in ('PL', 'pl', 'bc'):
        if text.startswith(name, pos) and not _word(text[pos + len(name):pos + len(name) + 1]):
            return ('level',) if name in ('PL', 'pl') else ('bc',), pos + len(name)
    return None


def _brackets(text, pos):
    """The text inside [ ... ] starting at pos, nested brackets kept: (inner, end)."""
    if pos >= len(text) or text[pos] != '[':
        raise FormulaError(f'expected [ at {pos}: {text[pos:pos + 20]!r}')
    depth, i = 0, pos
    while i < len(text):
        if text[i] == '[':
            depth += 1
        elif text[i] == ']':
            depth -= 1
            if depth == 0:
                return text[pos + 1:i], i + 1
        i += 1
    raise FormulaError('unclosed [')


COND_ATOM = re.compile(r'(!?)\$?([a-zA-Z])(\d+)')


def _condition(text, pos):
    """A condition after $?, up to its [: (ast, end). Atoms: s known spell, a aura, p, c."""
    end = text.index('[', pos)
    source = text[pos:end]
    tokens = re.findall(r'!?\$?[a-zA-Z]\d+|[&|()!]', source)
    if ''.join(tokens) != source.replace(' ', ''):
        raise FormulaError(f'unknown condition {source!r}')
    tokens = iter(tokens + [None])
    current = [next(tokens)]

    def take():
        token = current[0]
        current[0] = next(tokens)
        return token

    def unary():
        token = take()
        if token == '!':
            return ('not', unary())
        if token == '(':
            node = either()
            if take() != ')':
                raise FormulaError(f'unbalanced condition {source!r}')
            return node
        m = COND_ATOM.fullmatch(token or '')
        if not m:
            raise FormulaError(f'unknown condition {source!r}')
        atom = ('atom', m.group(2).lower(), int(m.group(3)))
        return ('not', atom) if m.group(1) else atom

    def both():
        node = unary()
        while current[0] == '&':
            take()
            node = ('and', node, unary())
        return node

    def either():
        node = both()
        while current[0] == '|':
            take()
            node = ('or', node, both())
        return node

    node = either()
    if current[0] is not None:
        raise FormulaError(f'unknown condition {source!r}')
    return node, end


def parse(text):
    """A description or variable value as a list of nodes."""
    nodes, buffer, i = [], [], 0

    def flush():
        if buffer:
            nodes.append(Text(''.join(buffer)))
            buffer.clear()

    while i < len(text):
        c = text[i]
        if c != '$':
            buffer.append(c)
            i += 1
            continue
        j = i + 1
        if j >= len(text):
            buffer.append(c)
            break
        n = text[j]
        if n == '$':  # an escaped sign before a token: the token still prints
            i = j
            continue
        flush()
        if n == '{':
            expr, end = _expression_block(text, j)
            decimals = None
            m = re.match(r'\.(\d)', text[end:])
            if m:
                decimals, end = int(m.group(1)), end + 2
            nodes.append(Number(text[i:end], expr, 'amount', decimals))
            i = end
        elif n == '<':
            end = text.index('>', j)
            nodes.append(Number(text[i:end + 1], ('var', text[j + 1:end]), 'amount'))
            i = end + 1
        elif n == '?':
            branches, other, k = [], [], j
            while True:
                cond, k = _condition(text, k + 1)
                then, k = _brackets(text, k)
                branches.append((cond, parse(then)))
                if k < len(text) and text[k] == '?' and re.match(r'\?!?\$?[a-zA-Z(]', text[k:]):
                    continue
                if k < len(text) and text[k] == '[':
                    inner, k = _brackets(text, k)
                    other = parse(inner)
                break
            for cond, then in reversed(branches):
                other = [Cond(cond, then, other)]
            nodes.extend(other)
            i = k
        elif n in 'lLgG' and re.match(r'[^;$\[\]]*;', text[j + 1:]):
            end = text.index(';', j)
            nodes.append(Choice(text[j + 1:end].split(':')))
            i = end + 1
        elif n in 'lLgG' and not text[j + 1:j + 2].isascii():
            # Chinese leaves the ; out: "$l目标]" ends at its branch's bracket.
            m = re.match(r'[^;$\[\]\s]*', text[j + 1:])
            nodes.append(Choice(m.group(0).split(':')))
            i = j + 1 + m.end()
        elif n == '@':
            m = re.match(r'@(spelldesc|spellname|spellicon|spelltooltip)(\d+)|@null', text[j:])
            if not m:
                raise FormulaError(f'unknown include {text[i:i + 20]!r}')
            if m.group(1):  # $@null (Korean "X$@null~Y") prints nothing
                nodes.append(Include(m.group(1), int(m.group(2))))
            i = j + m.end()
        elif n in '/*' and re.match(r'[/*]\d+;', text[j:]):
            m = re.match(r'([/*])(\d+);', text[j:])
            ref = _ref(text, j + m.end())
            if not ref:
                raise FormulaError(f'unknown token {text[i:i + 20]!r}')
            expr = ('div' if m.group(1) == '/' else 'mul', ref[0], ('num', float(m.group(2))))
            nodes.append(Number(text[i:ref[1]], expr, 'amount'))
            i = ref[1]
        else:
            stat = _stat(text, j)
            ref = None if stat else _ref(text, j)
            if stat:
                nodes.append(Number(text[i:stat[1]], stat[0], 'amount'))
                i = stat[1]
            elif ref:
                kind = ref[0][2]
                nodes.append(Number(text[i:ref[1]], ref[0], 'duration' if kind in 'dD' else
                                    'amount' if kind in 'smMob' else 'count'))
                i = ref[1]
            else:
                raise FormulaError(f'unknown token {text[i:i + 20]!r}')
    flush()
    return nodes


def _expression_block(text, pos):
    """${ ... } at pos (the {): (expression, end)."""
    depth, i = 0, pos
    while i < len(text):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return expression(text[pos + 1:i]), i + 1
        i += 1
    raise FormulaError('unclosed ${')


def expression(source):
    """Arithmetic over numbers, references, variables and stats: + - * / and parentheses."""
    tokens, i = [], 0
    while i < len(source):
        c = source[i]
        if c.isspace():
            i += 1
        elif c.isdigit() or (c == '.' and source[i + 1:i + 2].isdigit()):
            m = re.match(r'\d*\.?\d+', source[i:])
            tokens.append(('num', float(m.group(0))))
            i += m.end()
        elif c in '+-*/()':
            tokens.append(c)
            i += 1
        elif c == '$':
            if source[i + 1:i + 2] == '*':  # "$m2$*$<x>": the client reads $* as times
                tokens.append('*')
                i += 2
                continue
            if source[i + 1:i + 2] == '<':
                end = source.index('>', i)
                tokens.append(('var', source[i + 2:end]))
                i = end + 1
                continue
            stat = _stat(source, i + 1)
            ref = None if stat else _ref(source, i + 1)
            if stat:
                tokens.append(stat[0])
                i = stat[1]
            elif ref:
                tokens.append(ref[0])
                i = ref[1]
            else:
                raise FormulaError(f'unknown token in expression {source[i:i + 20]!r}')
        else:
            raise FormulaError(f'unknown character {c!r} in expression {source!r}')
    tokens.append(None)
    pos = [0]

    def peek():
        return tokens[pos[0]]

    def take():
        token = tokens[pos[0]]
        pos[0] += 1
        return token

    def atom():
        token = take()
        if token == '(':
            node = sums()
            if take() != ')':
                raise FormulaError(f'unbalanced expression {source!r}')
            return node
        if token == '-':
            return ('neg', atom())
        if token == '+':
            return atom()
        if isinstance(token, tuple):
            return token
        raise FormulaError(f'unexpected {token!r} in expression {source!r}')

    def products():
        node = atom()
        while peek() in ('*', '/'):
            op = take()
            node = ('mul' if op == '*' else 'div', node, atom())
        return node

    def sums():
        node = products()
        while peek() in ('+', '-'):
            op = take()
            node = ('add' if op == '+' else 'sub', node, products())
        return node

    node = sums()
    # The client ignores a stray closing parenthesis: Prayer of Mending's "${$1225132m1/100+1)}".
    while peek() == ')':
        take()
    if peek() is not None:
        raise FormulaError(f'trailing {peek()!r} in expression {source!r}')
    return node


def parse_variables(text):
    """A SpellDescriptionVariables block as {name: nodes}."""
    out = {}
    for line in re.split(r'[\r\n]+', text or ''):
        line = line.strip()
        if not line:
            continue
        m = re.match(r'\$([A-Za-z0-9_]+)\s*=\s*(.*)$', line)
        if not m:
            raise FormulaError(f'unknown variable line {line!r}')
        out[m.group(1)] = parse(m.group(2))
    return out


# --------------------------------------------------------------------------------------- evaluating

def atoms_of(node, variables, seen=None, talents=None, sid=None):
    """The conditions a node list depends on, through its variables: ('atom', kind, id) for
    $?s / $?a checks, ('rank', 'r', talent) for a talent's value."""
    seen = seen if seen is not None else set()
    talents = talents or {}
    found = []

    def walk_expr(e):
        if not isinstance(e, tuple):
            return
        if e[0] == 'var' and e[1] not in seen:
            seen.add(e[1])
            for a in atoms_of(variables.get(e[1], []), variables, seen, talents, sid):
                if a not in found:
                    found.append(a)
        if e[0] == 'ref' and (e[1] or sid) in talents and e[2] in 'smMo':
            a = ('rank', 'r', e[1] or sid)
            if a not in found:
                found.append(a)
        for part in e[1:]:
            walk_expr(part)

    def walk_cond(c):
        if c[0] == 'atom':
            if c not in found:
                found.append(c)
        else:
            for part in c[1:]:
                walk_cond(part)

    for n in node:
        if isinstance(n, Number):
            walk_expr(n.expr)
        elif isinstance(n, Cond):
            walk_cond(n.cond)
            for a in (atoms_of(n.then, variables, seen, talents, sid)
                      + atoms_of(n.other, variables, seen, talents, sid)):
                if a not in found:
                    found.append(a)
    return found


def holds(cond, state):
    kind = cond[0]
    if kind == 'atom':
        return bool(state.get(cond, False))
    if kind == 'not':
        return not holds(cond[1], state)
    if kind == 'and':
        return holds(cond[1], state) and holds(cond[2], state)
    return holds(cond[1], state) or holds(cond[2], state)


class Reader:
    """Evaluates a spell's template against the client's tables (a forever_spells.Client)."""

    def __init__(self, client, variables_by_spell, talents=None, level=LEVEL):
        self.client = client
        self.variables_by_spell = variables_by_spell  # spell ID -> variables text
        # Talent spell ID -> {effect index (0-based): [value at rank 1, rank 2, ...]}, from the
        # trait curves: the raw effect holds 0 or the top rank's value.
        self.talents = talents or {}
        self.level = level
        self._variables = {}
        self.warnings = set()

    def variables(self, sid):
        if sid not in self._variables:
            self._variables[sid] = parse_variables(self.variables_by_spell.get(sid, ''))
        return self._variables[sid]

    def effect(self, sid, index):
        """An effect by its 1-based index; None where the spell lacks it, as Contingency Plan's
        tooltip names a second effect its shield spell does not have."""
        e = next((x for x in self.client.effects(sid) if x['index'] == index - 1), None)
        if e is None:
            self.warnings.add(f'spell {sid} has no effect {index}')
        return e

    def stat_of(self, sid, e):
        """The stat an effect's spell power share uses."""
        if e['effect'] in HEAL_EFFECTS or e['aura'] in HEAL_AURAS:
            return 'heal'
        school = self.client.info(sid)['school']
        return 'spell:' + SCHOOLS.get(school, 'Multi') if school else 'spell'

    def base(self, sid, e):
        """The effect's base points at the reader's level, as lo..hi."""
        lv = self.client.info(sid)['levels'] or {}
        mean = e['bp']
        if e['ppl'] and lv.get('base'):
            top = min(self.level, lv['max']) if lv.get('max') else self.level
            mean += e['ppl'] * max(0, top - max(lv['base'], lv.get('spell') or 0))
        spread = abs(e['bp']) * e['var'] / 2
        return mean - spread, mean + spread

    def coefficient(self, sid, e):
        import forever_spells as fs  # noqa: PLC0415 -- shares the client's 1.0-means-unset rule
        school = self.client.info(sid)['school']
        sp = e['sp_raw'] if fs.coef_is_real(e['effect'], e['aura'], e['sp_raw'], school) else 0.0
        ap = e['ap'] if e['ap'] and not (e['effect'] in fs.E_WEAPON and abs(e['ap'] - 1) < 1e-6) else 0.0
        return sp, ap

    def ref(self, sid, kind, index, state):
        info = self.client.info(sid)
        if kind in 'dD':
            return Value(info['dur'] / 1000)
        if kind in 'nuir':
            return Value(0)  # counts, stacks, targets and ranges: numbers with no stat in them
        e = self.effect(sid, index or 1)
        if e is None:
            return Value(0)
        refs = {(sid, e['index'])}
        ranks = self.talents.get(sid, {}).get(e['index'])
        if ranks and kind in 'smMo':
            rank = state.get(('rank', 'r', sid), 0)
            return Value(ranks[rank - 1] if rank else 0, refs=refs)
        if kind in 'tT':
            return Value(e['period'] / 1000, refs=refs)
        if kind in 'aA':
            return Value(e['radius'][0], refs=refs)
        if kind in 'xX':
            return Value(e['chain'], refs=refs)
        if kind == 'b':
            return Value(e['ppr'], refs=refs)
        lo, hi = self.base(sid, e)
        sp, ap = self.coefficient(sid, e)
        terms = {}
        if sp:
            terms[self.stat_of(sid, e)] = sp
        if ap:
            terms['ap'] = ap
        if kind == 'm':
            return Value(lo, refs=refs, hidden=terms)
        if kind == 'M':
            return Value(hi, refs=refs, hidden=terms)
        if e['effect'] == WEAPON_PERCENT:  # the number is a percent; its flat bonus is not in it
            return Value(lo, hi, refs=refs, hidden=terms)
        value = Value(lo, hi, terms, refs)
        if kind == 'o':
            ticks = info['dur'] // e['period'] if e['period'] and info['dur'] else 1
            value = value * ticks
        return value

    def evaluate(self, expr, sid, state, depth=0):
        kind = expr[0]
        if kind == 'num':
            return Value(expr[1])
        if kind == 'ref':
            return self.ref(expr[1] or sid, expr[2], expr[3], state)
        if kind == 'stat':
            return Value(0, terms={expr[1]: 1})
        if kind == 'level':
            return Value(self.level)
        if kind == 'bc':
            e = self.effect(sid, 1)
            return Value(e['sp_raw'] if e else 0)
        if kind == 'var':
            if depth > 8:
                raise FormulaError('variables nest too deep')
            nodes = self.variables(sid).get(expr[1])
            if nodes is None:
                raise FormulaError(f'spell {sid} has no variable {expr[1]}')
            return self.value_of(nodes, sid, state, depth + 1)
        if kind == 'neg':
            return -self.evaluate(expr[1], sid, state, depth)
        a, b = self.evaluate(expr[1], sid, state, depth), self.evaluate(expr[2], sid, state, depth)
        return {'add': a.__add__, 'sub': a.__sub__, 'mul': a.__mul__, 'div': a.__truediv__}[kind](b)

    def value_of(self, nodes, sid, state, depth=0):
        """A variable's value: its one number, after its conditions."""
        values = []
        for n in self.flatten(nodes, state):
            if isinstance(n, Number):
                values.append(self.evaluate(n.expr, sid, state, depth))
            elif isinstance(n, Text) and n.text.strip():
                raise FormulaError(f'text {n.text!r} in a variable')
        if len(values) != 1:
            raise FormulaError(f'a variable with {len(values)} numbers')
        return values[0]

    def flatten(self, nodes, state):
        """The nodes that print in a state, conditions resolved."""
        out = []
        for n in nodes:
            if isinstance(n, Cond):
                out += self.flatten(n.then if holds(n.cond, state) else n.other, state)
            else:
                out.append(n)
        return out


# --------------------------------------------------------------------------------------- reading

NUMBER = re.compile(r'\d+(?:[.,]\d+)*')


def literal_numbers(text):
    """How many numbers plain template text prints."""
    return len(NUMBER.findall(text))


def printed(reader, sid, nodes, state, depth=0):
    """The numbers a tooltip prints in a state, in order: each (Number or None for a literal,
    Value or None, how many numbers it prints)."""
    out = []
    for n in reader.flatten(nodes, state):
        if isinstance(n, Text):
            out += [(None, None, 1)] * literal_numbers(n.text)
        elif isinstance(n, Choice):
            out += [(None, None, 1)] * literal_numbers(n.options[0])
        elif isinstance(n, Include):
            if n.what == 'spelldesc' and depth < 2:
                inner = parse(reader.client.desc.get(n.spell, ''))
                out += printed(reader, n.spell, inner, state, depth + 1)
        else:
            value = reader.evaluate(n.expr, sid, state)
            # A reference with a spread prints "low to high"; an expression or a fixed
            # amount, one number.
            count = 2 if (n.expr[0] == 'ref' and n.expr[2] in 'so' and value.is_range) else 1
            out.append((n, value, count))
    return out


def states(atoms, talents):
    """Every combination of conditions, the all-false one first: a check is true or false,
    a talent at rank 0 to its top."""
    domains = [range(max(len(v) for v in talents[a[2]].values()) + 1) if a[0] == 'rank' else (False, True)
               for a in atoms]
    ranked = {a[2] for a in atoms if a[0] == 'rank'}
    for values in itertools.product(*domains):
        state = dict(zip(atoms, values))
        # Knowing a talent, or having its passive aura, is having a rank in it.
        if any(a[0] == 'atom' and a[1] in 'sa' and a[2] in ranked and v != (state[('rank', 'r', a[2])] > 0)
               for a, v in state.items()):
            continue
        yield state


def read(reader, sid, template=None, max_atoms=8):
    """Every state's printed numbers for a spell: (atoms, [(state, printed)])."""
    text = reader.client.desc.get(sid, '') if template is None else template
    nodes = parse(text)
    atoms = atoms_of(nodes, reader.variables(sid), talents=reader.talents, sid=sid)
    if len(atoms) > max_atoms:
        raise FormulaError(f'{len(atoms)} conditions')
    return atoms, [(state, printed(reader, sid, nodes, state)) for state in states(atoms, reader.talents)]
