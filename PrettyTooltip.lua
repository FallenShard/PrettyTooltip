-- Short, colored stat wording. WoW Forever (1.60.x) uses the modern tooltip
-- data pipeline, so rewriting the item data before it is rendered reaches the
-- panel and the game's own tooltip alike, and gives split bonuses their own rows.
local _, ns = ...
if GetLocale() ~= "enUS" then
    return
end

if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPreCall
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item) then
    return
end

local isSecret = issecretvalue or function() return false end

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

-- Values use richer colors; labels use lighter, softer shades of the same hue.
-- Primary, physical, defense, and magic follow EllesmereUI's character sheet
-- defaults (Attributes, Attack, Defense, Secondary Stats). All but primary are
-- mixed a quarter toward white to stay readable on the dark panel.
local PRIMARY_COLOR = "0CD29D"
local PHYSICAL_COLOR = "FF8357"
local DEFENSE_COLOR = "6FBDFF"
local MAGIC_COLOR = "9A71D6"
local HEALING_COLOR = "93D68F"
local MANA_COLOR = "7AC0E6"
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

local function colorizeStat(text)
    local amount, percent, label = text:match("^%+([%d%.]+)(%%?) (.+)$")
    if not amount then return end

    local color = statColors[label]
    if not color then
        local school = label:match("^(%a+) Spell Power$")
            or label:match("^(%a+) Spell Damage Power$")
            or label:match("^(%a+) Resistance$")
        color = school and schoolColors[school]
    end
    if not color then return end

    local value, name = color, labelColors[color] or color
    if not ns.option("statColors") then value, name = "F2E8D5", "A89F8E" end
    return "|cff" .. value .. "+" .. amount .. percent .. "|r |cff" .. name .. label .. "|r"
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

local function rewrite(text)
    if type(text) ~= "string" then return end
    local line = text:match("^%s*(.-)%s*$"):lower()
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

local activeLinesByTooltip = setmetatable({}, { __mode = "k" })
local hookedTooltips = setmetatable({}, { __mode = "k" })

local function onItemTooltip(_, data)
    if isSecret(data) or not data then return end
    local lines = data.lines
    if isSecret(lines) or not lines then return end

    -- Keep the line table and its length intact. Other addons may have added
    -- rows to the same cached tooltip data since our previous pass.
    for index, source in ipairs(lines) do
        if not isSecret(source) and source and not source.prettyTooltipOriginal then
            local text = source.leftText
            local rightText = source.rightText
            if not isSecret(text) and type(text) == "string"
                and not isSecret(rightText) and not rightText then
                local replacements = rewrite(text)
                local displayLines = replacements or { text }
                local styled = false
                for displayIndex, displayText in ipairs(displayLines) do
                    local colored = colorizeStat(displayText)
                    if colored then
                        displayLines[displayIndex] = (ns.option("statMarkers") and STAT_MARKER or "") .. colored
                        styled = true
                    end
                end
                if replacements or styled then
                    local copy = {}
                    for key, value in pairs(source) do
                        copy[key] = value
                    end
                    -- A line break gives combined bonuses two visual lines
                    -- while preserving every other addon's tooltip row.
                    copy.leftText = table.concat(displayLines, "|n")
                    copy.wrapText = copy.wrapText or #displayLines > 1
                    copy.prettyTooltipOriginal = text
                    copy.prettyTooltipDisplay = copy.leftText
                    copy.lineIndex = nil
                    lines[index] = copy
                end
            end
        end
    end
end

TooltipDataProcessor.AddTooltipPreCall(Enum.TooltipDataType.Item, onItemTooltip)

-- The rewrite above changes the game's own tooltip text too, so the original
-- wording goes back on its font strings while the original-tooltip key is held.
local function showOriginalText(tooltip, original, relayout)
    local rows = activeLinesByTooltip[tooltip]
    if not rows then return end
    for _, row in ipairs(rows) do
        row.fontString:SetText(original and row.original or row.display)
    end
    if relayout then tooltip:Show() end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if isSecret(data) or not data then return end
    local lines = data.lines
    if isSecret(lines) or not lines then return end

    if not hookedTooltips[tooltip] then
        local function forget(cleared) activeLinesByTooltip[cleared] = nil end
        tooltip:HookScript("OnHide", forget)
        tooltip:HookScript("OnTooltipCleared", forget)
        hookedTooltips[tooltip] = true
    end

    local info = tooltip:GetProcessingTooltipInfo()
    local rows = (info and info.append and activeLinesByTooltip[tooltip]) or {}
    for _, line in ipairs(lines) do
        if not isSecret(line) and line and line.lineIndex and line.prettyTooltipOriginal then
            local fontString = tooltip:GetLeftLine(line.lineIndex)
            if fontString then
                rows[#rows + 1] = {
                    fontString = fontString,
                    original = line.prettyTooltipOriginal,
                    display = line.prettyTooltipDisplay,
                }
            end
        end
    end
    activeLinesByTooltip[tooltip] = #rows > 0 and rows or nil
    showOriginalText(tooltip, ns.originalKeyDown(), false)
end)

local modifierWatcher = CreateFrame("Frame")
modifierWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
modifierWatcher:SetScript("OnEvent", function(_, _, key)
    if not ns.isOriginalKey(key) then return end
    local original = ns.originalKeyDown()
    for tooltip in pairs(activeLinesByTooltip) do
        if tooltip:IsShown() and tooltip:IsTooltipType(Enum.TooltipDataType.Item) then
            showOriginalText(tooltip, original, true)
        end
    end
end)
