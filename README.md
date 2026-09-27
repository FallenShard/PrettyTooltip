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

Each stat value uses a deeper, richer color, while its name uses a lighter, less saturated shade of the same hue. Categories are parchment for primary attributes, copper for physical offense, steel for defense, violet for general magic, green for healing, blue for mana regeneration, and distinct colors for the six spell schools. Existing short stat lines such as `+12 Strength` receive the same treatment.

Recognized slot/type pairs are shown together, such as `Two-Hand · Staff` or `Chest · Cloth`. Solo slots such as `Finger` stay as they are. Equipment tooltips show item level directly below the item name when the game supplies it. Short `Equip: +8 Attack Power.` text becomes `+8 Attack Power`.

Hold **ALT** while viewing an item to see the original tooltip wording. The tooltip updates when ALT is pressed or released, even if it is already open.
ALT swaps only PrettyTooltip's own rendered text, leaving lines from other addons in place.
Unrecognized item lines are passed through unchanged. PrettyTooltip does not remove or replace the tooltip's line table.

## Install

Run `python deploy.py` from this folder to copy the game files to `D:\Programs\World of Warcraft\_classic_beta_\Interface\AddOns\PrettyTooltip`. For a different installation, run `python deploy.py --addons-dir "<path to Interface\AddOns>"`.

If the `PrettyTooltip` folder was added while the game was running, restart the game so it discovers the new addon. After later edits to the Lua file, deploy again and type `/reload` in game. Enable **PrettyTooltip** on the character AddOns screen if needed.

This first version targets the English WoW Forever 1.60.1 client (`## Interface: 16001`). The game's tooltip API may differ on other versions.
