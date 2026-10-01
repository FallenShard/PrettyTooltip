-- The panel that replaces item tooltips (and, through PrettyTooltipSpell.lua,
-- spell tooltips). The game's tooltip stays intact underneath, hidden, and is
-- shown while the original-tooltip key is held or a line cannot safely be read.
local _, ns = ...
if GetLocale() ~= "enUS" or not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then
    return
end

local isSecret = issecretvalue or function() return false end
local ITEM = Enum.TooltipDataType.Item
local LINE = Enum.TooltipDataLineType
local ART = "Interface\\AddOns\\PrettyTooltip\\art\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
-- The game's tooltip fonts, read at use time so a UI addon that replaces the
-- default font is followed. Friz Quadrata unless something changed it.
local function fontOf(object)
    local path = object and object.GetFont and object:GetFont()
    return path or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end
local function bodyFont() return fontOf(GameTooltipText) end
-- Expressway is a commercial font, so like DialogueUI's art it is used from
-- EllesmereUI's folder when that addon is installed, never copied here.
local ELLESMERE_BOLD = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway Bold.ttf"
local MIN_WIDTH, MAX_WIDTH = 260, 408
-- Wrapping prose (effects, set bonuses, flavor text) asks for this much inner
-- width at most; everything else must fit on one line.
local PROSE_WIDTH = 270
local PAD = 19
local COLUMN_GAP = 12
local ICON_SIZE = 43
-- Header text starts past the icon, which sits at the left.
local HEADER_INDENT = ICON_SIZE + 10
local ICON_TOP = 21
-- The title's text box starts level with the icon, so its capitals sit a
-- few pixels below the icon's edge instead of almost touching it.
local TITLE_TOP = ICON_TOP
local BADGE_GAP = 5
local BADGE_HEIGHT = 16
local EXTRA_COLOR = { .60, .60, .63 }
local GOLD_RULE = { .78, .59, .32 }
-- Flavor text and the crafter's signature.
local FLAVOR_GOLD = { .86, .74, .45 }
local QUEST_GOLD = { 1, .82, 0 }
local QUEST_CLASS = Enum.ItemClass and Enum.ItemClass.Questitem or 12
local CONSUMABLE_CLASS = Enum.ItemClass and Enum.ItemClass.Consumable or 0
local DELTA_UP = { .42, .86, .42 }
local DELTA_DOWN = { 1, .42, .36 }
local DURABILITY_BAR = 54
local HALO_SPREAD = 16
-- Must match MARGIN in art/make_glow.py.
local HALO_MARGIN = 24
-- DialogueUI's art belongs to its author, so it is used where that addon is
-- installed rather than copied into this one.
local DIALOGUE_BACKDROP = "Interface\\AddOns\\DialogueUI\\Art\\Theme_Dark\\TooltipBackground-Temp.png"
local STAT_LABELS = {
    ITEM_MOD_STRENGTH_SHORT = "Strength",
    ITEM_MOD_AGILITY_SHORT = "Agility",
    ITEM_MOD_STAMINA_SHORT = "Stamina",
    ITEM_MOD_INTELLECT_SHORT = "Intellect",
    ITEM_MOD_SPIRIT_SHORT = "Spirit",
    ITEM_MOD_ATTACK_POWER_SHORT = "Attack Power",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "Ranged Attack Power",
    ITEM_MOD_SPELL_POWER_SHORT = "Spell Power",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "Spell Damage Power",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "Healing Power",
    ITEM_MOD_SPELL_PENETRATION_SHORT = "Spell Penetration",
    ITEM_MOD_HIT_RATING_SHORT = "Hit Rating",
    ITEM_MOD_HIT_MELEE_RATING_SHORT = "Hit Rating",
    ITEM_MOD_HIT_SPELL_RATING_SHORT = "Spell Hit Rating",
    ITEM_MOD_CRIT_RATING_SHORT = "Critical Strike Rating",
    ITEM_MOD_CRIT_MELEE_RATING_SHORT = "Critical Strike Rating",
    ITEM_MOD_CRIT_SPELL_RATING_SHORT = "Spell Critical Strike Rating",
    ITEM_MOD_HASTE_RATING_SHORT = "Haste Rating",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "Defense Rating",
    ITEM_MOD_DODGE_RATING_SHORT = "Dodge Rating",
    ITEM_MOD_PARRY_RATING_SHORT = "Parry Rating",
    ITEM_MOD_BLOCK_RATING_SHORT = "Block Rating",
    ITEM_MOD_BLOCK_VALUE_SHORT = "Shield Block Value",
    ITEM_MOD_MANA_REGENERATION_SHORT = "Mana per 5 sec",
    ITEM_MOD_POWER_REGEN0_SHORT = "Mana per 5 sec",
    ITEM_MOD_HEALTH_REGEN_SHORT = "Health per 5 sec",
    ITEM_MOD_HEALTH_REGENERATION_SHORT = "Health per 5 sec",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "Damage per Second",
    RESISTANCE0_NAME = "Armor",
    RESISTANCE1_NAME = "Holy Resistance",
    RESISTANCE2_NAME = "Fire Resistance",
    RESISTANCE3_NAME = "Nature Resistance",
    RESISTANCE4_NAME = "Frost Resistance",
    RESISTANCE5_NAME = "Shadow Resistance",
    RESISTANCE6_NAME = "Arcane Resistance",
}
-- Percentage lines on older items report through the matching rating key.
local ROW_ALIASES = {
    ["Hit Chance"] = "Hit Rating",
    ["Critical Strike Chance"] = "Critical Strike Rating",
    ["Spell Hit Chance"] = "Spell Hit Rating",
    ["Spell Critical Strike Chance"] = "Spell Critical Strike Rating",
    ["Defense Skill"] = "Defense Rating",
    ["Dodge Chance"] = "Dodge Rating",
    ["Parry Chance"] = "Parry Rating",
    ["Block Chance"] = "Block Rating",
}
local QUALITY = {
    [0] = { .62, .62, .62 },
    [1] = { .77, .77, .77 },
    [2] = { .30, .82, .30 },
    [3] = { .32, .59, .98 },
    [4] = { .72, .40, .94 },
    [5] = { 1.00, .57, .22 },
}
-- The first stat block, as on EllesmereUI's character sheet; every other stat
-- follows under a divider, like its Secondary Stats.
local PRIMARY_STATS = {
    Strength = true, Agility = true, Stamina = true, Intellect = true, Spirit = true,
    ["All Stats"] = true,
}
-- Lines that say what an item is, shown with the slot and type in this order.
local ITEM_KINDS = { "Crafting Reagent", "Scarce" }
local ITEM_KIND_NAMES = {}
for _, kind in ipairs(ITEM_KINDS) do ITEM_KIND_NAMES[kind:lower()] = kind end
local panels = setmetatable({}, { __mode = "k" })

local function safeText(value)
    if isSecret(value) then return nil end
    if value == nil then return "" end
    if type(value) ~= "string" then return nil end
    return value
end

local function getItemInfo(tooltip, data)
    if tooltip.GetItem then
        local ok, _, link = pcall(tooltip.GetItem, tooltip)
        if ok and not isSecret(link) and link then return link end
    end
    if not isSecret(data.hyperlink) and data.hyperlink then return data.hyperlink end
    if not isSecret(data.id) then return data.id end
end

local function getQuality(itemInfo, data)
    if itemInfo and C_Item and C_Item.GetItemInfo then
        local ok, _, _, quality = pcall(C_Item.GetItemInfo, itemInfo)
        if ok and not isSecret(quality) and type(quality) == "number" then
            return quality
        end
    end
    if not isSecret(data.quality) and type(data.quality) == "number" then
        return data.quality
    end
    return 1
end

local function getIcon(itemInfo)
    if not (itemInfo and C_Item and C_Item.GetItemIconByID) then return end
    local ok, icon = pcall(C_Item.GetItemIconByID, itemInfo)
    if ok and not isSecret(icon) then return icon end
end

local function getLevel(itemInfo)
    if not (itemInfo and C_Item and C_Item.GetDetailedItemLevelInfo) then return end
    local ok, level = pcall(C_Item.GetDetailedItemLevelInfo, itemInfo)
    if ok and not isSecret(level) and type(level) == "number" and level > 0 then
        return level
    end
end

local function add(list, left, right)
    list[#list + 1] = { left = left, right = right }
end

-- Other addons' rows are secondary: default white goes grey, and their own
-- accent colours are kept but muted.
local function quietColor(r, g, b)
    if isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number"
        or (r > .9 and g > .9 and b > .9) then
        return EXTRA_COLOR
    end
    return { r * .85, g * .85, b * .85 }
end

local function colorOf(color)
    if isSecret(color) or type(color) ~= "table" then return EXTRA_COLOR end
    return quietColor(color.r, color.g, color.b)
end

-- The game greys set pieces you lack and bonuses that are not active yet.
local function isActive(color)
    if isSecret(color) or type(color) ~= "table" then return nil end
    local r, g, b = color.r, color.g, color.b
    if isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return nil
    end
    return not (r < .7 and math.abs(r - g) < .06 and math.abs(g - b) < .06)
end

local function addExtra(model, left, right, leftColor, rightColor)
    add(model.extras, left, right)
    local row = model.extras[#model.extras]
    row.color, row.rightColor = leftColor, rightColor
end

-- Level is checked directly. Skill, reputation, and other requirements trust
-- the game, which colors an unmet requirement red.
-- The game colors whatever the character cannot use red: an armor or weapon
-- type, a class or race list, an unmet requirement. Nil when unreadable.
local function isRed(color)
    if isSecret(color) or type(color) ~= "table" then return nil end
    local r, g = color.r, color.g
    if isSecret(r) or isSecret(g) or type(r) ~= "number" or type(g) ~= "number" then
        return nil
    end
    return r > .9 and g < .3
end

local UNUSABLE_COLOR = { 1, .34, .28 }

local function unusable(text, color)
    if isRed(color) then return "|cffFF5747" .. text .. "|r" end
    return text
end

local function requirementMet(text, color)
    local level = text:match("^Requires Level (%d+)")
    if level then
        local playerLevel = UnitLevel("player")
        if not isSecret(playerLevel) and type(playerLevel) == "number" then
            return playerLevel >= tonumber(level)
        end
    end
    return isRed(color) == false
end

local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:0:0:2:0|t"

local function formatMoney(copper)
    local format = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString
        or GetCoinTextureString
    if format then
        local ok, text = pcall(format, copper)
        if ok and not isSecret(text) and type(text) == "string" then return text end
    end
    local parts = {}
    local gold, silver = math.floor(copper / 10000), math.floor(copper / 100) % 100
    if gold > 0 then parts[#parts + 1] = gold .. COIN:format("Gold") end
    if silver > 0 then parts[#parts + 1] = silver .. COIN:format("Silver") end
    if copper % 100 > 0 or #parts == 0 then
        parts[#parts + 1] = copper % 100 .. COIN:format("Copper")
    end
    return table.concat(parts, " ")
end

local function plainText(text)
    return (text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- These lines can arrive color coded, or appended outside the tooltip data.
-- Each keeps the color it was given, inline or on the line.
local function itemKind(left, right, color)
    if right ~= "" then return end
    local kind = ITEM_KIND_NAMES[plainText(left):match("^%s*(.-)%s*$"):lower()]
    if not kind then return end
    local code = left:match("|c(%x%x%x%x%x%x%x%x)")
    if code then return kind, "|c" .. code .. kind .. "|r" end
    if isSecret(color) or type(color) ~= "table" then return kind, kind end
    local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
    if isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return kind, kind
    end
    return kind, string.format("|cff%02X%02X%02X%s|r", math.floor(r * 255 + .5),
        math.floor(g * 255 + .5), math.floor(b * 255 + .5), kind)
end

-- Enchants use the game's enchant green, marker included, so they read as
-- added to the item rather than part of it.
local ENCHANT_VALUE, ENCHANT_LABEL = "4CE64C", "A6EBA6"
-- Must match STAT_MARKER in PrettyTooltip.lua, minus its trailing spaces.
local STAT_MARKER = "|T" .. ART .. "stat-marker:9:9:0:-2|t"
-- Equip effects with no stat wording: the game's equip green.
local EQUIP_EFFECT_COLOR = { .48, .88, .48 }
local ENCHANT_MARKER = "|T" .. ART .. "stat-marker:9:9:0:-2:32:32:0:32:0:32:90:230:60|t  "

-- "Stamina +1 and Armor +8" becomes one row per bonus, value first like the
-- stat rows. Named enchants ("Crusader") stay whole.
local function enchantRows(text)
    local rows = {}
    local marker = ns.option("statMarkers") and ENCHANT_MARKER or ""
    for piece in (text:gsub(", and ", ", "):gsub(" and ", ", ") .. ", "):gmatch("(.-), ") do
        local name, amount = piece:match("^(.-) %+(%d+%%?)$")
        if not name then amount, name = piece:match("^%+(%d+%%?) (.+)$") end
        if not name then
            return { marker .. "|cff" .. ENCHANT_VALUE .. text .. "|r" }
        end
        rows[#rows + 1] = marker .. "|cff" .. ENCHANT_VALUE .. "+" .. amount
            .. "|r |cff" .. ENCHANT_LABEL .. name .. "|r"
    end
    return rows
end

-- Lines about this copy of the item: its crafter and its enchant. Either can
-- arrive color coded, or appended outside the tooltip data.
local function readCopyLine(model, left, right)
    if right ~= "" then return false end
    local text = plainText(left):match("^%s*(.-)%s*$")
    local maker = text:match("^<Made by (.+)>$")
    if maker then
        model.madeBy = maker
        return true
    end
    local enchant = text:match("^Enchanted:%s*(.+)$")
    if enchant then
        for _, row in ipairs(enchantRows(enchant)) do add(model.enchants, row, "") end
        return true
    end
    return false
end

local function valueLabel(value, label)
    return "|cffF2E8D5" .. value .. "|r |cffA89F8E" .. label .. "|r"
end

local function formatDelta(value)
    if math.abs(value - math.floor(value + .5)) > .001 then
        return string.format("%+.1f", value)
    end
    return string.format("%+d", value >= 0 and math.floor(value + .5) or math.ceil(value - .5))
end

local function statLabel(key)
    if STAT_LABELS[key] then return STAT_LABELS[key] end
    if not key:find("^ITEM_MOD_") and not key:find("^RESISTANCE%d") then return key end
    local label = key:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", ""):gsub("_NAME$", "")
        :gsub("_", " "):lower()
    return (label:gsub("(%a)([%w']*)", function(first, rest) return first:upper() .. rest end))
end

-- Deltas against the item the game's own comparison tooltip is showing, so
-- the arrows appear exactly when the comparison does.
local function getDeltas(tooltip, itemLink)
    if not (C_Item and C_Item.GetItemStatDelta) or type(itemLink) ~= "string" then return end
    local compare = tooltip.shoppingTooltips and tooltip.shoppingTooltips[1]
    if not (compare and compare:IsShown() and compare.GetItem) then return end
    local ok, _, equipped = pcall(compare.GetItem, compare)
    if not ok or isSecret(equipped) or type(equipped) ~= "string" then return end
    local found, deltas = pcall(C_Item.GetItemStatDelta, itemLink, equipped)
    if not found or isSecret(deltas) or type(deltas) ~= "table" then return end
    local byLabel = {}
    for key, value in pairs(deltas) do
        if not isSecret(key) and not isSecret(value) and type(key) == "string"
            and type(value) == "number" and math.abs(value) > .0001 then
            local label = statLabel(key)
            if byLabel[label] == nil then byLabel[label] = value end
        end
    end
    return byLabel
end

local function attachDeltas(model, deltas)
    local function take(row, label)
        label = ROW_ALIASES[label] or label
        local value = deltas[label]
        if value == nil then return end
        deltas[label] = nil
        if row and (not row.right or row.right == "") then
            row.right = formatDelta(value)
            row.rightColor = value > 0 and DELTA_UP or DELTA_DOWN
        end
        return value
    end
    for _, list in ipairs({ model.armor, model.primary, model.secondary }) do
        for _, row in ipairs(list) do
            local label = plainText(row.left):match("^%s*%+?[%d%.]+%%? (.+)$")
            if label then take(row, label) end
        end
    end
    if model.weaponDps then model.weaponDpsDelta = take(nil, "Damage per Second") end
    -- Stats only the equipped item has; a gain with no row is a wording mismatch.
    for label, value in pairs(deltas) do
        if value < 0 then
            add(model.lost, label, formatDelta(value))
            model.lost[#model.lost].rightColor = DELTA_DOWN
        end
    end
    table.sort(model.lost, function(a, b) return a.left < b.left end)
end

local function isInstalled(addon)
    if not (C_AddOns and C_AddOns.GetAddOnInfo) then return false end
    local ok, name, _, _, _, reason = pcall(C_AddOns.GetAddOnInfo, addon)
    return ok and name ~= nil and reason ~= "MISSING"
end

local function hasDialogueBackdrop()
    return isInstalled("DialogueUI")
end

-- The font for item, spell, and set names: EllesmereUI's Expressway Bold when
-- it is installed, else the game's tooltip header font.
local hasEllesmere
local function titleFont()
    if hasEllesmere == nil then hasEllesmere = isInstalled("EllesmereUI") end
    return hasEllesmere and ELLESMERE_BOLD or fontOf(GameTooltipHeaderText)
end

-- Rows other addons append straight to the tooltip are absent from its data.
-- Returns nil when one of them cannot be read.
local function appendedRows(tooltip, lineIndices)
    local rows = {}
    local name = tooltip:GetName()
    for index = 1, tooltip:NumLines() do
        if not lineIndices[index] then
            local leftFont = tooltip:GetLeftLine(index)
            local rightFont = tooltip.GetRightLine and tooltip:GetRightLine(index)
                or (name and _G[name .. "TextRight" .. index])
            local left = leftFont and safeText(leftFont:GetText()) or ""
            local right = rightFont and safeText(rightFont:GetText()) or ""
            if not left or not right then return end
            rows[#rows + 1] = {
                left = left,
                right = right,
                color = leftFont and quietColor(leftFont:GetTextColor()) or EXTRA_COLOR,
                textColor = leftFont and { leftFont:GetTextColor() },
                rightColor = rightFont and quietColor(rightFont:GetTextColor()),
            }
        end
    end
    return rows
end

local function readModel(tooltip, data)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local itemInfo = getItemInfo(tooltip, data)
    local model = {
        link = itemInfo,
        quality = getQuality(itemInfo, data),
        icon = getIcon(itemInfo),
        level = getLevel(itemInfo),
        header = {},
        armor = {},
        primary = {},
        secondary = {},
        equipEffects = {},
        enchants = {},
        effects = {},
        flavor = {},
        lost = {},
        setItems = {},
        setBonuses = {},
        extras = {},
        footerLeft = {},
        footerRight = {},
        lineIndices = {},
        kinds = {},
    }
    local inSet, setTotal = false, 0

    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.type) or isSecret(line.lineIndex) then
            return
        end
        -- The amount is drawn by a money frame, not as text, so take it from the data.
        if LINE.SellPrice and line.type == LINE.SellPrice then
            model.hasSellPrice = true
            if not isSecret(line.price) and type(line.price) == "number" then
                model.sellPrice = line.price
            end
        end
        if line.lineIndex then
        local left, right = safeText(line.leftText), safeText(line.rightText)
        if not left or not right then return end
        local lineType = line.type
        if line.lineIndex then model.lineIndices[line.lineIndex] = true end
        local trimmed = left:match("^%s*(.-)%s*$")
        if trimmed == "Quest Item" or trimmed:match("^This Item Begins a Quest") then
            model.quest = true
        end
        if isSecret(line.prettyTooltipDisplay) or isSecret(line.prettyTooltipOriginal) then return end
        local displayed = line.prettyTooltipDisplay or left

        if lineType == LINE.ItemName then
            -- Recipes embed the crafted item's tooltip, name line included.
            model.name = model.name or left
        elseif lineType == LINE.ItemLevel then
            local level = left:match("(%d+)")
            if level then model.level, model.levelLine = tonumber(level), true end
        elseif lineType == LINE.EquipSlot then
            model.equippable = true
            local slot = unusable(left, line.leftColor)
            local kind = unusable(right, line.rightColor)
            model.slot = right ~= "" and (kind .. " \194\183 " .. slot) or slot
        elseif lineType == LINE.ItemBinding or trimmed:match("^Binds ")
            or trimmed == "Soulbound" or trimmed:match("^Unique") then
            add(model.header, left, right)
            if isRed(line.leftColor) then model.header[#model.header].color = UNUSABLE_COLOR end
        elseif itemKind(left, right) then
            local kind, text = itemKind(left, right, line.leftColor)
            model.kinds[kind] = text
        elseif trimmed ~= "" then
            local setName, count, total = trimmed:match("^(.-) %((%d+)/(%d+)%)$")
            if setName and not model.setName then
                model.setName, model.setCount = setName, count .. "/" .. total
                inSet, setTotal = true, tonumber(total)
            elseif LINE.SellPrice and lineType == LINE.SellPrice then
                model.hasSellPrice = true
            elseif trimmed:match("^Requires Level %d+$") and right == "" then
                model.levelRequirement = {
                    text = trimmed, met = requirementMet(trimmed, line.leftColor),
                }
            elseif trimmed:match("^Requires ") then
                add(model.footerRight, left, right)
                local entry = model.footerRight[#model.footerRight]
                entry.requirement = true
                entry.met = requirementMet(trimmed, line.leftColor)
            elseif trimmed:match("^Durability %d+ / %d+$") then
                add(model.footerLeft, trimmed, right)
                local current, maximum = trimmed:match("(%d+) / (%d+)")
                model.footerLeft[#model.footerLeft].durability =
                    { tonumber(current), tonumber(maximum) }
            elseif trimmed:match("^Classes:") or trimmed:match("^Races:")
                or trimmed:match("^You haven't collected") or trimmed:match("^Appearance ") then
                add(model.footerLeft, left, right)
                if isRed(line.leftColor) then
                    model.footerLeft[#model.footerLeft].color = UNUSABLE_COLOR
                end
            elseif inSet and trimmed:match("^%(%d+%) Set:") then
                add(model.setBonuses, left, right)
                model.setBonuses[#model.setBonuses].active = isActive(line.leftColor)
            elseif inSet and #model.setItems < setTotal
                and right == "" and trimmed:match("^[%a'%- ]+$") then
                add(model.setItems, trimmed, right)
                model.setItems[#model.setItems].active = isActive(line.leftColor)
            elseif right:match("^Speed [%d%.]+$") and trimmed:match("^%d+%s*%-%s*%d+ Damage$") then
                model.weaponDamage, model.weaponSpeed = left, right
            elseif trimmed:match("^%([%d%.]+ damage per second%)$") then
                model.weaponDps = trimmed:match("^%(([%d%.]+) damage per second%)$")
            elseif trimmed:match("^%d+ Armor$") then
                add(model.armor, left, right)
                model.armor[#model.armor].value = trimmed:match("^(%d+)")
            elseif line.prettyTooltipOriginal or trimmed:match("^%+[%d%.]+") then
                -- Combined bonuses arrive as one line; each stat needs its own row.
                for piece in (displayed .. "|n"):gmatch("(.-)|n") do
                    local label = plainText(piece):match("^%s*%+?[%d%.]+%%? (.+)$")
                    add(PRIMARY_STATS[label] and model.primary or model.secondary, piece, right)
                    right = ""
                end
            elseif trimmed:match('^".+"$') then
                add(model.flavor, left, right)
            elseif readCopyLine(model, left, right) then
                -- Crafter or enchant, taken into their own rows.
            elseif trimmed:match("^<.+>$") then
                add(model.effects, left, right)
            elseif trimmed:match("^Equip:") and right == "" then
                -- Unparsed equip effects join the stats; the list implies "Equip:".
                add(model.equipEffects, (trimmed:gsub("^Equip:%s*", "")), "")
            elseif trimmed:match("^Equip:") or trimmed:match("^Use:") then
                add(model.effects, left, right)
            else
                addExtra(model, left, right, colorOf(line.leftColor), colorOf(line.rightColor))
            end
        end
        end
    end

    if not model.name or model.name == "" then return end
    local appended = appendedRows(tooltip, model.lineIndices)
    if not appended then return end
    for _, row in ipairs(appended) do
        local trimmed = row.left:match("^%s*(.-)%s*$")
        if trimmed:match("^Sell Price") then
            model.hasSellPrice = true
        elseif itemKind(row.left, row.right) then
            local kind, text = itemKind(row.left, row.right, row.textColor)
            model.kinds[kind] = text
        elseif readCopyLine(model, row.left, row.right) then
            -- Crafter or enchant, taken into their own rows.
        elseif trimmed ~= "" or row.right ~= "" then
            model.extras[#model.extras + 1] = row
        end
    end
    local classID, className, subClassName
    if itemInfo and C_Item and C_Item.GetItemInfoInstant then
        local ok, _, itemType, itemSubType, _, _, itemClassID = pcall(C_Item.GetItemInfoInstant, itemInfo)
        if ok and not isSecret(itemClassID) and not isSecret(itemType) and not isSecret(itemSubType) then
            classID, className, subClassName = itemClassID, itemType, itemSubType
        end
    end
    -- The level is the requirement that most often blocks an item, so it
    -- sits in the header across from the binding.
    local level = model.levelRequirement
    if level then
        if #model.header == 0 then add(model.header, "", "") end
        local row = model.header[1]
        if row.right == "" then
            row.right = level.text
            row.rightColor = level.met and { .95, .93, .88 } or UNUSABLE_COLOR
        else
            add(model.footerRight, level.text, "")
            local entry = model.footerRight[#model.footerRight]
            entry.requirement, entry.met = true, level.met
        end
    end
    -- Signed under the durability bar, which is where the footer starts to
    -- describe this particular copy of the item.
    if model.madeBy then
        local at = 1
        for index, entry in ipairs(model.footerLeft) do
            if entry.durability then at = index + 1 end
        end
        table.insert(model.footerLeft, at, {
            left = "Made by " .. model.madeBy,
            right = "",
            color = FLAVOR_GOLD,
        })
    end
    local shown = {}
    -- The game's tooltip never says an item is a consumable, or what kind.
    if classID == CONSUMABLE_CLASS and type(className) == "string" and className ~= "" then
        shown[1] = className
        if type(subClassName) == "string" and subClassName ~= "" and subClassName ~= className then
            shown[1] = className .. " \194\183 " .. subClassName
        end
    end
    for _, kind in ipairs(ITEM_KINDS) do shown[#shown + 1] = model.kinds[kind] end
    if #shown > 0 then
        local kinds = table.concat(shown, " \194\183 ")
        model.slot = model.slot and model.slot ~= "" and (model.slot .. " \194\183 " .. kinds) or kinds
    end

    local label = "Sell Price"
    if model.hasSellPrice and not model.sellPrice and itemInfo
        and C_Item and C_Item.GetItemInfo then
        -- The item's own price is per unit; the data line's covers the stack.
        local ok, price = pcall(function() return select(11, C_Item.GetItemInfo(itemInfo)) end)
        if ok and not isSecret(price) and type(price) == "number" then
            model.sellPrice, label = price, "Sell Price (each)"
        end
    end
    if model.sellPrice and model.sellPrice > 0 then
        add(model.footerRight, label, formatMoney(model.sellPrice))
    end
    model.quest = model.quest or classID == QUEST_CLASS
    local deltas = getDeltas(tooltip, itemInfo)
    if deltas then attachDeltas(model, deltas) end
    return model
end

local function makeTexture(parent, layer, path)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetTexture(path or WHITE)
    return tex
end

local function getPanel(tooltip)
    local panel = panels[tooltip]
    if panel then return panel end
    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetFrameStrata("TOOLTIP")
    panel.width = MAX_WIDTH
    panel:SetWidth(MAX_WIDTH)
    panel.measure = panel:CreateFontString(nil, "OVERLAY")
    panel.measure:SetPoint("TOPLEFT", panel, "TOPLEFT")
    panel.measure:SetAlpha(0)
    panel:SetClampedToScreen(true)
    panel:Hide()
    panel.pool, panel.used = {}, 0
    panel.texturePool, panel.texturesUsed = {}, 0
    if panel.SetIgnoreParentAlpha then panel:SetIgnoreParentAlpha(true) end
    -- Soft rarity halo behind the body; the backdrop covers all but its rim.
    panel.halo = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    panel.halo:SetPoint("TOPLEFT", panel, "TOPLEFT", -HALO_SPREAD, HALO_SPREAD)
    panel.halo:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", HALO_SPREAD, -HALO_SPREAD)
    panel.halo:SetTexture(ART .. "glow")
    if panel.halo.SetTextureSliceMargins then
        panel.halo:SetTextureSliceMargins(HALO_MARGIN, HALO_MARGIN, HALO_MARGIN, HALO_MARGIN)
    end
    panel.halo:SetBlendMode("ADD")
    panel.background = panel:CreateTexture(nil, "BACKGROUND", nil, -7)
    panel.background:SetAllPoints()
    -- Both looks are built once; applyBackdrop shows one per render.
    if panel.background.SetTextureSliceMargins then
        -- The backdrop is nearly black, so multiplying alone barely tints it.
        -- An additive copy of the same texture carries the rarity glow and
        -- keeps to its grain and brushed edge.
        panel.glow = panel:CreateTexture(nil, "BACKGROUND", nil, -6)
        panel.glow:SetAllPoints()
        panel.glow:SetTexture(DIALOGUE_BACKDROP)
        panel.glow:SetTextureSliceMargins(32, 32, 32, 32)
        panel.glow:SetTextureSliceMode(1)
        panel.glow:SetBlendMode("ADD")
    end
    -- Inner shade along each edge so the plain panel reads as one raised object.
    local function shade(orientation, from, to, a1, a2)
        local tex = panel:CreateTexture(nil, "BORDER", nil, 2)
        tex:SetColorTexture(1, 1, 1, 1)
        tex:SetPoint(from, panel, from)
        tex:SetPoint(to, panel, to)
        tex:SetGradient(orientation, CreateColor(0, 0, 0, a1), CreateColor(0, 0, 0, a2))
        return tex
    end
    panel.shades = {
        shade("VERTICAL", "TOPLEFT", "TOPRIGHT", 0, .30),
        shade("VERTICAL", "BOTTOMLEFT", "BOTTOMRIGHT", .45, 0),
        shade("HORIZONTAL", "TOPLEFT", "BOTTOMLEFT", .35, 0),
        shade("HORIZONTAL", "TOPRIGHT", "BOTTOMRIGHT", 0, .35),
    }
    panel.shades[1]:SetHeight(10)
    panel.shades[2]:SetHeight(10)
    panel.shades[3]:SetWidth(8)
    panel.shades[4]:SetWidth(8)
    panel.header = makeTexture(panel, "BORDER")
    panel.footer = makeTexture(panel, "BORDER")
    panel.icon = makeTexture(panel, "OVERLAY")
    panel.icon:SetSize(ICON_SIZE, ICON_SIZE)
    panel.iconBorder = makeTexture(panel, "OVERLAY")
    panel.iconBorder:SetSize(45, 45)
    panel.iconBorder:SetPoint("CENTER", panel.icon, "CENTER")
    panel.iconBorder:SetVertexColor(.55, .45, .37, .9)
    panel.iconBorder:SetDrawLayer("OVERLAY", 1)
    panel.icon:SetDrawLayer("OVERLAY", 2)
    panel.badge = makeTexture(panel, "OVERLAY")
    panel.badge:SetDrawLayer("OVERLAY", 1)
    panel.badge:SetPoint("TOP", panel.icon, "BOTTOM", 0, -BADGE_GAP)
    panel.badgeFill = makeTexture(panel, "OVERLAY")
    panel.badgeFill:SetDrawLayer("OVERLAY", 2)
    panel.badgeFill:SetPoint("TOPLEFT", panel.badge, "TOPLEFT", 1, -1)
    panel.badgeFill:SetPoint("BOTTOMRIGHT", panel.badge, "BOTTOMRIGHT", -1, 1)
    panel.badgeText = panel:CreateFontString(nil, "OVERLAY")
    panel.badgeText:SetDrawLayer("OVERLAY", 3)
    panel.badgeText:SetPoint("CENTER", panel.badge, "CENTER", 0, 0)
    panel.edges = {}
    for i = 1, 4 do panel.edges[i] = makeTexture(panel, "OVERLAY") end
    panel.edges[1]:SetPoint("TOPLEFT", panel, "TOPLEFT")
    panel.edges[1]:SetPoint("TOPRIGHT", panel, "TOPRIGHT")
    panel.edges[1]:SetHeight(2)
    panel.edges[2]:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT")
    panel.edges[2]:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT")
    panel.edges[2]:SetHeight(1)
    panel.edges[3]:SetPoint("TOPLEFT", panel, "TOPLEFT")
    panel.edges[3]:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT")
    panel.edges[3]:SetWidth(1)
    panel.edges[4]:SetPoint("TOPRIGHT", panel, "TOPRIGHT")
    panel.edges[4]:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT")
    panel.edges[4]:SetWidth(1)
    panels[tooltip] = panel
    return panel
end

-- DialogueUI's textured backdrop, or the plain gradient with drawn edges.
-- Chosen per render so the option applies without a reload.
local function applyBackdrop(panel)
    local textured = panel.glow ~= nil and ns.option("dialogueBackdrop") and hasDialogueBackdrop()
    if panel.textured == textured then return end
    panel.textured = textured
    if textured then
        panel.background:SetTexture(DIALOGUE_BACKDROP)
        panel.background:SetTextureSliceMargins(32, 32, 32, 32)
        panel.background:SetTextureSliceMode(1)
    else
        if panel.background.SetTextureSliceMargins then
            panel.background:SetTextureSliceMargins(0, 0, 0, 0)
            panel.background:SetTextureSliceMode(0)
        end
        panel.background:SetColorTexture(1, 1, 1, 1)
        if panel.glow then panel.glow:Hide() end
    end
    for _, region in ipairs(panel.shades) do region:SetShown(not textured) end
    for _, region in ipairs(panel.edges) do region:SetShown(not textured) end
    -- The textured backdrop has a brushed edge; tint bands stay inside it.
    panel.inset = textured and 6 or 1
    local inset = panel.inset
    panel.header:ClearAllPoints()
    panel.header:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, -inset)
    panel.header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -inset, -inset)
    panel.footer:ClearAllPoints()
    panel.footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", inset, inset)
    panel.footer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -inset, inset)
    panel.footer:SetVertexColor(.10, .075, .08, textured and .6 or .95)
end

local function clearPool(panel)
    for _, font in ipairs(panel.pool) do font:Hide() end
    for _, tex in ipairs(panel.texturePool) do tex:Hide() end
    panel.used, panel.texturesUsed = 0, 0
end

-- WoW fonts have no bold flag, and the face varies per install, so bold is
-- a shadow in the text's own color one pixel to the right.
local function textAt(panel, content, x, y, width, size, color, fontPath, align)
    panel.used = panel.used + 1
    local font = panel.pool[panel.used]
    if not font then
        font = panel:CreateFontString(nil, "OVERLAY")
        panel.pool[panel.used] = font
    end
    font:ClearAllPoints()
    font:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y)
    font:SetWidth(width)
    font:SetFont(fontPath or bodyFont(), size)
    font:SetJustifyH(align or "LEFT")
    font:SetJustifyV("TOP")
    font:SetTextColor(color[1], color[2], color[3])
    font:SetShadowColor(0, 0, 0, 0)
    font:SetShadowOffset(0, 0)
    font:SetText(content)
    font:Show()
    return math.max(size + 2, font:GetStringHeight() or 0)
end

local function measure(panel, text, size, fontPath)
    local font = panel.measure
    font:SetFont(fontPath or bodyFont(), size)
    font:SetText(text)
    local width = font.GetUnboundedStringWidth and font:GetUnboundedStringWidth()
        or font:GetStringWidth()
    -- Inline textures can be left out of the measured width.
    local _, textures = text:gsub("|T", "")
    return (width or 0) + textures * (size + 2)
end

local function rowWidth(panel, row, size)
    local width = measure(panel, row.left, size)
    if row.right and row.right ~= "" then
        -- The 2 matches the slack drawRow gives the right column.
        return width + COLUMN_GAP + measure(panel, row.right, size) + 2
    end
    return width
end

-- The header's text clears the icon on whichever side it sits: returns the
-- left and right indents for an icon that takes `indent` pixels.
local function headerInsets(indent)
    if ns.option("iconRight") then return 0, indent end
    return indent, 0
end

-- indent and rightIndent keep a row clear of the icon on either side.
local function drawRow(panel, row, y, size, color, indent, gap, rightIndent)
    local left = row.left
    local right = row.right
    local leftColor = row.color or color
    indent, gap, rightIndent = indent or 0, gap or 3, rightIndent or 0
    local w = panel.width - 2 * PAD - indent - rightIndent
    if right and right ~= "" then
        -- Half the row at most, unless a short left side leaves more room.
        local rightWidth = math.min(measure(panel, right, size) + 2,
            math.max(w * .5, w - measure(panel, left, size) - COLUMN_GAP))
        local leftHeight = textAt(panel, left, PAD + indent, y,
            w - rightWidth - COLUMN_GAP, size, leftColor)
        local rightHeight = textAt(panel, right, panel.width - PAD - rightIndent - rightWidth, y,
            rightWidth, size, row.rightColor or leftColor, nil, "RIGHT")
        return y + math.max(leftHeight, rightHeight) + gap
    end
    return y + textAt(panel, left, PAD + indent, y, w, size, leftColor) + gap
end

-- Pool slots are reused for both plain lines and the marker, so every
-- acquire sets the texture again.
local function acquireTexture(panel, path, sublevel)
    panel.texturesUsed = panel.texturesUsed + 1
    local tex = panel.texturePool[panel.texturesUsed]
    if not tex then
        tex = panel:CreateTexture(nil, "OVERLAY")
        panel.texturePool[panel.texturesUsed] = tex
    end
    tex:SetDrawLayer("OVERLAY", sublevel or 0)
    tex:SetTexture(path or WHITE)
    tex:ClearAllPoints()
    tex:Show()
    return tex
end

local function rule(panel, y, color)
    local line = acquireTexture(panel)
    line:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
    line:SetSize(panel.width - 2 * PAD, 1)
    line:SetVertexColor(color[1], color[2], color[3], .45)
    return y + 9
end

local function divider(panel, y, color)
    local left = acquireTexture(panel)
    left:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y - 5)
    left:SetSize((panel.width - 2 * PAD - 18) / 2, 1)
    left:SetVertexColor(color[1] * .52, color[2] * .52, color[3] * .52, .8)
    local right = acquireTexture(panel)
    right:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -y - 5)
    right:SetSize((panel.width - 2 * PAD - 18) / 2, 1)
    right:SetVertexColor(color[1] * .52, color[2] * .52, color[3] * .52, .8)
    local center = acquireTexture(panel, ART .. "stat-marker")
    center:SetPoint("TOP", panel, "TOP", 0, -y)
    center:SetSize(10, 10)
    center:SetVertexColor(.9, .76, .48, .9)
    return y + 18
end

local function drawGroup(panel, list, y, size, color, indent, gap, rightIndent)
    for _, row in ipairs(list) do
        y = drawRow(panel, row, y, size, color, indent, gap, rightIndent)
    end
    return y
end

-- Where stat text starts after an inline marker and its two spaces.
local function markerIndent(panel)
    if not ns.option("statMarkers") then return 0 end
    return 9 + measure(panel, "a  a", 13) - measure(panel, "aa", 13)
end

-- The marker is drawn on its own so wrapped lines hang under the text, not
-- under the diamond. Same size and offset as the inline markers above.
local function drawEquipEffects(panel, list, y)
    local hang = markerIndent(panel)
    local width = panel.width - 2 * PAD - hang
    for _, row in ipairs(list) do
        if hang > 0 then textAt(panel, STAT_MARKER, PAD, y, hang, 13, EQUIP_EFFECT_COLOR) end
        y = y + textAt(panel, row.left, PAD + hang, y, width, 13, EQUIP_EFFECT_COLOR) + 3
    end
    return y
end

local function footerText(row)
    if row.right ~= "" then return row.left .. " " .. row.right end
    return row.left
end

local function weaponText(model)
    local text = model.weaponDamage
    if model.weaponSpeed then text = text .. "  \194\183  " .. model.weaponSpeed end
    return text
end

-- Size the panel to its widest single-line content; prose wraps instead.
local function fitWidth(panel, model, title)
    local need = 0
    local function consider(width) if width > need then need = width end end
    local function group(list, size, extra, prose)
        for _, row in ipairs(list) do
            local width = rowWidth(panel, row, size)
            if prose and (not row.right or row.right == "") then
                width = math.min(width, PROSE_WIDTH)
            end
            consider(width + extra)
        end
    end
    local indent = model.icon and HEADER_INDENT or 0
    consider(measure(panel, title, 19, titleFont()) + indent)
    if model.slot then consider(measure(panel, model.slot, 13) + indent) end
    group(model.header, 12, indent)
    if model.weaponDps then
        local width = measure(panel, valueLabel(model.weaponDps, "Damage per Second"), 18)
        if model.weaponDpsDelta then
            width = width + COLUMN_GAP + measure(panel, formatDelta(model.weaponDpsDelta), 18)
        end
        consider(width)
    end
    if model.weaponDamage then consider(measure(panel, weaponText(model), 12) + 7) end
    group(model.armor, 16, 0)
    group(model.primary, 13, 0)
    group(model.secondary, 13, 0)
    for _, row in ipairs(model.equipEffects) do
        consider(math.min(measure(panel, row.left, 13), PROSE_WIDTH) + markerIndent(panel))
    end
    group(model.enchants, 13, 0)
    group(model.lost, 12, 0)
    group(model.effects, 13, 0, true)
    group(model.flavor, 12, 0, true)
    if model.setName then
        consider(measure(panel, model.setName:upper(), 15, titleFont()) + 45)
        group(model.setItems, 12, 20)
        group(model.setBonuses, 12, 3, true)
    end
    group(model.extras, 11, 0, true)
    for index = 1, math.max(#model.footerLeft, #model.footerRight) do
        local left, right = model.footerLeft[index], model.footerRight[index]
        local leftWidth = 0
        if left and left.durability then
            leftWidth = DURABILITY_BAR + 7
                + measure(panel, left.durability[1] .. " / " .. left.durability[2], 11)
        elseif left then
            leftWidth = measure(panel, left.left, 11)
        end
        consider(leftWidth + COLUMN_GAP
            + (right and measure(panel, footerText(right), 11) or 0))
    end
    local width = math.ceil(need + 2 * PAD)
    return math.max(MIN_WIDTH, math.min(MAX_WIDTH, width))
end

local function durabilityColor(current, maximum)
    local ratio = maximum > 0 and current / maximum or 0
    if current == 0 then return { 1, .34, .28 } end
    if ratio < .25 then return { 1, .52, .25 } end
    if ratio < .5 then return { .95, .76, .30 } end
    return { .45, .80, .40 }
end

local function drawDurability(panel, durability, y)
    local current, maximum = durability[1], durability[2]
    local color = durabilityColor(current, maximum)
    local track = acquireTexture(panel, nil, 0)
    track:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(y + 5))
    track:SetSize(DURABILITY_BAR, 4)
    track:SetVertexColor(.16, .14, .13, 1)
    local fill = acquireTexture(panel, nil, 1)
    local width = maximum > 0 and DURABILITY_BAR * current / maximum or 0
    fill:SetPoint("TOPLEFT", track, "TOPLEFT")
    fill:SetSize(math.max(width, 1), 4)
    fill:SetVertexColor(color[1], color[2], color[3], 1)
    if width < 1 then fill:Hide() end
    local healthy = maximum > 0 and current / maximum >= .5
    return textAt(panel, current .. " / " .. maximum, PAD + DURABILITY_BAR + 7, y, 90, 11,
        healthy and { .82, .78, .71 } or color)
end

-- The chat-link tooltip's close button is a child of the hidden tooltip, so
-- the panel draws its own and clicks the game's.
local function nativeCloseButton(tooltip)
    local button = tooltip.CloseButton
    if not button and tooltip == ItemRefTooltip then button = _G.ItemRefCloseButton end
    return button
end

local function getCloseButton(panel, tooltip)
    if panel.close then return panel.close end
    local close = CreateFrame("Button", nil, panel)
    close:SetSize(16, 16)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    local lines = {}
    for index, angle in ipairs({ 45, -45 }) do
        local line = close:CreateTexture(nil, "ARTWORK")
        line:SetTexture(WHITE)
        line:SetSize(11, 1.5)
        line:SetPoint("CENTER")
        if line.SetRotation then line:SetRotation(math.rad(angle)) end
        lines[index] = line
    end
    local function tint(r, g, b, a)
        for _, line in ipairs(lines) do line:SetVertexColor(r, g, b, a) end
    end
    tint(.78, .72, .63, .8)
    close:SetScript("OnEnter", function() tint(1, .92, .78, 1) end)
    close:SetScript("OnLeave", function() tint(.78, .72, .63, .8) end)
    close:SetScript("OnClick", function()
        local native = nativeCloseButton(tooltip)
        if native then native:Click() else tooltip:Hide() end
    end)
    panel.close = close
    return close
end

-- Blizzard's "Equipped" header is a child of the hidden comparison tooltip.
local function isComparison(tooltip)
    local name = tooltip:GetName()
    return name ~= nil and name:find("ShoppingTooltip%d$") ~= nil
end

-- A shield or off-hand is also compared against the one-hander from the bags
-- it would be worn with; Blizzard heads that one "Equipped With".
local function isEquipped(model)
    if not (C_Item and C_Item.IsEquippedItem and model.link) then return true end
    local ok, equipped = pcall(C_Item.IsEquippedItem, model.link)
    if not ok or isSecret(equipped) then return true end
    return equipped == true
end

local function getEquippedTag(panel)
    if panel.equipped then return panel.equipped end
    local tag = CreateFrame("Frame", nil, panel)
    tag:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 2)
    tag:SetHeight(BADGE_HEIGHT)
    tag.border = tag:CreateTexture(nil, "BACKGROUND")
    tag.border:SetAllPoints()
    tag.border:SetTexture(WHITE)
    tag.border:SetVertexColor(.55, .45, .30, .9)
    tag.fill = tag:CreateTexture(nil, "BORDER")
    tag.fill:SetPoint("TOPLEFT", 1, -1)
    tag.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    tag.fill:SetTexture(WHITE)
    tag.fill:SetVertexColor(.07, .055, .05, 1)
    tag.text = tag:CreateFontString(nil, "OVERLAY")
    tag.text:SetFont(bodyFont(), 10)
    tag.text:SetTextColor(.93, .80, .52)
    tag.text:SetPoint("CENTER")
    panel.equipped = tag
    return tag
end

-- Backdrop, tint, header band, icon, badge, close button, and tag shared by
-- every kind of panel. Returns the header height the icon and badge need.
local function drawChrome(panel, tooltip, style)
    applyBackdrop(panel)
    local color = style.color
    panel:SetFrameLevel(tooltip:GetFrameLevel() + 5)
    -- Untinted panels (common items, spells without a cost) keep a neutral body.
    local tinted = style.tint and ns.option("qualityTint")
    local tint = tinted and style.tint or { .5, .5, .5 }
    local strength = tinted and (style.strength or 1) or 0
    if panel.textured then
        panel.background:SetVertexColor(1 - .45 * strength + .45 * strength * tint[1],
            1 - .45 * strength + .45 * strength * tint[2],
            1 - .45 * strength + .45 * strength * tint[3], 1)
        panel.glow:SetVertexColor(tint[1], tint[2], tint[3], .35 * strength)
        panel.glow:SetShown(strength > 0)
    else
        panel.background:SetGradient("VERTICAL",
            CreateColor(.016 + tint[1] * .02 * strength, .012 + tint[2] * .02 * strength,
                .016 + tint[3] * .02 * strength, 1),
            CreateColor(.052 + tint[1] * .06 * strength, .040 + tint[2] * .06 * strength,
                .050 + tint[3] * .06 * strength, 1))
    end
    if strength > 0 then
        panel.halo:SetVertexColor(tint[1], tint[2], tint[3], .55 * strength)
    else
        panel.halo:SetVertexColor(.6, .6, .6, .18)
    end
    local headerAlpha = panel.textured and .72 or .96
    panel.header:SetGradient("VERTICAL",
        CreateColor(color[1] * .12, color[2] * .12, color[3] * .12, headerAlpha),
        CreateColor(color[1] * .38, color[2] * .38, color[3] * .38, headerAlpha))
    for index, edge in ipairs(panel.edges) do
        local edgeStrength = index == 1 and .8 or .36
        edge:SetVertexColor(color[1] * edgeStrength, color[2] * edgeStrength,
            color[3] * edgeStrength, .95)
    end
    panel.iconBorder:SetVertexColor(color[1], color[2], color[3], .85)
    local native = nativeCloseButton(tooltip)
    if native and native:IsShown() then
        getCloseButton(panel, tooltip):Show()
    elseif panel.close then
        panel.close:Hide()
    end
    if style.tag then
        local tag = getEquippedTag(panel)
        tag.text:SetText(style.tag)
        tag:SetWidth(tag.text:GetStringWidth() + 16)
        tag:Show()
    elseif panel.equipped then
        panel.equipped:Hide()
    end
    local iconSize = style.iconSize or ICON_SIZE
    panel.icon:SetSize(iconSize, iconSize)
    panel.icon:ClearAllPoints()
    if ns.option("iconRight") then
        panel.icon:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -ICON_TOP)
    else
        panel.icon:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -ICON_TOP)
    end
    panel.iconBorder:SetSize(iconSize + 2, iconSize + 2)
    -- Icons carry their own dark frame in the outer texels; cropping it lets
    -- the art meet the panel's colored border directly.
    panel.icon:SetTexCoord(.08, .92, .08, .92)
    if style.icon then
        panel.icon:SetTexture(style.icon)
        panel.icon:Show()
        panel.iconBorder:Show()
    else
        panel.icon:Hide()
        panel.iconBorder:Hide()
    end
    local headerMin = style.icon and ICON_TOP + iconSize + 12 or 0
    if style.badge then
        local badge = panel.badge
        panel.badgeText:SetFont(bodyFont(), 10)
        panel.badgeText:SetTextColor(color[1] * .45 + .55, color[2] * .45 + .55,
            color[3] * .45 + .55)
        panel.badgeText:SetText(style.badge)
        badge:SetSize(math.max(iconSize + 2, panel.badgeText:GetStringWidth() + 12),
            BADGE_HEIGHT)
        badge:SetVertexColor(color[1] * .8, color[2] * .8, color[3] * .8, .9)
        panel.badgeFill:SetVertexColor(color[1] * .14, color[2] * .14, color[3] * .14, 1)
        badge:Show()
        panel.badgeFill:Show()
        panel.badgeText:Show()
        headerMin = ICON_TOP + iconSize + BADGE_GAP + BADGE_HEIGHT + 10
    else
        panel.badge:Hide()
        panel.badgeFill:Hide()
        panel.badgeText:Hide()
    end
    return headerMin
end

-- The hidden tooltip is often wider than its panel, as long as its longest
-- unwrapped line. Pin the panel to the side the tooltip itself is anchored
-- by, so the spare width faces away from whatever it is attached to.
local function alignPanel(panel, tooltip)
    local point = tooltip:GetNumPoints() > 0 and tooltip:GetPoint(1)
    local side = "LEFT"
    if not isSecret(point) and type(point) == "string" and point:find("RIGHT") then
        side = "RIGHT"
    end
    if panel.side == side and panel:GetNumPoints() > 0 then return end
    panel.side = side
    panel:ClearAllPoints()
    panel:SetPoint("TOP" .. side, tooltip, "TOP" .. side)
end

local function finishPanel(panel, tooltip, y)
    panel:SetHeight(y + 17)
    alignPanel(panel, tooltip)
    panel:Show()
end

-- Re-points a tooltip's anchors through choose(frame), keeping the offsets.
local function retarget(tooltip, choose)
    local points, changed = {}, false
    for index = 1, tooltip:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = tooltip:GetPoint(index)
        if isSecret(point) or isSecret(relativeTo) or isSecret(relativePoint)
            or isSecret(x) or isSecret(y) then
            return
        end
        local target = choose(relativeTo)
        if target ~= relativeTo then changed = true end
        points[index] = { point, target, relativePoint, x, y }
    end
    if not changed then return end
    tooltip:ClearAllPoints()
    for _, anchor in ipairs(points) do
        tooltip:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
    end
end

-- Blizzard attaches comparisons to the hidden tooltips' edges, past the end
-- of a narrower panel; attach them to the panels instead.
local function anchorToPanels(comparison)
    retarget(comparison, function(frame)
        local target = frame and panels[frame]
        if target and target:IsShown() then return target end
        return frame
    end)
end

local function render(panel, tooltip, model)
    panel:Show()
    clearPool(panel)
    local title = model.name:find("|", 1, true) and model.name or model.name:upper()
    panel.width = fitWidth(panel, model, title)
    panel:SetWidth(panel.width)
    local quality = QUALITY[model.quality] or QUALITY[1]
    local tag
    if isComparison(tooltip) then
        tag = isEquipped(model) and "EQUIPPED" or "EQUIPPED WITH"
    end
    -- Quest items are mostly common, so they take quest gold instead of rarity;
    -- the title keeps the rarity color.
    local accent = model.quest and QUEST_GOLD or quality
    local headerMin = drawChrome(panel, tooltip, {
        color = accent,
        tint = (model.quest or model.quality >= 2) and accent or nil,
        icon = model.icon,
        badge = ns.option("itemLevelBadge") and model.level
            and (model.equippable or model.levelLine) and ("iLvl " .. model.level),
        tag = tag,
    })

    local y = TITLE_TOP
    local inner = panel.width - 2 * PAD
    local indent = model.icon and HEADER_INDENT or 0
    local leftIndent, rightIndent = headerInsets(indent)
    y = y + textAt(panel, title, PAD + leftIndent, y, inner - indent,
        19, quality, titleFont()) + 4
    if model.slot and model.slot ~= "" then
        -- Halfway to white: the title already carries the full rarity color.
        y = y + textAt(panel, model.slot, PAD + leftIndent, y, inner - indent, 13,
            { quality[1] * .5 + .5, quality[2] * .5 + .5, quality[3] * .5 + .5 }) + 4
    end
    y = drawGroup(panel, model.header, y, 12, { .78, .72, .63 }, leftIndent, nil, rightIndent)
    y = math.max(y + 6, headerMin)
    panel.header:SetHeight(y - panel.inset)

    -- Dividers go only between sections that have content.
    local sectioned = false
    if model.weaponDps or model.weaponDamage or #model.armor > 0 or #model.primary > 0
        or #model.secondary > 0 or #model.equipEffects > 0 or #model.enchants > 0
        or #model.lost > 0
        or #model.effects > 0 or #model.flavor > 0 then
        y = divider(panel, y, GOLD_RULE)
        if model.weaponDps then
            local delta = model.weaponDpsDelta
            y = drawRow(panel, {
                left = valueLabel(model.weaponDps, "Damage per Second"),
                right = delta and formatDelta(delta) or "",
                rightColor = delta and (delta > 0 and DELTA_UP or DELTA_DOWN),
            }, y, 18, { .93, .87, .75 }) + 2
        end
        if model.weaponDamage then
            y = y + textAt(panel, weaponText(model), PAD + 7, y, inner - 7,
                12, { .71, .72, .73 }) + 7
        end
        for _, row in ipairs(model.armor) do
            y = drawRow(panel, {
                left = row.value and valueLabel(row.value, "Armor") or row.left,
                right = row.right, rightColor = row.rightColor,
            }, y, 16, { .93, .87, .75 })
        end
        if #model.armor > 0 then y = y + 5 end
        y = drawGroup(panel, model.primary, y, 13, { .90, .85, .74 })
        if (#model.secondary > 0 or #model.equipEffects > 0) and #model.primary > 0 then
            y = divider(panel, y + 3, GOLD_RULE)
        end
        y = drawGroup(panel, model.secondary, y, 13, { .90, .85, .74 })
        y = drawEquipEffects(panel, model.equipEffects, y)
        y = drawGroup(panel, model.enchants, y, 13, { .90, .85, .74 })
        if #model.lost > 0 then
            y = drawGroup(panel, model.lost, y + 3, 12, { .50, .48, .45 })
        end
        if #model.effects > 0 then y = y + 5 end
        y = drawGroup(panel, model.effects, y, 13, { .48, .88, .48 })
        if #model.flavor > 0 then
            y = drawGroup(panel, model.flavor, y + 5, 12, FLAVOR_GOLD)
        end
        sectioned = true
    end

    if model.setName then
        y = divider(panel, sectioned and y + 11 or y, GOLD_RULE)
        sectioned = true
        local setTitle = model.setName:upper()
        textAt(panel, setTitle, PAD, y, inner - 45, 15,
            { 1, .76, .18 }, titleFont())
        textAt(panel, model.setCount or "", panel.width - PAD - 42, y, 42, 12,
            { 1, .76, .18 }, nil, "RIGHT")
        y = y + 24
        for _, row in ipairs(model.setItems) do
            local bullet, color = "|cff756C60-  |r", { .61, .58, .54 }
            if row.active == true then
                bullet, color = "|cffD9B36A-  |r", { .94, .89, .77 }
            elseif row.active == false then
                bullet, color = "|cff4A4540-  |r", { .44, .42, .40 }
            end
            y = drawRow(panel, { left = bullet .. row.left, right = row.right },
                y, 12, color, 5)
        end
        if #model.setBonuses > 0 then y = y + 7 end
        for _, row in ipairs(model.setBonuses) do
            local color = { .68, .65, .57 }
            if row.active == true then
                color = { .48, .88, .48 }
            elseif row.active == false then
                color = { .44, .42, .40 }
            end
            y = drawRow(panel, row, y, 12, color, 3)
        end
    end

    if #model.extras > 0 then
        if sectioned then
            y = rule(panel, y + 10, { .50, .50, .54 })
        else
            y = y + 12
        end
        y = drawGroup(panel, model.extras, y, 11, EXTRA_COLOR, 0, 2)
    end

    if #model.footerLeft > 0 or #model.footerRight > 0 then
        y = y + 9
        local footerStart = y
        local rows = math.max(#model.footerLeft, #model.footerRight)
        for index = 1, rows do
            local left = model.footerLeft[index]
            local right = model.footerRight[index]
            local h1, h2 = 0, 0
            local rightWidth = 0
            if right then
                local content = footerText(right)
                local color = { .88, .78, .60 }
                if right.requirement then
                    color = right.met and { 1, 1, 1 } or { 1, .34, .28 }
                end
                rightWidth = math.min(measure(panel, content, 11) + 2, inner * .6)
                h2 = textAt(panel, content, panel.width - PAD - rightWidth, y,
                    rightWidth, 11, color, nil, "RIGHT")
            end
            if left and left.durability then
                h1 = drawDurability(panel, left.durability, y)
            elseif left then
                h1 = textAt(panel, left.left, PAD, y, inner - rightWidth - COLUMN_GAP,
                    11, left.color or { .82, .78, .71 })
            end
            y = y + math.max(h1, h2, 13) + 4
        end
        panel.footer:SetHeight(y - footerStart + 23)
    else
        panel.footer:SetHeight(0)
    end
    finishPanel(panel, tooltip, y)
end

-- Blizzard anchors comparison tooltips, slides away from screen edges, and
-- clamps using the native frame's bounds, so the hidden frame must cover the
-- panel or the comparisons land on top of it.
local function fitNative(tooltip, panel)
    if not tooltip.SetPadding then return end
    local base = panel.nativeSize
    if not base then
        local right, bottom, left, top
        if tooltip.GetPadding then right, bottom, left, top = tooltip:GetPadding() end
        base = { right = right or 0, bottom = bottom or 0, left = left or 0, top = top or 0 }
        panel.nativeSize = base
    end
    -- A hidden tooltip is fitted by the Show hook once Blizzard shows it.
    if not tooltip:IsShown() then return end
    -- Every refresh resets the tooltip's size and the client does not report
    -- padding back, so measure from the natural size each time. Nothing is
    -- drawn between these calls.
    tooltip:SetPadding(base.right, base.bottom, base.left, base.top)
    tooltip:Show()
    local right = base.right + math.max(0, panel:GetWidth() - tooltip:GetWidth())
    local bottom = base.bottom + math.max(0, panel:GetHeight() - tooltip:GetHeight())
    if right ~= base.right or bottom ~= base.bottom then
        tooltip:SetPadding(right, bottom, base.left, base.top)
        tooltip:Show()
    end
end

local function refitNative(tooltip, panel)
    if panel.fitting then return end
    panel.fitting = true
    pcall(fitNative, tooltip, panel)
    panel.fitting = false
end

local function releaseNative(tooltip, panel)
    local base = panel.nativeSize
    panel.nativeSize = nil
    -- After a hide or a switch to other content the game has already reset
    -- the size, and the tooltip's new owner may have set its own padding.
    if base and panel.kind and tooltip:IsShown() and tooltip:IsTooltipType(panel.kind) then
        tooltip:SetPadding(base.right, base.bottom, base.left, base.top)
        tooltip:Show()
    end
end

local function restoreNative(tooltip)
    local panel = panels[tooltip]
    if not panel then return end
    panel.restorePending = false
    pcall(releaseNative, tooltip, panel)
    panel:Hide()
    if panel.nativeAlpha then
        tooltip:SetAlpha(panel.nativeAlpha)
        panel.nativeAlpha = nil
    end
    -- With the game tooltip visible again, its comparisons go back beside it.
    for comparison in pairs(panels) do
        if isComparison(comparison) then
            pcall(retarget, comparison, function(frame)
                return frame == panel and tooltip or frame
            end)
        end
    end
end

-- Each tooltip data type the panel draws: read(tooltip, data) -> model,
-- render(panel, tooltip, model), and key(tooltip, data) naming what is shown.
local KINDS = {}
KINDS[ITEM] = { read = readModel, render = render, key = getItemInfo }

-- The game's own tooltip shows while the chosen key is held, and for spells
-- when their panel is turned off.
local function showsOriginal(panel)
    return ns.originalKeyDown() or (panel.kind ~= ITEM and not ns.option("spellPanels"))
end

local function update(tooltip, data)
    local panel = getPanel(tooltip)
    local kind = KINDS[panel.kind]
    if showsOriginal(panel) or not kind then restoreNative(tooltip); return end
    local ok, model = pcall(kind.read, tooltip, data)
    if not ok or not model then restoreNative(tooltip); return end
    if not panel.nativeAlpha then panel.nativeAlpha = tooltip:GetAlpha() end
    local rendered = pcall(kind.render, panel, tooltip, model)
    if not rendered then restoreNative(tooltip); return end
    refitNative(tooltip, panel)
    panel.data = data
    panel.key = kind.key(tooltip, data)
    panel.lineCount = tooltip:NumLines()
    tooltip:SetAlpha(0)
end

-- Some tooltip owners clear or briefly hide the tooltip while refreshing the
-- same item. Keep the previous panel for that frame, and only tear it down if
-- no new item post-call replaces it.
local function scheduleRestore(tooltip)
    local panel = panels[tooltip]
    if not panel then return end
    panel.restorePending = true
    panel.refreshToken = (panel.refreshToken or 0) + 1
    local token = panel.refreshToken
    C_Timer.After(0, function()
        if panel.refreshToken == token and panel.restorePending then
            restoreNative(tooltip)
        end
    end)
end

-- A comparison can open after its owner's panel was drawn, and chat-link
-- tooltips never refresh on their own, so the owner redraws for its arrows.
local function refreshOwner(owner)
    local panel = owner and panels[owner]
    if panel and panel.kind == ITEM and panel:IsShown() and panel.data and owner:IsShown()
        and owner:IsTooltipType(ITEM) then
        update(owner, panel.data)
    end
end

local function onTooltipData(dataType, tooltip, data)
    local panel = getPanel(tooltip)
    local previousKey, previousKind = panel.key, panel.kind
    local key = KINDS[dataType].key(tooltip, data)
    panel.kind = dataType
    panel.data = data
    panel.refreshToken = (panel.refreshToken or 0) + 1
    local token = panel.refreshToken
    panel.restorePending = false
    if not panel.hooked then
        tooltip:HookScript("OnHide", scheduleRestore)
        if isComparison(tooltip) then
            tooltip:HookScript("OnHide", function()
                local owner = panel.owner
                C_Timer.After(0, function() refreshOwner(owner) end)
            end)
        end
        tooltip:HookScript("OnTooltipCleared", scheduleRestore)
        -- Every refresh re-shows the tooltip at its natural size and full
        -- opacity. Waiting for the next OnUpdate lets one frame of it draw.
        local function onNativeShown(shown)
            if not (panel.nativeSize and panel:IsShown()) then return end
            refitNative(shown, panel)
            -- Comparisons are anchored after they are shown, so align here.
            pcall(alignPanel, panel, shown)
            if isComparison(shown) then pcall(anchorToPanels, shown) end
            if panel.nativeAlpha and shown:GetAlpha() ~= 0 then
                shown:SetAlpha(0)
            end
        end
        hooksecurefunc(tooltip, "Show", function(shown)
            if not panel.fitting then onNativeShown(shown) end
        end)
        -- The comparison manager re-shows its tooltips with SetShown, which
        -- resets them the same way but never goes through Show.
        hooksecurefunc(tooltip, "SetShown", function(shown, visible)
            if visible and not panel.fitting then onNativeShown(shown) end
        end)
        tooltip:HookScript("OnShow", onNativeShown)
        hooksecurefunc(tooltip, "SetAlpha", function(faded, alpha)
            if panel.settingAlpha or alpha == 0 then return end
            if not (panel.nativeAlpha and panel:IsShown()) then return end
            panel.nativeAlpha = alpha
            panel.settingAlpha = true
            faded:SetAlpha(0)
            panel.settingAlpha = false
        end)
        panel.hooked = true
        panel:SetScript("OnUpdate", function(self, elapsed)
            if self.nativeAlpha and tooltip:GetAlpha() ~= 0 then
                tooltip:SetAlpha(0)
            end
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed < .25 then return end
            self.elapsed = 0
            if tooltip:IsShown() and self.data and tooltip:NumLines() ~= self.lineCount then
                C_Timer.After(0, function()
                    if tooltip:IsShown() and self.kind and tooltip:IsTooltipType(self.kind)
                        and self.data and tooltip:NumLines() ~= self.lineCount then
                        update(tooltip, self.data)
                    end
                end)
            end
        end)
    end
    if showsOriginal(panel) then
        restoreNative(tooltip)
        return
    end
    -- The first render shows the new item promptly. On refresh, retain the
    -- complete old panel until other addons have appended their rows.
    if not panel:IsShown() or dataType ~= previousKind or (key and key ~= previousKey) then
        update(tooltip, data)
    else
        if not panel.nativeAlpha then panel.nativeAlpha = tooltip:GetAlpha() end
        tooltip:SetAlpha(0)
        refitNative(tooltip, panel)
    end
    C_Timer.After(0, function()
        if panel.refreshToken == token and tooltip:IsShown()
            and tooltip:IsTooltipType(dataType) then
            update(tooltip, data)
        end
    end)
    if dataType == ITEM and isComparison(tooltip) then
        local owner = tooltip:GetOwner()
        if isSecret(owner) then owner = nil end
        panel.owner = owner
        C_Timer.After(0, function() refreshOwner(owner) end)
    end
end

local function registerKind(dataType, kind)
    KINDS[dataType] = kind
    TooltipDataProcessor.AddTooltipPostCall(dataType, function(tooltip, data)
        onTooltipData(dataType, tooltip, data)
    end)
end

TooltipDataProcessor.AddTooltipPostCall(ITEM, function(tooltip, data)
    onTooltipData(ITEM, tooltip, data)
end)

local modifier = CreateFrame("Frame")
modifier:RegisterEvent("MODIFIER_STATE_CHANGED")
modifier:SetScript("OnEvent", function(_, _, key)
    if key == "LSHIFT" or key == "RSHIFT" then
        -- Shift toggles the comparison; redraw once it has been shown or hidden.
        C_Timer.After(0, function()
            for tooltip, panel in pairs(panels) do
                if tooltip.shoppingTooltips and panel.kind == ITEM and tooltip:IsShown()
                    and panel:IsShown() and panel.data and tooltip:IsTooltipType(ITEM) then
                    update(tooltip, panel.data)
                end
            end
        end)
        return
    end
    if not ns.isOriginalKey(key) then return end
    for tooltip, panel in pairs(panels) do
        if tooltip:IsShown() and panel.kind and tooltip:IsTooltipType(panel.kind) then
            if showsOriginal(panel) then
                restoreNative(tooltip)
            elseif panel.data then
                update(tooltip, panel.data)
            end
        end
    end
end)

-- Shared with PrettyTooltipSpell.lua, which loads after this file.
ns.ui = {
    isSecret = isSecret,
    safeText = safeText,
    add = add,
    colorOf = colorOf,
    appendedRows = appendedRows,
    requirementMet = requirementMet,
    clearPool = clearPool,
    textAt = textAt,
    measure = measure,
    rowWidth = rowWidth,
    drawRow = drawRow,
    drawGroup = drawGroup,
    headerInsets = headerInsets,
    acquireTexture = acquireTexture,
    rule = rule,
    divider = divider,
    drawChrome = drawChrome,
    finishPanel = finishPanel,
    registerKind = registerKind,
    PAD = PAD,
    TITLE_TOP = TITLE_TOP,
    MIN_WIDTH = MIN_WIDTH,
    MAX_WIDTH = MAX_WIDTH,
    PROSE_WIDTH = PROSE_WIDTH,
    titleFont = titleFont,
    EXTRA_COLOR = EXTRA_COLOR,
    GOLD_RULE = GOLD_RULE,
}
