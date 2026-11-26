# PrettyTooltip

A full reskin of tooltips for WoW Forever and retail World of Warcraft. PrettyTooltip replaces the game's tooltip with a compact, ornamented panel: the icon and name up front, the details in short colored rows grouped by kind, and the fine print gathered in a footer. Hold **ALT** (or the key you choose) at any time to see the game's own tooltip.

## Forever and retail

One download serves both games: Forever loads `PrettyTooltip_Camelot.toc`, retail `PrettyTooltip_Mainline.toc`. Forever's file needs its own suffix: Forever counts as a Mainline game too, and would load retail's file over a plain `PrettyTooltip.toc`. Retail leaves out what comes from Classic's data, as no retail source exists for it: disenchant results, spell power coefficients, and herb, ore, and skinning loot. Their settings are hidden there. Spell schools come from retail's own spell tables, and damage and healing rates from the description alone, with the global cooldown after haste.

## Item tooltips

Top to bottom, an item panel shows:

- **Header.** The icon with an item level badge, the name in its quality color, and a subtitle with the item's type and slot, such as `Mail · Head` or `Staff · Two-Hand`. The subtitle also names what the game leaves unsaid: `Consumable · Potion`, `Crafting Reagent`, `Scarce`. The binding sits below it, with the required level at the right, red while you are below it. The whole panel is tinted by quality; quest items, and items that begin a quest, are tinted quest gold.
- **Retail's source, upgrade, and transmogrification.** On retail, where the item comes from (`Heroic`, `Mythic`) sits under its name, its upgrade level (`Myth 2/6`) under the subtitle, and what it is transmogrified to, with any weapon illusion, after the binding. A crafted item's quality, with the game's quality icon, follows the upgrade level. Each is its own part in the style editor: **Source**, **Upgrade level**, **Crafted quality**, and **Transmogrification**.
- **Gems and sockets.** On retail, after the enchants: each socketed gem with its icon and its stat in that stat's color, its enchantment indented under it, empty sockets with the game's socket icon, and the socket bonus, green once active. The style editor's **Gems and sockets** part sets their look, and its **Socket Hint** switch hides the game's `<Shift Right Click to Socket>` line.
- **Weapon damage.** DPS as the prominent row, with damage and speed beneath it.
- **Armor and stats.** Armor (and a shield's block under it), then the stats in two blocks: the primary attributes, and everything else under a divider. Long stat wording is shortened (see below), and each stat is colored by kind. On retail, the primary stats your specialization does not use stay grey, as the game shows them. Retail's Critical Strike, Haste, Mastery, and Versatility each have a color of their own, and Leech, Avoidance, and Speed share one; set them under **Secondary Stat Colors** in the style editor, and their font under its **Secondary stats** part.
- **Equip effects and enchants.** Equip effects that are not a plain stat, such as a zone-limited speed bonus, join the stat list in green without the `Equip:` prefix. A chance on hit joins them too, marked with a small sword instead of its `Chance on hit:` prefix. Its numbers follow the spell tooltip's highlighting: a lighter school color when the description names that school's damage, or a neutral highlight otherwise. Holyfire blends Holy and Fire. These highlights follow **Stat Colors** and a custom **Equip effects** color in the panel. Enchants follow as green rows marked with a sparkle, one per bonus: `Enchanted: Stamina +1 and Armor +8` becomes `+1 Stamina` and `+8 Armor`.
- **Use effects and flavor text,** as the game words them, each use effect marked with a small gear instead of its `Use:` prefix.
- **Item set.** The set name and how many pieces you own, the pieces you own highlighted, and the set bonuses, with active ones highlighted.
- **Disenchant.** For green, blue, and purple armor and weapons: what the item disenchants into, each result with its icon, count, and chance, and the Enchanting it needs, red while your skill is too low and grey if you have no Enchanting. The chances are Classic's published tables (Warcraft Wiki's *Disenchanting tables*); the game has no way to ask. Turned off under **Item Details** in the style editor.
- **Footer.** Durability as a small bar, the crafter's name for crafted items, other requirements such as skills or classes, and the sell price as coins alone; a stack shows its total first, then the count and one item's price, dimmed (`2g  (20 × 10s)`), which can be turned off under **Item Details** in the style editor.

While the game shows a comparison, the comparison panels are tagged **Equipped**, and the game's own "If you replace this item" stat changes appear among the rows at the bottom, in their usual green and red.

Recipes are the recipe first: their own icon and name, `Plans · Blacksmithing` beneath, and the skill they need beside the binding, red while yours is too low. The item they craft follows under **Creates** as a smaller card with its icon, name, slot, required level, and its own armor, stats, and effects, then the **Reagents** with their icons and how many you carry (`4 / 10`, red while short).

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

### The Blizzard layout

With **Layout Style** set to **Blizzard** on the style editor's **General** page, every tooltip keeps the game's own look, and so does each kind whose Restyle setting is off. Items keep the game's tooltip with selected Equip effects shortened as in the table above and the game's line colors kept, except for magic: spell power, spell hit and crit, penetration, and healing power in their stat colors, and the damage of chance on hit effects in its school's color, while **Stat Colors** is on. Combined bonuses split into separate lines. **Abbreviated Equip Effects** under **Item Details** in the style editor turns this off.

While the **Tooltip Details Modifier** is held (Shift by default), the details a panel would show appear at the bottom of the game's tooltip, below every other addon's rows: disenchant results, the spell power breakdown and rates, gathering contents, and IDs, each as its switch in the style editor allows. They show and hide as the key is pressed and released, in combat too. Holding the **Default Tooltip Modifier** shows the game's tooltip as it is, with neither.

### Colors

Each stat value takes a color and its name a lighter shade of the same hue. The category colors are soft and evenly light, so every kind of stat reads alike on the dark panel, and the vivid spell school colors stand apart from them:

| Category | Color |
| --- | --- |
| Primary attributes | Ivory |
| Attack: attack power, hit, crit, haste | Amber |
| Defense: defense, dodge, parry, block | Steel blue |
| Magic: spell power, spell hit and crit, penetration | Lavender |
| Healing | Mint |
| Mana regeneration | Periwinkle |
| Spell schools and resistances | Arcane, Fire, Frost, Holy, Nature, and Shadow each in their own color |

Set **School Colors** under **All Tooltips > Appearance** in the style editor. The same choices color spell panels, school badges, highlighted numbers, item spell-power and resistance stats, school weapon damage, and macro accents. Holyfire and Frostfire have their own swatches; their panel gradients follow their two component schools. Click a swatch to choose its color, right-click it for the default, or use the row's reset to restore every school. With no overrides, the original colors are kept.

Turn on **Armor Colors** under **Item Details** to tell armor types apart at a glance: the type that leads the subtitle, as *Plate* in *Plate · Chest*, takes its own color (cloth pink, leather light brown, mail blue-green, plate blue-gray), and the rest of the line keeps the quality color. A type the game shows in red, because you cannot wear it, stays red. Cloaks are left alone, since every class wears them. Each type has a swatch beside the switch; the switch is off by default.

## Spell tooltips

Spells use the same panel: the icon and name, small badges for the spell's school, its rank, and **Passive** for passive spells and talents, and a strip with cost, cast time, cooldown, and range. On retail, a spell with charges shows its recharge in the cooldown cell, its most charges under the strip (**Charges** in the style editor), and the time left on the next charge in orange. The description follows one sentence per line, with its numbers highlighted.

The panel is tinted by the spell's school: a class spell's comes from WoW Forever's client spell data, which the addon carries, and any other spell's is read from the damage its description names (`Fire damage`) or a school that starts its name (`Holy Light`). Spells with neither are tinted by the resource they cost: blue for mana, red for rage, yellow for energy.

A spell that carries another spell inside its tooltip, such as Feral Charge with its Cat Form version, shows the inner spell as a second section with its own name, strip, requirements, and description. Talents get the spell panel too.

Spells that deal magic damage or heal show their spell power under the description: a row for each amount the description prints, with its coefficient and the amount split into its base and what your spell power adds, as `Healing Power Coefficient` and `85.7% · 441 to 595 + 120`, the coefficient in the spell school's color. A spell with several amounts gets a row each: Holy Shock's damage or heal, a seal's strike and its Judgement, Immolate's hit and its burn. WoW Forever's tooltips already count your spell power in, so the base is the shown amount less spell power times the coefficient. No game API has coefficients, so the addon carries them for every class spell rank, read from Forever's client spell data and the formulas its tooltips are printed with, the talents and stances that change them included, with the corrections in Blizzard's development notes. Other spells follow Classic's rules (cast time / 3.5, duration / 15), which Forever keeps without Classic's cap on spells over time or its penalty for spells learned before level 20; a coefficient marked `~` is an estimate, and a channeled spell the addon has no data for shows none. Turned off under **Spell Details** in the style editor.

## Players and NPCs

Units under the cursor get a panel with their portrait, the name in class color (players) or reaction color (NPCs: red hostile, yellow neutral, green friendly, grey when tapped by someone else), the guild or an NPC's role, and the level, race, and class or creature type, the level in its difficulty color. Badges mark elites, rares, bosses, a player's faction, PvP, AFK, DND, and the dead. Below sit what the unit is targeting (in red when it is you), and the unit's quest lines. Rows other addons add are kept below, and the game's own health bar closes the panel; the game fills it, as WoW Forever keeps unit health from addons. Elites, rares, rare elites, and bosses show the dragon from the game's target frame behind the header, and players their faction's crest.

**Class Colors** under **Unit Details** in the style editor has a swatch for each of the nine classes. Overrides apply to player names, panel tints and glows, the guild's lighter shade, and player targets. Click to choose a color, right-click for the default, or reset the row to clear all class overrides. With no override, the game's current class color is used, including changes made by other addons.

## Buffs and debuffs

Auras show their icon and name, badges for buff or debuff, the dispel type in the game's colors (Magic, Curse, Disease, Poison), and stacks, then the description one sentence per line, the time left with who cast it, and a bar that drains as the aura runs out.

## Quests

With **DialogueUI** installed, enable **Quest Parchment** under **Quest Details** or **Item Details** in the style editor for its brown parchment and darker ink. The shared toggle applies to quest tooltips, items marked **Quest Item**, and items that begin a quest; the **Quest item** sample on the Items page previews it. It is off by default. Per-part custom text colors still take precedence, and the artwork is read from DialogueUI's folder.

Quest links read like a page of the quest log: the quest's name and the dungeon it is in, then badges for its level in the game's difficulty color, tags such as Elite or Dungeon, and where it stands (in progress, ready to turn in, completed, failed, repeatable). Below sit the quest giver's words in quotes and the objectives as a checklist with their progress, ticked and green once finished. The header has no icon unless **Show Icon** is turned on in the style editor. With **Questie** installed, which draws quest links itself, the panel is built from Questie's tooltip, both for a clicked link and for one hovered in chat; who starts or ends the quest and where follow as label and value rows. Quests hovered in the world map's quest log get the same panel, with the level from your quest log; rows other addons add, such as a guide's note, are kept below.

## Mail

Mail attachment summaries have their own **Mail** category and style-editor preview. They show item icons, quality-colored names and quantities, with Auctionator's price rows beneath each attachment and its total in the footer. Individual attachments retain their normal item tooltips. Turn off **Restyle** on the Mail page to keep the native summary.

## World objects

Herbs, ore, chests, and quest objects get a panel too. A herb or ore node shows the herb or ore it yields, with its icon; the skill it needs and the level, in the game's skill-up color (red while your skill is too low), beside your own skill; and in the footer the yield's sell price and, with **Auctionator** installed, its auction price. Locked chests show the lock and the Lockpicking they need, and quest objects show their quests and objectives. Rows other addons add, such as Questie's, are kept below.

## Working with other addons

- Rows other addons add to a tooltip are kept, below a thin rule in smaller, muted text, in their original order and colors.
- Comparison tooltips, screen-edge clamping, and anything anchored to the tooltip follow the panel's real size.
- With **DialogueUI** installed, the panel uses its dark tooltip backdrop, unless another **Panel Style** is picked in the style editor. Text uses the game's own tooltip fonts, so a UI addon that changes the default font is followed; with **EllesmereUI** installed, names use its Expressway font. Both are used from those addons' own folders; nothing of theirs is bundled.
- Whenever a tooltip cannot be read safely, such as spell details restricted during combat, the game's own tooltip is shown instead.

## Style editor

Type `/ptip` (or `/prettytooltip`) to open the editor. Its sidebar has two top-level pages:

- **General** holds the PrettyTooltip/Blizzard layout choice, original-tooltip and details modifier keys, and the editor's Blizzard or Flat appearance.
- **Tooltips** opens **All Tooltips**, the shared styling and behavior defaults. Its children are **Items**, **Spells**, **Units**, **Objects**, **Buffs**, **Quests**, **Macros**, **Mail**, and **Other Tooltips**. The small plus/minus button expands or collapses the children; clicking Tooltips itself always opens the shared settings.

The editor opens on All Tooltips. Choose a preview type at the top right to see how a shared change affects different kinds of tooltip. Changes appear in the preview immediately and on actual tooltips the next time they open. A message explains when the previewed style is disabled by the Blizzard layout or that type's Restyle setting.

### Shared styling and overrides

Style settings inherit independently: **All Tooltips**, then the **tooltip type**, then an **individual text part**. For example, set the shared title font and size, give Items its own title size, and change the shared font again: Items picks up the new font while keeping its own size. Existing saved per-type and per-part settings remain overrides.

Both All Tooltips and type pages use expandable groups. A group's header shows how many settings it overrides; a type with no overrides in a group shows **All shared**. Expand a group to edit its fields:

| Group | Settings |
| --- | --- |
| **Appearance** | Panel Style, Panel Tint, Separators, Show Icon, Backdrop Opacity, Glow Strength, and both Header Opacity controls. All Tooltips also has School Colors. |
| **Layout** | Global Scale (Scale on a type), Padding, Minimum Width, Row Spacing, Section Spacing, and Icon Placement. |
| **Text** | Text Size, followed by Title and Body Text subheadings with Font, Size, Outline, Color, and Capitalization. |
| **Behavior** | Restyle and Follow Cursor, where the type supports it. All Tooltips also has Show IDs, tooltip fading, and Follow Cursor in Combat. |

A type's dropdown names its inherited value, such as **All Tooltips: Arial Narrow**. Choosing a value or moving a slider creates an override for that property; its reset arrow means **Use All Tooltips setting**. The remaining fields keep following their shared defaults.

**Default** in a shared list keeps each part's built-in value: sizes keep the differences between parts until a shared size is chosen, fonts are the game's, and Show Icon and Follow Cursor keep each type's own default (quest icons are off, and only world objects follow the cursor). **Capitalization** offers **Default** and **All Caps** and shows what is in effect: names start in All Caps, body text in Default. Each type can inherit the shared choice or override it; a type's Default writes names as they are and undoes a shared All Caps on body text, while section captions keep their capitals. Existing individual text-part overrides still take precedence. **Default** color preserves semantic colors such as item quality, player class, NPC reaction, spell school, and unmet requirements. Choosing a custom title or body color replaces those colors; a type or individual part can choose Default to restore them.

**School Colors** is under **Appearance**. **Behavior** includes Show IDs, tooltip fading with its delay and duration, and Follow Cursor in Combat. Fading applies to units and world objects; other tooltips hide immediately. With **Follow Cursor in Combat** off, each type keeps its preference but uses the default position during combat.

### Type-specific content and text parts

Below the common styling groups, each type keeps its own content controls:

- **Item Details**: level badge, stat markers and category colors, armor colors, damage/DPS ordering, abbreviated native Equip effects, disenchant results, sell price, and Retail's socket hint.
- **Spell Details**: the experimental spell-power breakdown on Forever, and damage/healing rates.
- **Unit Details**: level badge, guild realm, health bar, class colors, and skinning contents.
- **Object Details**: gathering contents for herbs and ore.
- **Quest Parchment**, available with DialogueUI, is shared by Quests and quest-related Items. **Gathering** is shared by Objects and Units. Resetting one type leaves these shared switches unchanged.

Click a part of the live sample to open **Selected Part** on its type's page and scroll to it, or expand Selected Part and use its picker. The part can override its font, size, color, outline, and capitalization. A reset arrow restores the type's text style; **Reset this part** removes all of that part's overrides. Fonts include the game's faces and those registered with LibSharedMedia. The samples cover the available parts, and picking a part can select a sample that contains it.

To preview a real item or spell, enter its ID in the top-right field and press Enter, or focus the field and shift-click a link. **Clear**, or a sample button, returns to the examples. Other types use built-in samples.

**Other tooltips** contains the Restyle and Follow cursor controls for kinds without their own preview page, such as weapon imbues, flight paths, pet abilities, and the minimap. Unsupported restyles are disabled.

A gold sidebar dot marks a page with custom settings. **Reset page** on a type removes its style/part overrides and restores its own content defaults; its styling then follows All tooltips. Resetting All tooltips restores the shared defaults and shared text parts while preserving type overrides. Resetting General restores addon preferences without changing tooltip styles. **Reset all fonts and colors**, at the end of General, clears text styles and color/opacity overrides across all types while preserving layout, restyle, and content preferences.

Long labels and sample buttons wrap within their columns. The window scales down to fit smaller UI dimensions, and each type remembers which groups are expanded during the session.

## Options

Open the game's options, then **AddOns > PrettyTooltip**, or type `/ptip options`. The page opens the style editor, which has every setting, including **Global Scale** under **Tooltips > Layout**. Its **Defaults** button puts every setting back.

## Install

1. Download the release and extract the `PrettyTooltip` folder into the `Interface\AddOns` folder of your WoW Forever or retail installation. The same folder works in both.
2. Restart the game if it was running, and enable **PrettyTooltip** on the character select AddOns screen.

## Compatibility

- WoW Forever 1.60.1 (`## Interface: 16001`) and retail World of Warcraft 12.1.5 (`## Interface: 120105`); on retail, what comes from Classic's data is left out (see *Forever and retail*). Other clients may word their tooltips differently.
- English, German, French, Spanish (Spain and Latin America), Portuguese, Korean, Simplified Chinese, Traditional Chinese, and Russian clients, including localized spell power coefficients and rate rows. Translations outside English are drafts. Spell descriptions are read with each language's amount, duration, and tick wording; unrecognized descriptions can omit the extra rows. On unsupported languages the panel and stat rewriting stay off, though the options page still appears.

## Known limitations

- No game API names a spell's school. Class spells and racials take theirs from the client data the addon carries; any other spell's is read from its text, so one that never names its damage type may get no school, or the wrong one if its name starts with one.
- Spell power coefficients come from the client's data, not the game server: scaling the server adds by script, such as Riptide's, is not shown, and attack power and weapon scaling for physical abilities is not shown yet. Those marked `~` are estimates.
- WoW Forever keeps the minimap's tooltip text from addons, so the minimap panel shows the game's own text as it is, without the skill a herb or ore needs or a player's class color.
- Profession recipe spells do not show the crafted item as an item panel.
- Herb and ore nodes show their yield, skill level, and prices only for the classic herbs and ores; other nodes show their skill alone. Chest and quest object tooltips are less tested.
- Stat wordings not in the table above are shown unchanged.

## Development

`python deploy.py` copies the game files into `D:\Programs\World of Warcraft\_forever_\Interface\AddOns\PrettyTooltip`, and `python deploy.py --retail` into retail's `_retail_` folder beside it; pass `--addons-dir "<path to Interface\AddOns>"` for another installation. After a deploy, `/reload` picks up Lua changes; changes to the `.toc` need a game restart.

Retail's own code is in `Retail/`, which only retail's `.toc` loads; `Retail/README.md` describes how it plugs into the shared code, and what to do to add to it.

`/ptip dump` shows the raw data of the tooltip you are hovering, to see what a kind of tooltip carries, or the lines shown when an addon filled it without data. A link clicked in chat is dumped when nothing is hovered. `/ptip anchors` shows where each shown panel sits, the gaps between them, and how the game's tooltips under them are anchored. `/ptip pixel` shows how lines are snapped to screen pixels at the current UI scale.

`/ptip trace [seconds]` records tooltip states and calls for 1–10 seconds (4 by default), including clicked item links, hovered items, both sets of comparison tooltips, and their Pretty panels. To investigate sticky comparison flicker, run `/ptip trace 10`, click an item link, then hover the item that triggers the flicker. The report includes panel hide/show calls between frame samples, comparison-manager events, and pending layout work. For hover deadzones, move the mouse into and out of the affected area: enter/leave events include cursor coordinates, and mouse-focus changes identify the receiving frames, their parents, bounds, and opacity, including invisible controls. Repeated zero-alpha calls are filtered; if the detailed event limit is reached, frame samples and visibility and comparison-manager events continue for the full selected duration.

Three commands measure performance; a label after the number names the run in its report.

- `/ptip bench [refreshes] [label]` (8–200, 24 by default) has the game time the hovered tooltip's own refresh, the one it runs every 0.2 seconds, with `C_AddOnProfiler.MeasureCall`. PrettyTooltip is off and on in turn, and the report gives each refresh's time and allocated memory, what PrettyTooltip adds, and which of its scopes spend it. Hover an item in your bags or on your character (with Shift for its comparisons) and keep the mouse still. Where the hovered button is protected, as action buttons are, or for an item link, only the comparisons are timed; the report names what it timed.
- `/ptip perf [seconds] [label]` (1–30, 5 by default) measures where PrettyTooltip's time goes while you use tooltips as usual. Frames are split into those in which the game handed tooltips their data, the frames right after them, and the rest, with their frame times and PrettyTooltip's work in each. Every hook, timer, and stage is a scope; each is reported per update, all the work divided by the frames with tooltip data, so runs over the same tooltip compare across builds.
- `/ptip perf ab [seconds] [label]` (10–120, 20 by default) turns PrettyTooltip off and on every 2.5 seconds, with no scopes measured, and compares the frame times; hover the same refreshing tooltip for the whole run.

`bench` and `perf ab` run out of combat, and turn PrettyTooltip off by suspending its panels and stages, not by changing settings. The reports also show the game's own profiler counts. The game counts hooks that run inside its code as its own time, so its figures for an addon leave out most tooltip work; the bench measures that work directly.

Each opens a window with its findings already selected, under a line naming the addon's version, the client build, and the locale: Ctrl+C copies them for a bug report, and Escape closes the window.

`/ptip capture <name>` saves the tooltip you are hovering, or a link clicked in chat, as a test fixture: its data, the lines it shows, any comparison tooltips beside it, and the game's answers its reader asks for (item, spell, and unit info, your level, spell power, and skills). Values the game hides, as on some player tooltips, are kept marked as hidden, and the tests play them back that way. Captures are kept in the `PrettyTooltipCaptures` saved variable, which the game writes on `/reload` or logout; `/ptip capture list` names them and `/ptip capture clear` removes them.

`tests/` runs the addon outside the game against captured tooltips and checks, for both games: `pip install -r tests/requirements.txt`, then `python tests/run.py`. `tests/README.md` describes capturing, importing, and the expected outputs.

`art/README.md` describes each texture and how it is made.
