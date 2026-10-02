# PrettyTooltip

A full reskin of item and spell tooltips for WoW Forever. PrettyTooltip replaces the game's tooltip with a compact, ornamented panel: the item's icon and quality up front, stats in short colored rows grouped by kind, and the fine print gathered in a footer. Hold **ALT** at any time to see the game's own tooltip.

## Item tooltips

Top to bottom, an item panel shows:

- **Header.** The icon with an item level badge, the name in its quality color, and a subtitle with the item's type and slot, such as `Mail · Head` or `Staff · Two-Hand`. The subtitle also names what the game leaves unsaid: `Consumable · Potion`, `Crafting Reagent`, `Scarce`. The binding sits below it, with the required level at the right, red while you are below it. The whole panel is tinted by quality; quest items, and items that begin a quest, are tinted quest gold.
- **Weapon damage.** DPS as the prominent row, with damage and speed beneath it.
- **Armor and stats.** Armor, then the stats in two blocks: the primary attributes, and everything else under a divider. Long stat wording is shortened (see below), and each stat is colored by kind.
- **Equip effects and enchants.** Equip effects that are not a plain stat, such as a zone-limited speed bonus, join the stat list in green without the `Equip:` prefix. Enchants follow as green rows with a green marker, one per bonus: `Enchanted: Stamina +1 and Armor +8` becomes `+1 Stamina` and `+8 Armor`.
- **Use effects and flavor text,** as the game words them.
- **Item set.** The set name and how many pieces you own, the pieces you own highlighted, and the set bonuses, with active ones highlighted.
- **Footer.** Durability as a small bar, the crafter's name for crafted items, other requirements such as skills or classes, and the sell price (per item for stacks).

While the game shows a comparison, the comparison panels are tagged **Equipped**, and each ends with what would change if the item you are looking at replaced it: gains in green, losses in red, as in the game's own comparison. Rings, trinkets, and one-handed weapons compare against both equipped items, each with its own list.

Recipes take their own name as the title, so `Pattern: Blue Linen Vest` stays the pattern even though the game's tooltip includes the vest.

### Shorter stats

Common Equip wordings become short stat rows:

| The game says | PrettyTooltip shows |
| --- | --- |
| Equip: Increases healing done by up to 48 and damage done by up to 16 for all magical spells and effects. | +48 Healing Power<br>+16 Spell Damage Power |
| Equip: Increases damage and healing done by magical spells and effects by up to 12. | +12 Spell Power |
| Equip: Increases damage done by Fire spells and effects by up to 20. | +20 Fire Spell Damage Power |
| Equip: Improves your chance to get a critical strike by 1%. | +1% Critical Strike Chance |
| Equip: Increased Defense +2. | +2 Defense Skill |
| Equip: Restores 3 mana per 5 sec. | +3 Mana per 5 sec |

**Spell Power** is a bonus to both damage and healing; **Spell Damage Power** is damage only. Hit, crit, dodge, parry, block, ratings, attack power, health regeneration, and spell penetration are shortened the same way. Wording PrettyTooltip does not recognize is shown as the game writes it.

### Colors

Each stat value takes a rich color and its name a lighter shade of the same hue. The four main categories use the defaults of EllesmereUI's character sheet:

| Category | Color |
| --- | --- |
| Primary attributes | Teal |
| Attack: attack power, hit, crit, haste | Orange |
| Defense: defense, dodge, parry, block | Blue |
| Magic: spell power, spell hit and crit, penetration | Purple |
| Healing | Green |
| Mana regeneration | Light blue |
| Spell schools and resistances | Arcane, Fire, Frost, Holy, Nature, and Shadow each in their own color |

## Spell tooltips

Spells use the same panel: the icon and name, small badges for the spell's school and rank, and a strip with cost, cast time, cooldown, and range. The description follows one sentence per line, with its numbers highlighted.

The panel is tinted by the spell's school, read from the damage its description names (`Fire damage`) or a school that starts its name (`Holy Light`). Spells with neither are tinted by the resource they cost: blue for mana, red for rage, yellow for energy.

A spell that carries another spell inside its tooltip, such as Feral Charge with its Cat Form version, shows the inner spell as a second section with its own name, strip, requirements, and description. Talents get the spell panel too.

## World objects

Herbs, ore, chests, and quest objects get a panel too. A herb or ore node shows the herb or ore it yields, with its icon; the skill it needs and the level, in the game's skill-up color (red while your skill is too low), beside your own skill; and in the footer the yield's sell price and, with **Auctionator** installed, its auction price. Locked chests show the lock and the Lockpicking they need, and quest objects show their quests and objectives. Rows other addons add, such as Questie's, are kept below.

## Working with other addons

- Rows other addons add to a tooltip are kept, below a thin rule in smaller, muted text, in their original order and colors.
- Comparison tooltips, screen-edge clamping, and anything anchored to the tooltip follow the panel's real size.
- With **DialogueUI** installed, the panel uses its dark tooltip backdrop, unless turned off in the options. Text uses the game's own tooltip fonts, so a UI addon that changes the default font is followed; with **EllesmereUI** installed, names use its Expressway font. Both are used from those addons' own folders; nothing of theirs is bundled.
- Whenever a tooltip cannot be read safely, such as spell details restricted during combat, the game's own tooltip is shown instead.

## Style editor

Type `/ptip` (or `/prettytooltip`) to open the style editor, where everything about the tooltip's look is set. **Items**, **Spells**, and **Objects** switch between the kinds of panel. The editor shows a sample tooltip; click any part of it, such as the name, the stats, or a spell's description, to change that part's font, size, color, and outline. The samples (for items a weapon, the equipped item it is compared with, a set piece, and a potion; for spells a damage spell, an ability with a cooldown and an unmet requirement, and a heal; for objects a herb, an ore node you cannot mine yet, a locked chest, and a quest object) cover every part, and the editor switches to one that has the part you pick from its list.

To preview a real item or spell instead, type its ID in the box at the top right and press Enter, or click the box and shift-click the item or spell, as you would to link it in chat. **Clear**, or a sample tab, goes back to the samples.

- **Font**: every font registered with LibSharedMedia, which includes EllesmereUI's fonts when it is installed, plus the game's own. **Global Settings** sets the font for everything at once, with a separate font for names; a part's own font overrides it.
- **Color**: a custom color replaces every color the part would have had, including quality, category, and red or grey states. **Automatic** goes back to the normal colors.
- **All caps** sets a part in capitals. It is on by default for item, spell, and set names (off, they keep the game's capitalization) and off for every other part.
- **Reset this part** and **Reset all fonts and colors** go back to the defaults.

Under **Layout and color** (hover one for its description):

- **Icon on the right** moves the icon and its item level badge to the right of the name.
- **Item level badge** and **Stat markers** turn those elements off.
- **Stat colors**: off, every stat is parchment.
- **Tint the panel**: off, every panel is neutral; names keep their quality color.
- **Separators**: off, the gold dividers between sections and the thin rules are hidden, along with the space around them.
- **DialogueUI backdrop** (on by default, only with DialogueUI installed): off, the panel uses its plain dark gradient.

Tooltips use the new look the next time they open.

## Options

Open the game's options, then **AddOns > PrettyTooltip**, or type `/ptip options`. The page opens the style editor and has the settings that are not about the look. `/ptip dump` prints the data of the tooltip you are hovering, to see what a kind of tooltip carries.

- **Restyled Tooltips** is a table with a row for every kind of tooltip the game has: items, spells, players and NPCs, buffs and debuffs, herbs, ore, chests and other objects, quests, currencies, lockouts, pet abilities, the minimap, mounts, toys and pets, and achievements.
  - **Restyle**: **Items**, **Spells**, and **Herbs, ore, chests, and other objects** can each be turned off, and that kind then keeps the game's own tooltip, wording included. The other kinds are greyed out until PrettyTooltip restyles them.
  - **Follow cursor** (on by default for herbs, ore, chests, and other objects; off for the rest): the kind's tooltip appears at the cursor and follows it whenever the game would show it in its default corner, as for units, world objects, and action buttons. Tooltips that bags, the character pane, and other panels place beside themselves stay there. While it is off, PrettyTooltip leaves the tooltip's position to the game and to any other addon that places tooltips.
- **Default Tooltip Modifier** picks the key you hold to see the game's own tooltip: CTRL, ALT (the default), or **Never show default tooltip**.

## Install

1. Download the release and extract the `PrettyTooltip` folder into your WoW Forever installation's `Interface\AddOns` folder.
2. Restart the game if it was running, and enable **PrettyTooltip** on the character select AddOns screen.

## Compatibility

- WoW Forever 1.60.1 (`## Interface: 16001`). Other clients may word their tooltips differently.
- English clients only. On other languages the panel and stat rewriting stay off, though the options page still appears.

## Known limitations

- No game API names a spell's school, so it is read from the spell's text. A spell that never names its damage type may get no school, or the wrong one if its name starts with one.
- Profession recipe spells show the crafted item as plain rows under the description.
- Stat wordings not in the table above are shown unchanged.

## Development

`python deploy.py` copies the game files into `D:\Programs\World of Warcraft\_classic_beta_\Interface\AddOns\PrettyTooltip`; pass `--addons-dir "<path to Interface\AddOns>"` for another installation. After a deploy, `/reload` picks up Lua changes; changes to the `.toc` need a game restart.

`art/README.md` describes each texture and how it is made.
