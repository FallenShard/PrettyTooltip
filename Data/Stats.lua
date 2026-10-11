-- Item wording and formatting rules. Settings are explicit arguments; no game hooks.
local _, ns = ...
local stats = {}
ns.Stats = stats

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

-- Category colors follow EllesmereUI's character sheet; labels are lighter shades.
local PRIMARY_COLOR = "0CD29D"
local PHYSICAL_COLOR = "FF8357"
local DEFENSE_COLOR = "6FBDFF"
local MAGIC_COLOR = "9A71D6"
local HEALING_COLOR = "93D68F"
local MANA_COLOR = "7AC0E6"
local NEGATIVE_COLOR = "FF6B5C"
local STAT_MARKER = "|TInterface\\AddOns\\PrettyTooltip\\art\\stat-marker:9:9:0:-2|t  "

local schoolColors = {
    Arcane = "EB60D6",
    Fire = "FF6D1B",
    Frost = "4CC6F7",
    Holy = "FBBA38",
    Nature = "7FCD48",
    Shadow = "A44EE2",
}

local labelColors = {
    [PRIMARY_COLOR] = "79DCC2",
    [PHYSICAL_COLOR] = "F5B8A1",
    [DEFENSE_COLOR] = "ADD4F5",
    [MAGIC_COLOR] = "C3AFE1",
    [HEALING_COLOR] = "BDE2BB",
    [MANA_COLOR] = "ACD5EB",
    [schoolColors.Arcane] = "F0ADE6",
    [schoolColors.Fire] = "EE9F72",
    [schoolColors.Frost] = "9EDCF5",
    [schoolColors.Holy] = "F6D28A",
    [schoolColors.Nature] = "A6D783",
    [schoolColors.Shadow] = "C595E8",
}

local statColors = {
    Strength = PRIMARY_COLOR,
    Agility = PRIMARY_COLOR,
    Stamina = PRIMARY_COLOR,
    Intellect = PRIMARY_COLOR,
    Spirit = PRIMARY_COLOR,
    ["All Stats"] = PRIMARY_COLOR,

    ["Attack Power"] = PHYSICAL_COLOR,
    ["Ranged Attack Power"] = PHYSICAL_COLOR,
    ["Hit Chance"] = PHYSICAL_COLOR,
    ["Critical Strike Chance"] = PHYSICAL_COLOR,
    ["Hit Rating"] = PHYSICAL_COLOR,
    ["Critical Strike Rating"] = PHYSICAL_COLOR,
    ["Haste Rating"] = PHYSICAL_COLOR,
    ["Expertise Rating"] = PHYSICAL_COLOR,

    Armor = DEFENSE_COLOR,
    ["Defense Skill"] = DEFENSE_COLOR,
    ["Defense Rating"] = DEFENSE_COLOR,
    ["Dodge Chance"] = DEFENSE_COLOR,
    ["Dodge Rating"] = DEFENSE_COLOR,
    ["Parry Chance"] = DEFENSE_COLOR,
    ["Parry Rating"] = DEFENSE_COLOR,
    ["Block Chance"] = DEFENSE_COLOR,
    ["Block Rating"] = DEFENSE_COLOR,
    ["Shield Block Value"] = DEFENSE_COLOR,
    ["Resilience Rating"] = DEFENSE_COLOR,
    ["All Resistances"] = DEFENSE_COLOR,

    ["Spell Power"] = MAGIC_COLOR,
    ["Spell Damage Power"] = MAGIC_COLOR,
    ["Spell Penetration"] = MAGIC_COLOR,
    ["Spell Hit Chance"] = MAGIC_COLOR,
    ["Spell Critical Strike Chance"] = MAGIC_COLOR,
    ["Spell Hit Rating"] = MAGIC_COLOR,
    ["Spell Critical Strike Rating"] = MAGIC_COLOR,
    ["Spell Haste Rating"] = MAGIC_COLOR,

    ["Healing Power"] = HEALING_COLOR,
    ["Health per 5 sec"] = HEALING_COLOR,
    ["Mana per 5 sec"] = MANA_COLOR,
    Mana = MANA_COLOR,
}

local function colorizeStat(text, colors)
    local sign, amount, percent, label = text:match("^([%+%-])([%d%.,]+)(%%?) (.+)$")
    if not amount then return end
    amount = amount:gsub(",", "")

    local color = statColors[label]
    if not color then
        local school = label:match("^(%a+) Spell Power$")
            or label:match("^(%a+) Spell Damage Power$")
            or label:match("^(%a+) Resistance$")
        color = school and schoolColors[school]
    end
    if not color then return end

    local value, name = color, labelColors[color] or color
    if not colors then value, name = "F2E8D5", "A89F8E" end
    if sign == "-" then value = NEGATIVE_COLOR end
    return "|cff" .. value .. sign .. amount .. percent .. "|r |cff" .. name .. label .. "|r"
end

function stats.styleStat(text, colors, markers)
    local colored = colorizeStat(text, colors)
    if not colored then return text end
    -- The second result supplies the marker-free wording for lite mode.
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

    local amount = line:match("^equip: increases damage and healing done by magical spells and effects by up to (%d+)%.?$")
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
