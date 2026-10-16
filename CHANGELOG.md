# PrettyTooltip 1.1.3

## Tooltips

- Elites, rares, rare elites, and world bosses now show the dragon from the game's target frame behind their tooltip's header.
- Unit tooltips show a health bar again, at the bottom of the panel: the game's own bar, which the game fills, so it works without the addon reading unit health. It can be turned off under **Unit Details** in the options.
- Bosses that WoW Forever reports as elites, such as faction leaders, are now shown as bosses, as the game's own tooltip names them.
- Quests hovered in the world map's quest log are now restyled, with the quest's level and status from your quest log. Lines other addons add, such as a guide's note, are kept below.
- Removed the progress bar under quest objectives; each objective still shows its count.
- Fixed divider lines that vanished, or were drawn twice as thick, depending on where the tooltip sat on screen.
- Fixed an error when a tooltip refreshed before it had any lines.

## Editor

- Added Rare elite and Boss samples to the Units tab.
- Unit samples show the health bar, each filled to its own health.

# PrettyTooltip 1.1.2

## Tooltips

- Added optional damage and healing per second and per mana under a spell's spell power breakdown.
- Unit tooltips now fade out smoothly, without the game's tooltip showing through behind them. ([#2](https://github.com/FallenShard/PrettyTooltip/issues/2))
- Removed the unit health bar, since WoW Forever does not let addons read unit health. ([#3](https://github.com/FallenShard/PrettyTooltip/issues/3))

# PrettyTooltip 1.1.1

## Tooltips

- Added optional drop tables for herb nodes, ore nodes and skinnable mobs.
- Added a new table for spell power coefficients. This is still WIP until we confirm scaling formulas for all spells in WoW Forever.
- Added clearer descriptions for quest-starting items.
- Revamped the color palette to be a little brighter and removed default colorization of primary stats.
- Toned down colorization for lite mode.
- Borders, dividers, and separators stay one pixel sharp at any UI scale.

## Editor

- Each stat category's color can be chosen in the style editor.
- Added global text size for accessibility.

# PrettyTooltip 1.1.0

## Tooltips

- Added styled macro tooltips, including spell and item previews selected through #showtooltip.
- Added pet ability, command, and stance tooltips, with autocast and active-state indicators.
- Added styled minimap tooltips.
- Added flight path tooltips showing the destination, zone, travel cost, and current location.
- Improved spell school detection with a dedicated database covering WoW Forever spells and Frostfire Bolt.
- Expanded spell damage and healing breakdowns and fixed talent tooltip layouts.
- Added markers for use effects, chance-on-hit effects, and enchants, plus number highlighting for use and proc effects.
- Improved bag tooltip handling and parsing of bonuses against specific creature types.
- Added font string caching for faster drawing, and addon memory reporting in /ptip perf.

## Editor

- Expanded style controls with padding, minimum width, Blizzard borders, and individual reset buttons; refined badges and item level icons.
