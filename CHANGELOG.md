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
