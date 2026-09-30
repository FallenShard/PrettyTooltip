# PrettyTooltip

Shortens English item stat text in WoW Forever tooltips. For example:

```text
Equip: Increases healing done by up to 48 and damage done by up to 16 for all magical spells and effects.
```

becomes two tooltip lines:

```text
+48 Healing Power
+16 Spell Damage Power
```

**Spell Damage Power** names damage-only magical bonuses, including the damage part of a combined healing/damage line. **Spell Power** names generic bonuses that apply to both damage and healing. School-specific damage bonuses use names such as **Fire Spell Damage Power**.

It also shortens common spell damage, attack power, hit, crit, avoidance, defense, rating, regeneration, and similar Equip bonuses. Stat lines that are already short, item uses, procs, and unrecognized wording stay as the game displays them.

Each stat value uses a deeper, richer color, while its name uses a lighter, less saturated shade of the same hue. Categories are teal for primary attributes, orange for physical offense, blue for defense, and purple for general magic, matching the defaults of EllesmereUI's character sheet; green for healing, blue for mana regeneration, and distinct colors for the six spell schools. Existing short stat lines such as `+12 Strength` receive the same treatment.

Recognized slot/type pairs are shown together, such as `Staff · Two-Hand` or `Cloth · Chest`. Solo slots such as `Finger` stay as they are. `Crafting Reagent` and `Scarce` lines join that same line in their original colors, as in `Crafting Reagent · Scarce`. Consumables, which the game never labels, start that line with their class and subclass, such as `Consumable · Potion`. Equipment tooltips show item level directly below the item name when the game supplies it. Short `Equip: +8 Attack Power.` text becomes `+8 Attack Power`.

## V2 presentation

The item tooltip has a slim frame and a small item icon beside the name. Common items use a graphite frame; uncommon, rare, epic, and legendary items tint the frame and a custom silver filigree corner to match their quality. A small texture marks each recognized stat, so the marker works with fonts that lack diamond characters. For weapons with the game's usual damage, speed, and DPS rows, DPS becomes the prominent first row; damage and speed follow on the next row. This keeps the same number of tooltip rows and leaves all unrecognized and addon supplied lines in place.

The filigree source is `art/quality-corner-source.png`; the game loads the scaled `art/quality-corner.tga`. The stat marker is `art/stat-marker.tga`.

## V3 layout preview

The addon renders an item panel with a quality-colored header, icon with an item level badge, ornamented dividers, stats grouped as primary attributes and then everything else, an item-set block, and a footer with durability, requirements, and sell price. The original game tooltip remains available while ALT is held. Lines the layout cannot classify, including rows appended directly by other addons, appear below a thin rule in smaller, muted text, in their original order and keeping their own colors. If tooltip values cannot be read safely, the original game tooltip is shown instead.

The panel is only as wide as its widest single-line content, between 260 and 408 pixels; effects, set bonuses, and other prose wrap. Set pieces you own and active set bonuses are highlighted, following the game's own coloring. Quest items, and items that begin a quest, are tinted quest gold instead of their rarity color; the title keeps the rarity color. While the game shows a comparison, each stat, armor, and DPS row carries its change against the compared item in green or red, and stats only the equipped item has are listed dimmed below. Durability is a small bar with its value. Dividers appear only between sections that have content. When DialogueUI is installed, its dark tooltip backdrop is used from its own folder; it is not copied into this addon. The hidden game tooltip is resized to cover the panel, so comparison tooltips, screen-edge sliding, and clamping follow the panel's real size.

Tooltip refreshes keep the previous panel visible until other addons finish appending their rows, then redraw it at the end of the frame. A clear or brief hide also keeps the panel visible through a same-frame rebuild.

Hold **ALT** while viewing an item to see the original tooltip wording. The tooltip updates when ALT is pressed or released, even if it is already open.
ALT also hides the frame and item icon and restores the original weapon row order, leaving lines from other addons in place.
Unrecognized item lines are passed through unchanged. PrettyTooltip does not remove or replace the tooltip's line table.

## Spell tooltips

Spell tooltips use the same panel. Cost, cast time, cooldown, and range sit in a centered strip under the header, the spell icon sits left of the name, small badges under the name give the school, in its color, and the rank, and the description is split into one sentence per line, with its numbers in the school's color. The panel is tinted by the spell's school, taken from the first damage its description names, such as `Fire damage`, or else from a school that starts its name, such as `Holy Light` (Arcane, Fire, Frost, Holy, Nature, Shadow), and otherwise by the resource it costs: blue for mana, red for rage, yellow for energy. The cost value keeps the resource color either way. Lines the layout cannot classify, and rows added by other addons, appear below in the muted style used for items. If the spell's lines cannot be read, such as while combat restricts them, the game's tooltip is shown instead.

## Install

Run `python deploy.py` from this folder to copy the game files to `D:\Programs\World of Warcraft\_classic_beta_\Interface\AddOns\PrettyTooltip`. For a different installation, run `python deploy.py --addons-dir "<path to Interface\AddOns>"`.

If the `PrettyTooltip` folder was added while the game was running, restart the game so it discovers the new addon. After later edits to the Lua file, deploy again and type `/reload` in game. Enable **PrettyTooltip** on the character AddOns screen if needed.

This addon targets the English WoW Forever 1.60.1 client (`## Interface: 16001`). The game's tooltip API may differ on other versions.
