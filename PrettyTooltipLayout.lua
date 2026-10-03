-- The panel that replaces tooltips. The game's tooltip stays
-- underneath, hidden, and shows while the modifier is held or a line cannot be read.
local _, ns = ...
if GetLocale() ~= "enUS" or not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then
    return
end

local isSecret = issecretvalue or function() return false end
local ITEM = Enum.TooltipDataType.Item
local LINE = Enum.TooltipDataLineType
local ART = "Interface\\AddOns\\PrettyTooltip\\art\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
-- Read at use time, so a UI addon's replacement font is followed.
local function fontOf(object)
    local path = object and object.GetFont and object:GetFont()
    return path or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end
local function bodyFont() return ns.fontPath(ns.option("bodyFont")) or fontOf(GameTooltipText) end
-- A file that fails to load leaves the string without a font, and SetText errors.
local function setFont(object, path, size, flags)
    if not object:SetFont(path, size, flags or "") then
        object:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, flags or "")
    end
end
-- A commercial font: used from EllesmereUI's folder, never copied here.
local ELLESMERE_BOLD = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway Bold.ttf"
local MIN_WIDTH, MAX_WIDTH = 260, 408
-- Wrapping prose is capped at this inner width; other rows fit on one line.
local PROSE_WIDTH = 270
local PAD = 19
local COLUMN_GAP = 12
local ICON_SIZE = 43
local HEADER_INDENT = ICON_SIZE + 10
local ICON_TOP = 21
local TITLE_TOP = ICON_TOP
local BADGE_GAP = 5
local BADGE_HEIGHT = 16
local EXTRA_COLOR = { .60, .60, .63 }
local GOLD_RULE = { .78, .59, .32 }
local FLAVOR_GOLD = { .86, .74, .45 }
local QUEST_GOLD = { 1, .82, 0 }
local QUEST_CLASS = Enum.ItemClass and Enum.ItemClass.Questitem or 12
local CONSUMABLE_CLASS = Enum.ItemClass and Enum.ItemClass.Consumable or 0
local DURABILITY_BAR = 54
local HEADER_ALPHA_TEXTURED, HEADER_ALPHA_PLAIN = .72, .96
local HALO_SPREAD = 16
-- Must match MARGIN in art/make_glow.py.
local HALO_MARGIN = 24
-- Must match --margin for band.tga in art/README.md's make_glow.py command.
local BAND_MARGIN = 16
-- Another author's art: used from DialogueUI's folder, never copied here.
local DIALOGUE_BACKDROP = "Interface\\AddOns\\DialogueUI\\Art\\Theme_Dark\\TooltipBackground-Temp.png"
local QUALITY = {
    [0] = { .62, .62, .62 },
    [1] = { .77, .77, .77 },
    [2] = { .30, .82, .30 },
    [3] = { .32, .59, .98 },
    [4] = { .72, .40, .94 },
    [5] = { 1.00, .57, .22 },
}
local PRIMARY_STATS = {
    Strength = true, Agility = true, Stamina = true, Intellect = true, Spirit = true,
    ["All Stats"] = true,
}
local ITEM_KINDS = { "Crafting Reagent", "Scarce" }
local ITEM_KIND_NAMES = {}
for _, kind in ipairs(ITEM_KINDS) do ITEM_KIND_NAMES[kind:lower()] = kind end
local panels = setmetatable({}, { __mode = "k" })

-- /ptip perf: how often the panel's work runs and how long it takes. While no
-- capture runs, a probed call costs one check.
local perf = { on = false, calls = {}, time = {} }

local function count(name)
    if perf.on then perf.calls[name] = (perf.calls[name] or 0) + 1 end
end

local function pack(...)
    return { n = select("#", ...), ... }
end

local function probe(name, fn)
    return function(...)
        if not perf.on then return fn(...) end
        local start = debugprofilestop()
        local results = pack(fn(...))
        perf.calls[name] = (perf.calls[name] or 0) + 1
        perf.time[name] = (perf.time[name] or 0) + debugprofilestop() - start
        return unpack(results, 1, results.n)
    end
end

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

-- The game colors whatever the character cannot use red. Nil when unreadable.
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

-- Can arrive color coded, or appended outside the tooltip data.
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

local ENCHANT_VALUE, ENCHANT_LABEL = "4CE64C", "A6EBA6"
-- Must match STAT_MARKER in PrettyTooltip.lua, minus its trailing spaces.
local STAT_MARKER = "|T" .. ART .. "stat-marker:9:9:0:-2|t"
local EQUIP_EFFECT_COLOR = { .48, .88, .48 }
local ENCHANT_MARKER = "|T" .. ART .. "stat-marker:9:9:0:-2:32:32:0:32:0:32:90:230:60|t  "

-- One row per bonus; named enchants ("Crusader") stay whole.
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

local function isComparison(tooltip)
    local name = tooltip:GetName()
    return name ~= nil and name:find("ShoppingTooltip%d$") ~= nil
end

-- The game's "If you replace this item" lines are kept as rows from another
-- source; their "+5 Stamina" lines must not be read as the item's own stats.
local STOCK_CHANGES = ITEM_DELTA_DESCRIPTION
    or "If you replace this item, the following stat changes will occur:"

local function isInstalled(addon)
    if not (C_AddOns and C_AddOns.GetAddOnInfo) then return false end
    local ok, name, _, _, _, reason = pcall(C_AddOns.GetAddOnInfo, addon)
    return ok and name ~= nil and reason ~= "MISSING"
end

local function hasDialogueBackdrop()
    return isInstalled("DialogueUI")
end

local hasEllesmere
local function titleFont()
    local chosen = ns.fontPath(ns.option("titleFont"))
    if chosen then return chosen end
    if hasEllesmere == nil then hasEllesmere = isInstalled("EllesmereUI") end
    return hasEllesmere and ELLESMERE_BOLD or fontOf(GameTooltipHeaderText)
end

local function styleOf(key)
    local style = ns.style(key)
    style.customFont = style.font ~= nil
    style.font = style.font or (style.title and titleFont() or bodyFont())
    return style
end

-- Escape codes are case sensitive ("|r", "|t", link data), so only the text
-- between them is uppercased.
local ESCAPE_ENDS = { T = "|t", A = "|a", H = "|h", K = "|k", ["4"] = ";" }

local function capitalize(text)
    local out, pos = {}, 1
    while true do
        local bar = text:find("|", pos, true)
        if not bar then break end
        out[#out + 1] = text:sub(pos, bar - 1):upper()
        local code, stop = text:sub(bar + 1, bar + 1), bar + 1
        if code == "c" then
            stop = bar + 9
        elseif ESCAPE_ENDS[code] then
            local _, found = text:find(ESCAPE_ENDS[code], bar + 2, true)
            stop = found or #text
        end
        out[#out + 1] = text:sub(bar, stop)
        pos = stop + 1
    end
    out[#out + 1] = text:sub(pos):upper()
    return table.concat(out)
end

local function asStyle(style)
    if type(style) == "table" then return style end
    return { size = style, font = bodyFont(), flags = "" }
end

local function uncolored(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Rows other addons append are absent from the data. Nil when one is unreadable.
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
        setItems = {},
        setBonuses = {},
        extras = {},
        footerLeft = {},
        footerRight = {},
        lineIndices = {},
        kinds = {},
    }
    local inSet, setTotal = false, 0
    local inStockChanges = false
    local function isStockChange(text)
        local trimmed = plainText(text):match("^%s*(.-)%s*$")
        if trimmed == STOCK_CHANGES or trimmed:find("^If you replace this item") then
            inStockChanges = true
            return true
        end
        if inStockChanges and (trimmed == "" or trimmed:match("^[%+%-][%d%.,]+%%? %S")) then
            return true
        end
        inStockChanges = false
        return false
    end

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

        if isStockChange(left) then
            addExtra(model, left, right, colorOf(line.leftColor), colorOf(line.rightColor))
        elseif lineType == LINE.ItemName then
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
            elseif right:match("^Speed [%d%.]+$") and trimmed:match("^[%d,]+%s*%-%s*[%d,]+ Damage$") then
                model.weaponDamage, model.weaponSpeed = left, right
            elseif trimmed:match("^%([%d%.]+ damage per second%)$") then
                model.weaponDps = trimmed:match("^%(([%d%.]+) damage per second%)$")
            elseif trimmed:match("^[%d,]+ Armor$") then
                add(model.armor, left, right)
                model.armor[#model.armor].value = (trimmed:match("^([%d,]+)"):gsub(",", ""))
            elseif line.prettyTooltipOriginal or trimmed:match("^%+[%d%.]+") then
                -- Combined bonuses arrive as one line; each stat needs its own row.
                for piece in (displayed .. "|n"):gmatch("(.-)|n") do
                    local label = plainText(piece):match("^%s*[%+%-]?[%d%.,]+%%? (.+)$")
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
        if isStockChange(row.left) then
            model.extras[#model.extras + 1] = row
        elseif trimmed:match("^Sell Price") then
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
    model.comparison = isComparison(tooltip)
    return model
end
readModel = probe("read item", readModel)

local function makeTexture(parent, layer, path)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetTexture(path or WHITE)
    return tex
end

local function createPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
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
    if panel.background.SetTextureSliceMargins then
        -- Multiplying barely tints the near-black backdrop; an additive copy carries the glow.
        panel.glow = panel:CreateTexture(nil, "BACKGROUND", nil, -6)
        panel.glow:SetAllPoints()
        panel.glow:SetTexture(DIALOGUE_BACKDROP)
        panel.glow:SetTextureSliceMargins(32, 32, 32, 32)
        panel.glow:SetTextureSliceMode(1)
        panel.glow:SetBlendMode("ADD")
    end
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
    return panel
end

local function getPanel(tooltip)
    local panel = panels[tooltip]
    if panel then return panel end
    panel = createPanel(UIParent)
    panels[tooltip] = panel
    return panel
end

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
    for _, band in ipairs({ panel.header, panel.footer }) do
        if textured then
            band:SetTexture(ART .. "band")
            band:SetTextureSliceMargins(BAND_MARGIN, BAND_MARGIN, BAND_MARGIN, BAND_MARGIN)
        else
            if band.SetTextureSliceMargins then band:SetTextureSliceMargins(0, 0, 0, 0) end
            band:SetTexture(WHITE)
        end
    end
    for _, region in ipairs(panel.shades) do region:SetShown(not textured) end
    for _, region in ipairs(panel.edges) do region:SetShown(not textured) end
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
    if panel.hits then panel.hits = {} end
end

local function textAt(panel, content, x, y, width, size, color, fontPath, align, flags)
    panel.used = panel.used + 1
    local font = panel.pool[panel.used]
    if not font then
        font = panel:CreateFontString(nil, "OVERLAY")
        panel.pool[panel.used] = font
    end
    font:ClearAllPoints()
    font:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y)
    font:SetWidth(width)
    setFont(font, fontPath or bodyFont(), size, flags)
    font:SetJustifyH(align or "LEFT")
    font:SetJustifyV("TOP")
    font:SetTextColor(color[1], color[2], color[3])
    font:SetShadowColor(0, 0, 0, 0)
    font:SetShadowOffset(0, 0)
    font:SetText(content)
    font:Show()
    return math.max(size + 2, font:GetStringHeight() or 0)
end

-- A custom color replaces every color, inline codes included.
local function styledAt(panel, content, x, y, width, style, color, align)
    if style.caps then content = capitalize(content) end
    if style.color then content, color = uncolored(content), style.color end
    local height = textAt(panel, content, x, y, width, style.size, color, style.font, align,
        style.flags)
    if panel.hits and style.key then
        panel.hits[#panel.hits + 1] = { key = style.key, region = panel.pool[panel.used] }
    end
    return height
end

local function measure(panel, text, size, fontPath, flags)
    local font = panel.measure
    setFont(font, fontPath or bodyFont(), size, flags)
    font:SetText(text)
    local width = font.GetUnboundedStringWidth and font:GetUnboundedStringWidth()
        or font:GetStringWidth()
    -- Inline textures can be left out of the measured width.
    local _, textures = text:gsub("|T", "")
    return (width or 0) + textures * (size + 2)
end

local function measureStyled(panel, text, style)
    if style.caps then text = capitalize(text) end
    return measure(panel, text, style.size, style.font, style.flags)
end

local function rowWidth(panel, row, style)
    style = asStyle(style)
    local width = measureStyled(panel, row.left, style)
    if row.right and row.right ~= "" then
        -- The 2 matches the slack drawRow gives the right column.
        return width + COLUMN_GAP + measureStyled(panel, row.right, style) + 2
    end
    return width
end

local function headerInsets(indent)
    if ns.option("iconRight") then return 0, indent end
    return indent, 0
end

local function drawRow(panel, row, y, style, color, indent, gap, rightIndent)
    style = asStyle(style)
    local left = row.left
    local right = row.right
    local leftColor = row.color or color
    indent, gap, rightIndent = indent or 0, gap or 3, rightIndent or 0
    local w = panel.width - 2 * PAD - indent - rightIndent
    if right and right ~= "" then
        local rightWidth = math.min(measureStyled(panel, right, style) + 2,
            math.max(w * .5, w - measureStyled(panel, left, style) - COLUMN_GAP))
        local leftHeight = styledAt(panel, left, PAD + indent, y,
            w - rightWidth - COLUMN_GAP, style, leftColor)
        local rightHeight = styledAt(panel, right, panel.width - PAD - rightIndent - rightWidth, y,
            rightWidth, style, row.rightColor or leftColor, "RIGHT")
        return y + math.max(leftHeight, rightHeight) + gap
    end
    return y + styledAt(panel, left, PAD + indent, y, w, style, leftColor) + gap
end

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

-- before is the gap above a separator; a hidden one takes its gap with it.
local function rule(panel, y, color, before)
    if not ns.option("separators") then return y end
    y = y + (before or 0)
    local line = acquireTexture(panel)
    line:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
    line:SetSize(panel.width - 2 * PAD, 1)
    line:SetVertexColor(color[1], color[2], color[3], .45)
    return y + 9
end

local function divider(panel, y, color, before)
    if not ns.option("separators") then return y end
    y = y + (before or 0)
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

local function drawGroup(panel, list, y, style, color, indent, gap, rightIndent)
    for _, row in ipairs(list) do
        y = drawRow(panel, row, y, style, color, indent, gap, rightIndent)
    end
    return y
end

local function markerIndent(panel, style)
    if not ns.option("statMarkers") then return 0 end
    return 9 + measureStyled(panel, "a  a", style) - measureStyled(panel, "aa", style)
end

-- Drawn apart from the text so wrapped lines hang under the text, not the marker.
local function drawEquipEffects(panel, list, y, style)
    local hang = markerIndent(panel, style)
    local width = panel.width - 2 * PAD - hang
    for _, row in ipairs(list) do
        if hang > 0 then styledAt(panel, STAT_MARKER, PAD, y, hang, style, EQUIP_EFFECT_COLOR) end
        y = y + styledAt(panel, row.left, PAD + hang, y, width, style, EQUIP_EFFECT_COLOR) + 3
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

local function setCountStyle(setName)
    local style = {}
    for field, value in pairs(setName) do style[field] = value end
    style.size = math.max(8, setName.size - 3)
    if not setName.customFont then style.font = bodyFont() end
    return style
end

local function fitWidth(panel, model, title, styles)
    local need = 0
    local function consider(width) if width > need then need = width end end
    local function group(list, style, extra, prose)
        for _, row in ipairs(list) do
            local width = rowWidth(panel, row, style)
            if prose and (not row.right or row.right == "") then
                width = math.min(width, PROSE_WIDTH)
            end
            consider(width + extra)
        end
    end
    local indent = model.icon and HEADER_INDENT or 0
    consider(measureStyled(panel, title, styles.title) + indent)
    if model.slot then consider(measureStyled(panel, model.slot, styles.subtitle) + indent) end
    group(model.header, styles.header, indent)
    if model.weaponDps then
        consider(measureStyled(panel, valueLabel(model.weaponDps, "Damage per Second"), styles.dps))
    end
    if model.weaponDamage then
        consider(measureStyled(panel, weaponText(model), styles.damage) + 7)
    end
    group(model.armor, styles.armor, 0)
    group(model.primary, styles.stats, 0)
    group(model.secondary, styles.stats, 0)
    for _, row in ipairs(model.equipEffects) do
        consider(math.min(measureStyled(panel, row.left, styles.equipEffects), PROSE_WIDTH)
            + markerIndent(panel, styles.equipEffects))
    end
    group(model.enchants, styles.enchants, 0)
    group(model.effects, styles.effects, 0, true)
    group(model.flavor, styles.flavor, 0, true)
    if model.setName then
        local countWidth = measureStyled(panel, model.setCount or "", setCountStyle(styles.setName))
        consider(measureStyled(panel, model.setName, styles.setName)
            + math.max(45, countWidth + COLUMN_GAP))
        group(model.setItems, styles.setItems, 20)
        group(model.setBonuses, styles.setBonuses, 3, true)
    end
    group(model.extras, styles.extras, 0, true)
    for index = 1, math.max(#model.footerLeft, #model.footerRight) do
        local left, right = model.footerLeft[index], model.footerRight[index]
        local leftWidth = 0
        if left and left.durability then
            leftWidth = DURABILITY_BAR + 7 + measureStyled(panel,
                left.durability[1] .. " / " .. left.durability[2], styles.footer)
        elseif left then
            leftWidth = measureStyled(panel, left.left, styles.footer)
        end
        consider(leftWidth + COLUMN_GAP
            + (right and measureStyled(panel, footerText(right), styles.footer) or 0))
    end
    local width = math.ceil(need + 2 * PAD)
    return math.max(MIN_WIDTH, math.min(MAX_WIDTH, width))
end
fitWidth = probe("fit width", fitWidth)

local function durabilityColor(current, maximum)
    local ratio = maximum > 0 and current / maximum or 0
    if current == 0 then return { 1, .34, .28 } end
    if ratio < .25 then return { 1, .52, .25 } end
    if ratio < .5 then return { .95, .76, .30 } end
    return { .45, .80, .40 }
end

local function drawDurability(panel, durability, y, style)
    local current, maximum = durability[1], durability[2]
    local color = durabilityColor(current, maximum)
    local track = acquireTexture(panel, nil, 0)
    track:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(y + math.floor(style.size / 2)))
    track:SetSize(DURABILITY_BAR, 4)
    track:SetVertexColor(.16, .14, .13, 1)
    local fill = acquireTexture(panel, nil, 1)
    local width = maximum > 0 and DURABILITY_BAR * current / maximum or 0
    fill:SetPoint("TOPLEFT", track, "TOPLEFT")
    fill:SetSize(math.max(width, 1), 4)
    fill:SetVertexColor(color[1], color[2], color[3], 1)
    if width < 1 then fill:Hide() end
    local healthy = maximum > 0 and current / maximum >= .5
    return styledAt(panel, current .. " / " .. maximum, PAD + DURABILITY_BAR + 7, y,
        math.max(90, style.size * 8), style, healthy and { .82, .78, .71 } or color)
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

-- Returns the header height the icon and badge need.
local function drawChrome(panel, tooltip, style)
    applyBackdrop(panel)
    -- Panels are shared across kinds; the kind that wants a watermark shows it.
    if panel.watermark then panel.watermark:Hide() end
    local color = style.color
    panel:SetFrameLevel(tooltip:GetFrameLevel() + 5)
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
    local headerAlpha = panel.textured and HEADER_ALPHA_TEXTURED or HEADER_ALPHA_PLAIN
    panel.header:SetGradient("VERTICAL",
        CreateColor(color[1] * .12, color[2] * .12, color[3] * .12,
            ns.headerAlpha(style.kind, "Bottom") or headerAlpha),
        CreateColor(color[1] * .38, color[2] * .38, color[3] * .38,
            ns.headerAlpha(style.kind, "Top") or headerAlpha))
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
        local text = styleOf("badge")
        local textColor = text.color or { color[1] * .45 + .55, color[2] * .45 + .55,
            color[3] * .45 + .55 }
        setFont(panel.badgeText, text.font, text.size, text.flags)
        panel.badgeText:SetTextColor(textColor[1], textColor[2], textColor[3])
        panel.badgeText:SetText(style.badge)
        local height = math.max(BADGE_HEIGHT, text.size + 6)
        badge:SetSize(math.max(iconSize + 2, panel.badgeText:GetStringWidth() + 12), height)
        badge:SetVertexColor(color[1] * .8, color[2] * .8, color[3] * .8, .9)
        panel.badgeFill:SetVertexColor(color[1] * .14, color[2] * .14, color[3] * .14, 1)
        badge:Show()
        panel.badgeFill:Show()
        panel.badgeText:Show()
        if panel.hits then panel.hits[#panel.hits + 1] = { key = "badge", region = badge } end
        headerMin = ICON_TOP + iconSize + BADGE_GAP + height + 10
    else
        panel.badge:Hide()
        panel.badgeFill:Hide()
        panel.badgeText:Hide()
    end
    return headerMin
end
drawChrome = probe("chrome", drawChrome)

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
alignPanel = probe("align panel", alignPanel)

local function finishPanel(panel, tooltip, y)
    panel:SetHeight(y + 17)
    alignPanel(panel, tooltip)
    panel:Show()
end

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
anchorToPanels = probe("anchor comparison", anchorToPanels)

local function render(panel, tooltip, model)
    panel:Show()
    clearPool(panel)
    local styles = {}
    for _, element in ipairs(ns.ELEMENTS) do
        if not element.kind or element.kind == "shared" then
            styles[element.key] = styleOf(element.key)
        end
    end
    if not ns.option("iconItems") then model.icon = nil end
    local title = model.name
    panel.width = fitWidth(panel, model, title, styles)
    panel:SetWidth(panel.width)
    local quality = QUALITY[model.quality] or QUALITY[1]
    local tag
    if model.comparison then
        tag = isEquipped(model) and "EQUIPPED" or "EQUIPPED WITH"
    end
    local accent = model.quest and QUEST_GOLD or quality
    local headerMin = drawChrome(panel, tooltip, {
        kind = "item",
        color = accent,
        tint = (model.quest or model.quality >= 2) and accent or nil,
        icon = model.icon,
        badge = model.icon and ns.option("itemLevelBadge") and model.level
            and (model.equippable or model.levelLine) and ("iLvl " .. model.level),
        tag = tag,
    })

    local y = TITLE_TOP
    local inner = panel.width - 2 * PAD
    local indent = model.icon and HEADER_INDENT or 0
    local leftIndent, rightIndent = headerInsets(indent)
    y = y + styledAt(panel, title, PAD + leftIndent, y, inner - indent, styles.title, quality) + 4
    if model.slot and model.slot ~= "" then
        y = y + styledAt(panel, model.slot, PAD + leftIndent, y, inner - indent, styles.subtitle,
            { quality[1] * .5 + .5, quality[2] * .5 + .5, quality[3] * .5 + .5 }) + 4
    end
    y = drawGroup(panel, model.header, y, styles.header, { .78, .72, .63 }, leftIndent, nil,
        rightIndent)
    y = math.max(y + 6, headerMin)
    panel.header:SetHeight(y - panel.inset)

    local sectioned = false
    if model.weaponDps or model.weaponDamage or #model.armor > 0 or #model.primary > 0
        or #model.secondary > 0 or #model.equipEffects > 0 or #model.enchants > 0
        or #model.effects > 0 or #model.flavor > 0 then
        y = divider(panel, y, GOLD_RULE)
        if model.weaponDps then
            y = drawRow(panel, {
                left = valueLabel(model.weaponDps, "Damage per Second"), right = "",
            }, y, styles.dps, { .93, .87, .75 }) + 2
        end
        if model.weaponDamage then
            y = y + styledAt(panel, weaponText(model), PAD + 7, y, inner - 7, styles.damage,
                { .71, .72, .73 }) + 7
        end
        for _, row in ipairs(model.armor) do
            y = drawRow(panel, {
                left = row.value and valueLabel(row.value, "Armor") or row.left,
                right = row.right, rightColor = row.rightColor,
            }, y, styles.armor, { .93, .87, .75 })
        end
        if #model.armor > 0 then y = y + 5 end
        y = drawGroup(panel, model.primary, y, styles.stats, { .90, .85, .74 })
        if (#model.secondary > 0 or #model.equipEffects > 0) and #model.primary > 0 then
            y = divider(panel, y, GOLD_RULE, 3)
        end
        y = drawGroup(panel, model.secondary, y, styles.stats, { .90, .85, .74 })
        y = drawEquipEffects(panel, model.equipEffects, y, styles.equipEffects)
        y = drawGroup(panel, model.enchants, y, styles.enchants, { .90, .85, .74 })
        if #model.effects > 0 then y = y + 5 end
        y = drawGroup(panel, model.effects, y, styles.effects, { .48, .88, .48 })
        if #model.flavor > 0 then
            y = drawGroup(panel, model.flavor, y + 5, styles.flavor, FLAVOR_GOLD)
        end
        sectioned = true
    end

    if model.setName then
        y = divider(panel, y, GOLD_RULE, sectioned and 11 or 0)
        sectioned = true
        local setTitle = model.setName
        local countStyle = setCountStyle(styles.setName)
        local count = model.setCount or ""
        local countWidth = math.max(42, measureStyled(panel, count, countStyle) + 2)
        local titleHeight = styledAt(panel, setTitle, PAD, y, inner - countWidth - 3,
            styles.setName, { 1, .76, .18 })
        local countHeight = styledAt(panel, count, panel.width - PAD - countWidth, y, countWidth,
            countStyle, { 1, .76, .18 }, "RIGHT")
        y = y + math.max(24, titleHeight + 7, countHeight + 7)
        for _, row in ipairs(model.setItems) do
            local bullet, color = "|cff756C60-  |r", { .61, .58, .54 }
            if row.active == true then
                bullet, color = "|cffD9B36A-  |r", { .94, .89, .77 }
            elseif row.active == false then
                bullet, color = "|cff4A4540-  |r", { .44, .42, .40 }
            end
            y = drawRow(panel, { left = bullet .. row.left, right = row.right },
                y, styles.setItems, color, 5)
        end
        if #model.setBonuses > 0 then y = y + 7 end
        for _, row in ipairs(model.setBonuses) do
            local color = { .68, .65, .57 }
            if row.active == true then
                color = { .48, .88, .48 }
            elseif row.active == false then
                color = { .44, .42, .40 }
            end
            y = drawRow(panel, row, y, styles.setBonuses, color, 3)
        end
    end

    if #model.extras > 0 then
        if sectioned then
            y = rule(panel, y, { .50, .50, .54 }, 10)
        else
            y = y + 12
        end
        y = drawGroup(panel, model.extras, y, styles.extras, EXTRA_COLOR, 0, 2)
    end

    if #model.footerLeft > 0 or #model.footerRight > 0 then
        y = y + 9
        local footerStart = y
        local footer = styles.footer
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
                rightWidth = math.min(measureStyled(panel, content, footer) + 2, inner * .6)
                h2 = styledAt(panel, content, panel.width - PAD - rightWidth, y,
                    rightWidth, footer, color, "RIGHT")
            end
            if left and left.durability then
                h1 = drawDurability(panel, left.durability, y, footer)
            elseif left then
                h1 = styledAt(panel, left.left, PAD, y, inner - rightWidth - COLUMN_GAP,
                    footer, left.color or { .82, .78, .71 })
            end
            y = y + math.max(h1, h2, footer.size + 2) + 4
        end
        panel.footer:SetHeight(y - footerStart + 23)
    else
        panel.footer:SetHeight(0)
    end
    finishPanel(panel, tooltip, y)
end
render = probe("render item", render)

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
    -- A refresh asks for several refits; only a changed size needs one.
    if panel.fittedWidth and math.abs(tooltip:GetWidth() - panel.fittedWidth) <= .5
        and math.abs(tooltip:GetHeight() - panel.fittedHeight) <= .5
        and math.abs(panel:GetWidth() - panel.fittedPanelWidth) <= .5
        and math.abs(panel:GetHeight() - panel.fittedPanelHeight) <= .5 then
        return
    end
    count("refit applied")
    -- GetPadding reports the applied padding and SetPadding resizes at once, so
    -- the natural size needs no layout pass to measure.
    if tooltip.GetPadding then
        local currentRight, currentBottom = tooltip:GetPadding()
        if type(currentRight) == "number" and type(currentBottom) == "number" then
            local panelWidth, panelHeight = panel:GetWidth(), panel:GetHeight()
            local right = base.right + math.max(0, panelWidth
                - (tooltip:GetWidth() - (currentRight - base.right)))
            local bottom = base.bottom + math.max(0, panelHeight
                - (tooltip:GetHeight() - (currentBottom - base.bottom)))
            if math.abs(right - currentRight) > .01 or math.abs(bottom - currentBottom) > .01 then
                tooltip:SetPadding(right, bottom, base.left, base.top)
            end
            local width, height = tooltip:GetWidth(), tooltip:GetHeight()
            local widthFits = right > base.right and math.abs(width - panelWidth) <= 1
                or right <= base.right and width >= panelWidth - .5
            local heightFits = bottom > base.bottom and math.abs(height - panelHeight) <= 1
                or bottom <= base.bottom and height >= panelHeight - .5
            if widthFits and heightFits then
                count("refit fast")
                panel.fittedWidth, panel.fittedHeight = width, height
                panel.fittedPanelWidth, panel.fittedPanelHeight = panelWidth, panelHeight
                return
            end
            count("refit fallback")
        end
    end
    tooltip:SetPadding(base.right, base.bottom, base.left, base.top)
    tooltip:Show()
    local right = base.right + math.max(0, panel:GetWidth() - tooltip:GetWidth())
    local bottom = base.bottom + math.max(0, panel:GetHeight() - tooltip:GetHeight())
    if right ~= base.right or bottom ~= base.bottom then
        tooltip:SetPadding(right, bottom, base.left, base.top)
        tooltip:Show()
    end
    panel.fittedWidth, panel.fittedHeight = tooltip:GetWidth(), tooltip:GetHeight()
    panel.fittedPanelWidth, panel.fittedPanelHeight = panel:GetWidth(), panel:GetHeight()
end

local function refitNative(tooltip, panel)
    if panel.fitting then return end
    panel.fitting = true
    pcall(fitNative, tooltip, panel)
    panel.fitting = false
end
refitNative = probe("refit hidden tooltip", refitNative)

local function releaseNative(tooltip, panel)
    local base = panel.nativeSize
    panel.nativeSize, panel.fittedWidth = nil, nil
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
    for comparison in pairs(panels) do
        if isComparison(comparison) then
            pcall(retarget, comparison, function(frame)
                return frame == panel and tooltip or frame
            end)
        end
    end
end

-- Each tooltip data type the panel draws: read(tooltip, data) -> model,
-- render(panel, tooltip, model), key(tooltip, data) naming what is shown,
-- and option, the setting that turns the kind on.
local KINDS = {}
KINDS[ITEM] = { read = readModel, render = render, key = getItemInfo, option = "itemPanels" }

local function showsOriginal(panel)
    local kind = KINDS[panel.kind]
    return ns.originalKeyDown() or not (kind and ns.option(kind.option))
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
update = probe("update", update)

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

local function onTooltipData(dataType, tooltip, data)
    -- The editor reads this one itself.
    if tooltip.prettyTooltipScanner then return end
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
        tooltip:HookScript("OnTooltipCleared", scheduleRestore)
        -- Every refresh re-shows the tooltip at its natural size and full
        -- opacity. Waiting for the next OnUpdate lets one frame of it draw.
        local function onNativeShown(shown)
            count(isComparison(shown) and "show hook (comparison)" or "show hook")
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
end
onTooltipData = probe("tooltip data", onTooltipData)

local function registerKind(dataType, kind)
    kind.read = probe("read " .. dataType, kind.read)
    kind.render = probe("render " .. dataType, kind.render)
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

-- The editor's sample, drawn inside anchor; hits record where each part landed.
local function renderPreview(anchor, model, dataType)
    local panel = anchor.prettyTooltipPreview
    if not panel then
        panel = createPanel(anchor)
        panel:SetFrameStrata(anchor:GetFrameStrata())
        panel:SetClampedToScreen(false)
        anchor.prettyTooltipPreview = panel
    end
    panel.hits = {}
    KINDS[dataType or ITEM].render(panel, anchor, model)
    return panel
end

local function defaultHeaderAlpha()
    if ns.option("dialogueBackdrop") and hasDialogueBackdrop() then return HEADER_ALPHA_TEXTURED end
    return HEADER_ALPHA_PLAIN
end

-- The editor's lookup by ID reads this hidden tooltip; it never gets a panel.
local scanner
local function previewByID(anchor, dataType, id)
    if not scanner then
        scanner = CreateFrame("GameTooltip", "PrettyTooltipScanner", UIParent, "GameTooltipTemplate")
        scanner.prettyTooltipScanner = true
    end
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    if dataType == ITEM then scanner:SetItemByID(id) else scanner:SetSpellByID(id) end
    local data = scanner:GetTooltipData()
    local kind = KINDS[dataType]
    local ok, model = pcall(kind.read, scanner, data)
    scanner:Hide()
    if not (ok and model) then return end
    return renderPreview(anchor, model, dataType)
end

function ns.perfCapture(seconds)
    perf.calls, perf.time, perf.on = {}, {}, true
    local memory = collectgarbage("count")
    print("PrettyTooltip: measuring for " .. seconds .. " seconds; keep the tooltip open.")
    C_Timer.After(seconds, function()
        perf.on = false
        local names, counts = {}, {}
        for name, calls in pairs(perf.calls) do
            if perf.time[name] then
                names[#names + 1] = name
            else
                counts[#counts + 1] = name .. " " .. calls
            end
        end
        table.sort(names, function(a, b) return perf.time[a] > perf.time[b] end)
        table.sort(counts)
        print(string.format("PrettyTooltip perf over %d s (memory %+.0f KB):", seconds,
            collectgarbage("count") - memory))
        if #counts > 0 then print("  counts: " .. table.concat(counts, ", ")) end
        for _, name in ipairs(names) do
            print(string.format("  %s: %d calls (%.0f/s), %.1f ms", name, perf.calls[name],
                perf.calls[name] / seconds, perf.time[name] or 0))
        end
    end)
end

ns.ui = {
    renderPreview = renderPreview,
    previewByID = previewByID,
    defaultHeaderAlpha = defaultHeaderAlpha,
    styleOf = styleOf,
    alignPanel = alignPanel,
    shownPanel = function(tooltip)
        local panel = panels[tooltip]
        if panel and panel:IsShown() then return panel end
    end,
    styledAt = styledAt,
    measureStyled = measureStyled,
    enchantRows = enchantRows,
    formatMoney = formatMoney,
    setFont = setFont,
    FLAVOR_GOLD = FLAVOR_GOLD,
    isSecret = isSecret,
    safeText = safeText,
    add = add,
    colorOf = colorOf,
    appendedRows = appendedRows,
    requirementMet = requirementMet,
    clearPool = clearPool,
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
    EXTRA_COLOR = EXTRA_COLOR,
    GOLD_RULE = GOLD_RULE,
}
