-- The style editor's sample tooltips, as data: each type's samples are the
-- fields of its model, which its own tooltip file completes. What comes from
-- the game or the settings is written as a marker and filled in on each draw:
-- { item = ID } or { spell = ID } an icon, { money = copper } coins (with
-- each and count, a stack), a stat list's strings the stat rows the settings
-- style, enchant an "Enchanted:" line's rows, disenchant the results for
-- { quality, class, level, slot }, expiresIn an aura's end, and after fields
-- set once the model is complete.
local _, ns = ...
local ui = ns.ui
if not ui then return end

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

-- The types in the editor's order; dataType names the game's tooltip type and
-- model the completer the tooltip file shares.
local TYPES = {
    {
        key = "item", label = "Items", dataType = "Item", model = "itemModel", first = "title", noun = "item",
        samples = {
            {
                label = "Weapon",
                fields = {
                    name = "Arcanite Reaper", quality = 4, icon = { item = 12784 }, level = 63,
                    equippable = true,
                    slot = "Axe \194\183 Two-Hand",
                    header = { { left = "Binds when equipped", right = "Requires Level 58",
                        rightColor = { .95, .93, .88 } } },
                    weaponDps = "53.8",
                    weaponDamage = "153 - 256 Damage", weaponSpeed = "Speed 3.80",
                    primary = { "+13 Stamina" },
                    secondary = { "+62 Attack Power" },
                    equipEffects = {
                        { left = "Your attacks have a chance to cleave a nearby enemy.", right = "" },
                        { left = "Wounds the target for 40 to 60 damage.", right = "", onHit = true },
                    },
                    enchant = "+25 Agility",
                    flavor = { { left = "\"Sample flavor text sits here, in gold.\"", right = "" } },
                    footerLeft = {
                        { left = "Durability 61 / 120", right = "", durability = { 61, 120 } },
                        { left = "Made by Lorelei", right = "", color = ui.FLAVOR_GOLD },
                    },
                    footerRight = { { left = { money = 64218 }, right = "", sellPrice = true } },
                    disenchant = { 2, 4, 63, "INVTYPE_2HWEAPON" },
                },
            },
            {
                label = "Set piece",
                fields = {
                    name = "Redemption Tunic", quality = 4, icon = { item = 22416 }, level = 88,
                    equippable = true,
                    slot = "Plate \194\183 Chest",
                    header = { { left = "Binds when picked up", right = "Requires Level 60",
                        rightColor = { .95, .93, .88 } } },
                    armor = { { left = "1027 Armor", right = "", value = "1027" } },
                    primary = { "+31 Intellect", "+25 Stamina" },
                    secondary = { "+1% Critical Strike Chance", "+59 Healing Power", "+10 Mana per 5 sec" },
                    enchant = "+4 All Stats",
                    setName = "Redemption Armor", setCount = "3/9",
                    setItems = {
                        { left = "Redemption Tunic", right = "", active = true },
                        { left = "Redemption Legguards", right = "", active = true },
                        { left = "Redemption Handguards", right = "", active = true },
                        { left = "Redemption Headpiece", right = "", active = false },
                        { left = "Redemption Spaulders", right = "", active = false },
                    },
                    setBonuses = {
                        { left = "(2) Set: Increases the amount healed by your Judgement of Light by 20.",
                            right = "", active = true },
                        { left = "(4) Set: Reduces cooldown on your Lay on Hands by 12 min.",
                            right = "", active = false },
                    },
                    extras = { { left = "Dropped by: Kel'Thuzad", right = "", color = { .17, .51, .77 } } },
                    footerLeft = { { left = "Durability 165 / 165", right = "", durability = { 165, 165 } } },
                    footerRight = {
                        { left = "Requires Argent Dawn - Revered", right = "", requirement = true, met = false },
                        { left = { money = 123767 }, right = "", sellPrice = true },
                    },
                },
            },
            {
                label = "Equipped",
                fields = {
                    name = "Blackhand Doomsaw", quality = 3, icon = { item = 12583 }, level = 63,
                    equippable = true, comparison = true,
                    slot = "Polearm \194\183 Two-Hand",
                    header = { { left = "Soulbound", right = "Requires Level 55", rightColor = { .95, .93, .88 } } },
                    weaponDps = "45.1",
                    weaponDamage = "131 - 197 Damage", weaponSpeed = "Speed 3.60",
                    primary = { "+15 Strength" },
                    extras = {
                        { left = "If you replace this item, the following stat changes will occur:",
                            right = "", color = { .85, .70, 0 } },
                        { left = "-15 Strength", right = "", color = { .85, .13, .13 } },
                        { left = "+13 Stamina", right = "", color = { .09, .85, .09 } },
                        { left = "+62 Attack Power", right = "", color = { .09, .85, .09 } },
                    },
                    footerLeft = { { left = "Durability 100 / 100", right = "", durability = { 100, 100 } } },
                    footerRight = { { left = { money = 41250 }, right = "", sellPrice = true } },
                },
            },
            {
                label = "Potion",
                fields = {
                    name = "Major Healing Potion", quality = 1, icon = { item = 13446 }, level = 55,
                    slot = "Consumable \194\183 Potion",
                    header = { { left = "", right = "Requires Level 45", rightColor = { .95, .93, .88 } } },
                    effects = { { left = "Restores 1050 to 1750 health. (2 Min Cooldown)", right = "", use = true } },
                    footerRight = { { left = { money = 5000, each = 1000, count = 5 }, right = "", sellPrice = true } },
                },
            },
            {
                label = "Recipe",
                fields = {
                    name = "Plans: Veteran's Gloves", quality = 2, icon = "Interface\\Icons\\INV_Scroll_03",
                    slot = "Plans \194\183 Blacksmithing",
                    header = { { left = "Binds when picked up", right = "Requires Blacksmithing 80",
                        rightColor = { .95, .93, .88 } } },
                    created = {
                        name = "Veteran's Gloves", quality = 2, icon = "Interface\\Icons\\INV_Gauntlets_05",
                        slot = "Mail \194\183 Hands", levelRequirement = { text = "Requires Level 15", met = true },
                        armor = { { left = "115 Armor", right = "", value = "115" } },
                        primary = { "+5 Strength", "+3 Agility", "+5 Stamina" },
                    },
                    reagents = {
                        { name = "Bronze Bar", count = 10, have = 4, icon = { item = 2841 } },
                        { name = "Rough Grinding Stone", count = 4, have = 4, icon = { item = 3470 } },
                        { name = "Small Lustrous Pearl", count = 3, have = 1, icon = { item = 5498 } },
                    },
                    footerRight = { { left = { money = 400 }, right = "", sellPrice = true } },
                },
            },
        },
    },
    {
        key = "spell", label = "Spells", dataType = "Spell", model = "spellModel", first = "spellTitle", noun = "spell",
        samples = {
            {
                label = "Fireball",
                fields = {
                    name = "Fireball", rank = "Rank 1", icon = { spell = 133 },
                    cost = { "30", "Mana" }, power = "Mana", cast = { "1.5 sec", "Cast" },
                    range = { "35 yd", "Range" },
                    spellPower = 10,
                    description = { "Hurls a fiery ball that causes 16 to 25 Fire damage and an "
                        .. "additional 2 Fire damage over 4 sec." },
                },
            },
            {
                label = "Ability",
                fields = {
                    name = "Shield Bash", rank = "Rank 1", icon = { spell = 72 },
                    cost = { "10", "Rage" }, power = "Rage", cast = { "Instant", "Cast" },
                    cooldown = { "12 sec", "Cooldown" }, range = { "Melee", "Range" },
                    requirements = { { left = "Requires Shields", right = "", color = { 1, .34, .28 } } },
                    details = { { left = "Cooldown remaining: 8 sec", right = "", color = { 1, .60, .25 } } },
                    description = { "Bashes the target with your shield for 8 damage. It also "
                        .. "interrupts spellcasting and prevents any spell in that school from being "
                        .. "cast for 6 sec." },
                },
            },
            {
                label = "Heal",
                fields = {
                    name = "Holy Light", rank = "Rank 1", icon = { spell = 635 },
                    cost = { "35", "Mana" }, power = "Mana", cast = { "2.5 sec", "Cast" },
                    range = { "40 yd", "Range" },
                    spellPower = 10,
                    description = { "Heals a friendly target for 42 to 51." },
                    extras = { { left = "Spell ID: 635", right = "", color = { .60, .60, .63 } } },
                },
            },
        },
    },
    {
        key = "object", label = "Objects", dataType = "Object", model = "objectModel", first = "objectTitle",
        noun = "object", noLookup = true,
        samples = {
            {
                label = "Herb",
                fields = { name = "Bruiseweed", skill = "Herbalism", skillColor = { 1, .5, .25 } },
                -- Completing the model asks the game for them.
                after = { prices = { { "Sell Price", { money = 40 } }, { "Auction", { money = 1250 } } } },
            },
            {
                label = "Ore",
                fields = {
                    name = "Mithril Deposit", skill = "Mining", skillMet = false,
                    details = { { left = "Requires Mining", right = "", requirement = true, met = false } },
                    extras = { { left = "Gathered here 12 times", right = "", color = { .17, .51, .77 } } },
                },
            },
            {
                label = "Chest",
                fields = {
                    name = "Battered Chest", skill = "Lockpicking",
                    details = {
                        { left = "Locked", right = "" },
                        { left = "Requires Lockpicking (25)", right = "", requirement = true, met = true },
                    },
                },
            },
            {
                label = "Quest",
                fields = {
                    name = "Sealed Supply Crate",
                    quests = {
                        { left = "Heavy Supplies", right = "", title = true },
                        { left = "- Supply Crate: 2/5", right = "" },
                        { left = "- Report to the quartermaster", right = "", completed = true },
                    },
                },
            },
        },
    },
    {
        key = "unit", label = "Units", dataType = "Unit", model = "unitModel", first = "unitName", noun = "unit",
        noLookup = true,
        samples = {
            {
                label = "Player",
                fields = {
                    name = "Somniferie", iconPath = "Interface\\Icons\\INV_Misc_Head_Human_02",
                    isPlayer = true, level = 60, race = "Human", className = "Warrior",
                    classFile = "WARRIOR", guild = "Dawnbreakers", faction = "Alliance", pvp = true,
                    target = "Ragnaros", targetColor = { 1, .27, .22 },
                    extras = { { left = "Item Level 61", right = "", color = { .60, .60, .63 } } },
                },
            },
            {
                label = "Enemy",
                fields = {
                    name = "Defias Pillager", iconPath = "Interface\\Icons\\INV_Misc_Head_Human_01",
                    level = 15, creature = "Humanoid", classification = "elite", reaction = 2,
                    target = "Somniferie", targetIsYou = true,
                    quests = {
                        { left = "The Defias Brotherhood", right = "", title = true },
                        { left = "- Defias Pillager slain: 4/10", right = "" },
                    },
                },
            },
            {
                label = "Vendor",
                fields = {
                    name = "Innkeeper Farley", iconPath = "Interface\\Icons\\INV_Misc_Head_Dwarf_01",
                    tag = "<Innkeeper>", level = 30, creature = "Humanoid", reaction = 5,
                },
            },
            {
                label = "Rare",
                fields = {
                    name = "Mother Fang", iconPath = "Interface\\Icons\\Ability_Hunter_Pet_Spider",
                    level = 10, creature = "Beast", classification = "rare", reaction = 2,
                },
            },
            {
                label = "Rare elite",
                fields = {
                    name = "Foe Reaper 4000", iconPath = "Interface\\Icons\\INV_Misc_Gear_01",
                    level = 20, creature = "Mechanical", classification = "rareelite", reaction = 2,
                },
            },
            {
                label = "Boss",
                fields = {
                    name = "Azuregos", iconPath = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
                    level = -1, creature = "Dragonkin", classification = "worldboss", reaction = 2,
                },
            },
        },
    },
    {
        key = "aura", label = "Buffs", dataType = "UnitAura", model = "auraModel", first = "auraName", noun = "aura",
        noLookup = true,
        samples = {
            {
                label = "Buff",
                fields = {
                    name = "Power Word: Fortitude", icon = { spell = 1245 }, dispel = "Magic",
                    harmful = false, text = "Increases Stamina by 26.", remaining = "17 minutes remaining",
                    duration = 1800, expiresIn = 1020, caster = "Somniferie",
                },
            },
            {
                label = "Curse",
                fields = {
                    name = "Curse of Agony", icon = { spell = 980 }, dispel = "Curse", harmful = true,
                    text = "Causes 84 Shadow damage over 24 sec. This damage is dealt slowly at first, "
                        .. "and builds up as the Curse reaches its full duration.",
                    remaining = "16 seconds remaining", duration = 24, expiresIn = 16,
                },
            },
            {
                label = "Poison",
                fields = {
                    name = "Deadly Poison", icon = { spell = 2818 }, dispel = "Poison", harmful = true,
                    stacks = 3, text = "Inflicts 9 Nature damage every 3 sec.",
                    remaining = "9 seconds remaining", duration = 12, expiresIn = 9,
                },
            },
        },
    },
    {
        key = "quest", label = "Quests", dataType = "Quest", model = "questModel", first = "questTitle", noun = "quest",
        noLookup = true,
        samples = {
            {
                label = "Active",
                fields = {
                    name = "The Fury Runs Deep", level = 27, tags = { "Dungeon" }, zone = "The Stockade",
                    active = true,
                    description = { "Motley Garmason wants Kam Deepfury's head brought to him at Dun Modr." },
                    objectives = { { left = "Head of Deepfury", right = "0/1", completed = false } },
                },
            },
            {
                label = "Ready",
                fields = {
                    name = "Wolves Across the Border", level = 6, active = true, ready = true,
                    description = { "Eliminate the wolves to the east of Northshire and bring their paws to Eagan Peltskinner." },
                    objectives = { { left = "Tough Wolf Meat", right = "8/8", completed = true } },
                    extras = { { left = "Ended by", right = "Eagan Peltskinner" } },
                },
            },
            {
                label = "New",
                fields = {
                    name = "Arugal Must Die", level = 27, tags = { "Dungeon" }, zone = "Shadowfang Keep",
                    description = { "Dalar Dawnweaver wants Arugal dead and his head brought to him." },
                    objectives = { { left = "Head of Arugal" } },
                    extras = { { left = "Started by", right = "Dalar Dawnweaver" },
                        { left = "Found in", right = "Silverpine Forest" } },
                },
            },
        },
    },
    {
        key = "macro", label = "Macros", dataType = "Macro", model = "macroModel", first = "macroName", noun = "macro",
        noLookup = true,
        samples = {
            {
                label = "Cast",
                fields = {
                    name = "Heal", icon = { spell = 19750 },
                    body = { "#showtooltip", "/cast [@mouseover,help,nodead][] Flash of Light" },
                },
            },
            {
                label = "Targeting",
                fields = {
                    name = "Rares", icon = 132212,
                    body = { "/targetexact Mor'Ladim", "/targetexact Sewer Beast", "/run SetRaidTarget(\"target\", 8)" },
                },
            },
        },
    },
}

-- Markers ----------------------------------------------------------------------

local function icon(getter, id)
    if getter then
        local ok, found = pcall(getter, id)
        if ok and found then return found end
    end
    return QUESTION_MARK
end

local function money(marker)
    local text = ui.formatMoney(marker.money)
    if not marker.each then return text end
    return text .. "  |cff9E9485(" .. marker.count .. " \195\151 " .. ui.formatMoney(marker.each) .. ")|r"
end

-- A copy with each marker filled in.
local function resolve(value)
    if type(value) ~= "table" then return value end
    if value.item and next(value, next(value)) == nil then
        return icon(C_Item and C_Item.GetItemIconByID, value.item)
    end
    if value.spell and next(value, next(value)) == nil then
        return icon(C_Spell and C_Spell.GetSpellTexture or GetSpellTexture, value.spell)
    end
    if value.money then return money(value) end
    local copy = {}
    for key, item in pairs(value) do copy[key] = resolve(item) end
    return copy
end

local function stat(text)
    return { left = ns.Stats.styleStat(text, ns.option("statColors"), ns.option("statMarkers")), right = "" }
end

-- An item's stat strings as the rows the settings style, its enchant as rows,
-- and its disenchant results; the crafted item of a recipe likewise.
local function prepareItem(fields)
    for _, list in ipairs({ "primary", "secondary" }) do
        for index, text in ipairs(fields[list] or {}) do
            if type(text) == "string" then fields[list][index] = stat(text) end
        end
    end
    if fields.enchant then
        fields.enchants = {}
        for _, row in ipairs(ui.enchantRows(fields.enchant)) do fields.enchants[#fields.enchants + 1] = { left = row, right = "" } end
        fields.enchant = nil
    end
    if fields.disenchant then
        local spec = fields.disenchant
        fields.disenchant = ns.disenchantFor and ns.disenchantFor(spec[1], spec[2], spec[3], spec[4], nil, ns.Game)
    end
    if fields.created then fields.created = ui.itemModel(prepareItem(fields.created)) end
    return fields
end

-- A sample's model, built fresh on every draw.
local function build(sampleType, sample)
    local fields = resolve(sample.fields)
    if fields.expiresIn then fields.expires, fields.expiresIn = GetTime() + fields.expiresIn, nil end
    if sampleType.key == "item" then prepareItem(fields) end
    local model = ui[sampleType.model](fields)
    for key, value in pairs(resolve(sample.after or {})) do model[key] = value end
    return model
end

-- The types this client has, each with its samples' builders, in order.
function ns.editorSampleTypes()
    local types = {}
    for _, sampleType in ipairs(TYPES) do
        local dataType = Enum.TooltipDataType[sampleType.dataType]
        if dataType and ui[sampleType.model] then
            local samples = {}
            for index, sample in ipairs(sampleType.samples) do
                samples[index] = { label = sample.label, build = function() return build(sampleType, sample) end }
            end
            types[#types + 1] = { key = sampleType.key, label = sampleType.label, dataType = dataType,
                samples = samples, first = sampleType.first, noun = sampleType.noun, noLookup = sampleType.noLookup }
        end
    end
    return types
end
