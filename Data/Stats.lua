-- Item wording and formatting rules. Settings are explicit arguments, but for
-- the category colors the style editor may replace; no game hooks.
local _, ns = ...
local util = ns.util
local stats = {}
ns.Stats = stats

local function titleCase(word)
    return word:sub(1, 1):upper() .. word:sub(2)
end

local function bonus(amount, label, percent)
    return "+" .. amount .. (percent and "% " or " ") .. label
end

local ratings = {
    ["hit"] = "Hit Rating",
    ["spell hit"] = "Spell Hit Rating",
    ["critical strike"] = "Critical Strike Rating",
    ["spell critical strike"] = "Spell Critical Strike Rating",
    ["haste"] = "Haste Rating",
    ["spell haste"] = "Spell Haste Rating",
    ["defense"] = "Defense Rating",
    ["dodge"] = "Dodge Rating",
    ["parry"] = "Parry Rating",
    ["block"] = "Block Rating",
    ["resilience"] = "Resilience Rating",
    ["expertise"] = "Expertise Rating",
}

local attributes = {
    ["strength"] = "Strength",
    ["agility"] = "Agility",
    ["stamina"] = "Stamina",
    ["intellect"] = "Intellect",
    ["spirit"] = "Spirit",
    ["armor"] = "Armor",
    ["attack power"] = "Attack Power",
    ["ranged attack power"] = "Ranged Attack Power",
    ["spell power"] = "Spell Power",
    ["spell penetration"] = "Spell Penetration",
    ["all stats"] = "All Stats",
}

local schools = {
    ["arcane"] = "Arcane Spell Damage Power",
    ["fire"] = "Fire Spell Damage Power",
    ["frost"] = "Frost Spell Damage Power",
    ["holy"] = "Holy Spell Damage Power",
    ["nature"] = "Nature Spell Damage Power",
    ["shadow"] = "Shadow Spell Damage Power",
}

-- Category colors are soft and evenly light, so every kind of stat reads
-- alike on the dark panel; the vivid school colors stay apart from them.
-- Each has a lighter, less saturated shade for the stat's name. The style
-- editor can replace a category's color (setting statColor plus its name),
-- and the shade then follows from it.
local CATEGORIES = {
    { key = "Primary", label = "Primary attributes", value = "E9DDC4", name = "EEE7DA" },
    { key = "Attack", label = "Attack", value = "FAA365", name = "F7C5A5" },
    { key = "Defense", label = "Defense", value = "A6C1DD", name = "C7D6E6" },
    { key = "Magic", label = "Magic", value = "C6A9FC", name = "D7C8F7" },
    { key = "Healing", label = "Healing", value = "89DA9B", name = "BDE8C4" },
    { key = "Mana", label = "Mana", value = "9EB8FE", name = "C0D0FA" },
    { key = "Negative", label = "Negative values", value = "F66D67" },
}
local CATEGORY = {}
for _, category in ipairs(CATEGORIES) do CATEGORY[category.key] = category end
stats.CATEGORIES = CATEGORIES
local STAT_MARKER = "|TInterface\\AddOns\\PrettyTooltip\\art\\stat-marker:9:9:0:-2|t  "

local schoolColors = {
    Arcane = "EB60D6",
    Fire = "FF6D1B",
    Frost = "4CC6F7",
    Holy = "FBBA38",
    Nature = "7FCD48",
    Shadow = "C174FF",
}

local labelColors = {
    [schoolColors.Arcane] = "F0ADE6",
    [schoolColors.Fire] = "EE9F72",
    [schoolColors.Frost] = "9EDCF5",
    [schoolColors.Holy] = "F6D28A",
    [schoolColors.Nature] = "A6D783",
    [schoolColors.Shadow] = "C9A2EE",
}

local statCategories = {
    Strength = "Primary",
    Agility = "Primary",
    Stamina = "Primary",
    Intellect = "Primary",
    Spirit = "Primary",
    ["All Stats"] = "Primary",

    ["Attack Power"] = "Attack",
    ["Ranged Attack Power"] = "Attack",
    ["Hit Chance"] = "Attack",
    ["Critical Strike Chance"] = "Attack",
    ["Hit Rating"] = "Attack",
    ["Critical Strike Rating"] = "Attack",
    ["Haste Rating"] = "Attack",
    ["Expertise Rating"] = "Attack",

    Armor = "Defense",
    ["Defense Skill"] = "Defense",
    ["Defense Rating"] = "Defense",
    ["Dodge Chance"] = "Defense",
    ["Dodge Rating"] = "Defense",
    ["Parry Chance"] = "Defense",
    ["Parry Rating"] = "Defense",
    ["Block Chance"] = "Defense",
    ["Block Rating"] = "Defense",
    ["Shield Block Value"] = "Defense",
    ["Resilience Rating"] = "Defense",
    ["All Resistances"] = "Defense",

    ["Spell Power"] = "Magic",
    ["Spell Damage Power"] = "Magic",
    ["Spell Penetration"] = "Magic",
    ["Spell Hit Chance"] = "Magic",
    ["Spell Critical Strike Chance"] = "Magic",
    ["Spell Hit Rating"] = "Magic",
    ["Spell Critical Strike Rating"] = "Magic",
    ["Spell Haste Rating"] = "Magic",

    ["Healing Power"] = "Healing",
    ["Health per 5 sec"] = "Healing",
    ["Mana per 5 sec"] = "Mana",
    Mana = "Mana",
}

-- A category's color and its name's shade, as "RRGGBB": the style editor's,
-- if set, with a shade lifted toward white, else the defaults.
local function categoryColors(key)
    local category = CATEGORY[key]
    local custom = ns.option and ns.option("statColor" .. key)
    if type(custom) == "table" and type(custom[1]) == "number" then
        local shade = {}
        for index = 1, 3 do shade[index] = custom[index] + (1 - custom[index]) * .45 end
        return util.hex(custom), util.hex(shade)
    end
    return category.value, category.name or category.value
end
stats.categoryColors = categoryColors

local function colorizeStat(text, colors)
    local sign, amount, percent, label = text:match("^([%+%-])([%d%.,]+)(%%?) (.+)$")
    if not amount then return end
    amount = amount:gsub(",", "")

    -- A bonus against one kind of creature, "Attack Power vs Undead", takes
    -- its stat's color.
    local category = statCategories[label] or statCategories[label:match("^(.-) vs %a+$") or ""]
    local value, name
    if category then
        value, name = categoryColors(category)
    else
        local school = label:match("^(%a+) Spell Power$")
            or label:match("^(%a+) Spell Damage Power$")
            or label:match("^(%a+) Resistance$")
        value = school and schoolColors[school]
        name = value and labelColors[value]
    end
    if not value then return end

    if not colors then value, name = "F2E8D5", "A89F8E" end
    if sign == "-" then value = categoryColors("Negative") end
    return "|cff" .. value .. sign .. amount .. percent .. "|r |cff" .. name .. label .. "|r"
end

-- Whether a stat row is a spell's: spell power and its schools, spell hit,
-- crit, and penetration, and healing power. Lite mode colors only these.
function stats.isMagical(text)
    local label = text:match("^[%+%-][%d%.,]+%%? (.+)$")
    if not label then return false end
    return statCategories[label] == "Magic" or label == "Healing Power"
        or label:match("^%a+ Spell Power$") ~= nil or label:match("^%a+ Spell Damage Power$") ~= nil
end

function stats.styleStat(text, colors, markers)
    local colored = colorizeStat(text, colors)
    if not colored then return text end
    -- The second result supplies the colored wording without a marker.
    return (markers and STAT_MARKER or "") .. colored, colored
end

-- Weapon damage of a school in that school's stat colors: a wand's
-- "64 - 120 Shadow Damage", or a bonus "+5 - 7 Fire Damage".
function stats.styleDamage(text, colors)
    local amount, school = text:match("^%s*(%+?%s*[%d,]+%s*%-%s*[%d,]+) (%a+) Damage%s*$")
    local color = school and schoolColors[school]
    if not color or not colors then return text end
    return "|cff" .. color .. amount .. "|r |cff" .. labelColors[color] .. school .. " Damage|r"
end

-- Item effects (procs, Use, and Equip) use the same school detection and
-- lighter number colors as spell descriptions, with the same neutral fallback.
function stats.styleEffect(text, colors)
    if not colors then return text end
    text = ns.util.uncolored(text)
    local school = ns.Palette.detectSchool({ text })
    return ns.util.colorNumbers(text, ns.Palette.numberCode(school and ns.Palette.schools[school]))
end

local chanceRules = {
    { "^equip: improves your chance to hit with spells by ([%d%.]+)%%%.?$", "Spell Hit Chance" },
    { "^equip: increases your chance to hit with spells by ([%d%.]+)%%%.?$", "Spell Hit Chance" },
    { "^equip: improves your chance to hit by ([%d%.]+)%%%.?$", "Hit Chance" },
    { "^equip: increases your chance to hit by ([%d%.]+)%%%.?$", "Hit Chance" },
    { "^equip: improves your chance to get a critical strike with spells by ([%d%.]+)%%%.?$", "Spell Critical Strike Chance" },
    { "^equip: improves your chance to get a critical strike by ([%d%.]+)%%%.?$", "Critical Strike Chance" },
    { "^equip: increases your chance to dodge an attack by ([%d%.]+)%%%.?$", "Dodge Chance" },
    { "^equip: increases your chance to parry an attack by ([%d%.]+)%%%.?$", "Parry Chance" },
    { "^equip: increases your chance to block attacks with a shield by ([%d%.]+)%%%.?$", "Block Chance" },
}

local shortEquipStats = {
    ["attack power"] = "Attack Power",
    ["ranged attack power"] = "Ranged Attack Power",
    ["spell power"] = "Spell Power",
    ["spell damage"] = "Spell Damage Power",
    ["healing power"] = "Healing Power",
}

function stats.rewrite(text)
    if type(text) ~= "string" then return end
    local line = ns.util.trim(text):lower()
    -- Bonuses against one kind of creature: Undead, Demons, Elementals, Beasts.
    local creature, amount = line:match("^equip: increases damage done to (%a+) by magical spells and effects by up to (%d+)%.?$")
    if creature then return { bonus(amount, "Spell Damage Power vs " .. titleCase(creature)) } end
    amount, creature = line:match("^equip: %+(%d+) attack power when fighting (%a+)%.?$")
    if not amount then amount, creature = line:match("^equip: increases attack power by (%d+) when fighting (%a+)%.?$") end
    if not amount then amount, creature = line:match("^equip: increases attack power by (%d+) against (%a+)%.?$") end
    if amount then return { bonus(amount, "Attack Power vs " .. titleCase(creature)) } end

    local shortAmount, shortStat = line:match("^equip: %+(%d+) ([%a ]+)%.?$")
    if shortAmount and shortEquipStats[shortStat] then
        return { bonus(shortAmount, shortEquipStats[shortStat]) }
    end

    local healing, damage = line:match("^equip: increases healing done by up to (%d+) and damage done by up to (%d+) for all magical spells and effects%.?$")
    if healing then
        return {
            bonus(healing, "Healing Power"),
            bonus(damage, "Spell Damage Power"),
        }
    end

    amount = line:match("^equip: increases damage and healing done by magical spells and effects by up to (%d+)%.?$")
        or line:match("^equip: increases spell damage and healing by up to (%d+)%.?$")
        or line:match("^equip: increases damage and healing done by spells and effects by up to (%d+)%.?$")
    if amount then return { bonus(amount, "Spell Power") } end

    amount = line:match("^equip: increases healing done by spells and effects by up to (%d+)%.?$")
        or line:match("^equip: increases healing done by magical spells and effects by up to (%d+)%.?$")
        or line:match("^equip: increases healing done by up to (%d+) for all magical spells and effects%.?$")
    if amount then return { bonus(amount, "Healing Power") } end

    local school
    school, amount = line:match("^equip: increases damage done by (%a+) spells and effects by up to (%d+)%.?$")
    if school and schools[school] then return { bonus(amount, schools[school]) } end

    amount = line:match("^equip: increases damage done by magical spells and effects by up to (%d+)%.?$")
        or line:match("^equip: increases spell damage by up to (%d+)%.?$")
    if amount then return { bonus(amount, "Spell Damage Power") } end

    local stat
    stat, amount = line:match("^equip: increases your ([%a ]+) rating by (%d+)%.?$")
    if not stat then
        stat, amount = line:match("^equip: improves ([%a ]+) rating by (%d+)%.?$")
    end
    if stat and ratings[stat] then return { bonus(amount, ratings[stat]) } end

    stat, amount = line:match("^equip: increases your ([%a ]+) by (%d+)%.?$")
    if not stat then stat, amount = line:match("^equip: increases ([%a ]+) by (%d+)%.?$") end
    if stat and attributes[stat] then return { bonus(amount, attributes[stat]) } end

    for _, rule in ipairs(chanceRules) do
        amount = line:match(rule[1])
        if amount then return { bonus(amount, rule[2], true) } end
    end

    amount = line:match("^equip: increases defense skill by (%d+)%.?$")
        or line:match("^equip: increases your defense skill by (%d+)%.?$")
        or line:match("^equip: increased defense %+(%d+)%.?$")
    if amount then return { bonus(amount, "Defense Skill") } end

    amount = line:match("^equip: increases the block value of your shield by (%d+)%.?$")
    if amount then return { bonus(amount, "Shield Block Value") } end

    amount = line:match("^equip: restores (%d+) mana per 5 sec%.?$")
        or line:match("^equip: restores (%d+) mana per 5 seconds%.?$")
    if amount then return { bonus(amount, "Mana per 5 sec") } end

    amount = line:match("^equip: restores (%d+) health per 5 sec%.?$")
        or line:match("^equip: restores (%d+) health per 5 seconds%.?$")
    if amount then return { bonus(amount, "Health per 5 sec") } end

    amount = line:match("^equip: decreases the magical resistances of your spell targets by (%d+)%.?$")
    if amount then return { bonus(amount, "Spell Penetration") } end
end
