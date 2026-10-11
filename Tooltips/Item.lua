-- Items as a panel: the reader, which turns the game's item lines into a
-- model, and the renderer, which draws it. The panel, its chrome, and the
-- hooks that show it are in Panel/Layout.lua.
local _, ns = ...
local ui = ns.ui
local ITEM = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
if not (ui and ITEM) then
    return
end

local util = ns.util
local colors = ns.Palette.roles
local isSecret, safeText, number = util.isSecret, util.safeText, util.number
local plainText, rgb = util.plainText, util.rgb
local LINE = Enum.TooltipDataLineType
local ART = "Interface\\AddOns\\PrettyTooltip\\art\\"
local pad, minWidth, titleTop = ui.pad, ui.minWidth, ui.titleTop
local MAX_WIDTH, PROSE_WIDTH, COLUMN_GAP = ui.MAX_WIDTH, ui.PROSE_WIDTH, ui.COLUMN_GAP
local ICON_SIZE, EXTRA_COLOR, GOLD_RULE, FLAVOR_GOLD, probe, bodyFont = ui.ICON_SIZE, ui.EXTRA_COLOR, ui.GOLD_RULE, ui.FLAVOR_GOLD, ui.probe, ui.bodyFont
local isComparison = ui.isComparison
local isRed, add, colorOf = ns.TooltipData.isRed, ns.TooltipData.add, ns.TooltipData.colorOf
local appendedRows, requirementMet = ns.TooltipData.appendedRows, ns.TooltipData.requirementMet
local formatMoney, enchantRows, styleOf, clearPool, styledAt, measureStyled = ui.formatMoney, ui.enchantRows, ui.styleOf, ui.clearPool, ui.styledAt, ui.measureStyled
local rowWidth, headerInsets, drawRow, acquireTexture, rule, divider = ui.rowWidth, ui.headerInsets, ui.drawRow, ui.acquireTexture, ui.rule, ui.divider
local caption, drawGroup, drawChrome, finishPanel = ui.caption, ui.drawGroup, ui.drawChrome, ui.finishPanel

local QUEST_CLASS = Enum.ItemClass and Enum.ItemClass.Questitem or 12
local CONSUMABLE_CLASS = Enum.ItemClass and Enum.ItemClass.Consumable or 0
local DURABILITY_BAR = 54
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
local function getItemInfo(tooltip, data)
    if tooltip.GetItem then
        local ok, _, link = pcall(tooltip.GetItem, tooltip)
        if ok and not isSecret(link) and link then return link end
    end
    if not isSecret(data.hyperlink) and data.hyperlink then return data.hyperlink end
    if not isSecret(data.id) then return data.id end
end

-- A bag's "16 Slot Soul Bag" line, in its subtitle: the kind of bag, in place
-- of a plainer slot it ends with, then the slots.
local function withBagSlots(item)
    local bag = item.bag
    if not bag then return end
    local slot, kind = item.slot or "", bag.kind
    if slot == "" or kind:sub(-#slot) == slot then
        slot = kind
    elseif slot ~= kind then
        slot = slot .. " \194\183 " .. kind
    end
    item.slot = slot .. " \194\183 " .. bag.count .. (bag.count == 1 and " Slot" or " Slots")
end

local function getQuality(itemInfo, data, game)
    local info = game.itemInfo(itemInfo)
    if info and type(info.quality) == "number" then return info.quality end
    return number(data.quality) or 1
end

local function getLevel(itemInfo, game)
    local level = game.itemLevel(itemInfo)
    if level and level > 0 then return level end
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

local UNUSABLE_COLOR = colors.unmet

local function unusable(text, color)
    if isRed(color) then return "|cffFF5747" .. text .. "|r" end
    return text
end

-- A stack's per-item price, beside its total: a muted shade of the footer's gold.
local PRICE_DETAIL = "9E9485"

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

-- Must match STAT_MARKER in Data/Stats.lua, minus its trailing spaces.
local STAT_MARKER = "|T" .. ART .. "stat-marker:9:9:0:-2|t"
local EQUIP_EFFECT_COLOR = { .48, .88, .48 }
-- A sword marks a chance on hit, a sparkle an enchant, and a gear a use
-- effect: white art from art/make_markers.py, tinted here. Every row's text
-- starts after a 9 px marker, the size of the diamond in a stat's text. These
-- three are drawn apart from their text, two pixels larger and shifted one
-- left, so they center where the diamond does.
local MARKER_SIZE = 9
local ON_HIT_MARKER = "|T" .. ART .. "marker-sword:11:11:-1:-2:32:32:0:32:0:32:200:210:225|t"
local ENCHANT_MARKER = "|T" .. ART .. "marker-sparkle:11:11:-1:-2:32:32:0:32:0:32:90:230:60|t"
local USE_MARKER = "|T" .. ART .. "marker-gear:11:11:-1:-2:32:32:0:32:0:32:240:200:90|t"
-- Markers that stand in for a line's opening words, which come back while
-- markers are off.
local MARKED = {
    onHit = { ON_HIT_MARKER, "Chance on hit: " },
    use = { USE_MARKER, "Use: " },
}

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

-- The game's "If you replace this item" lines are kept as rows from another
-- source; their "+5 Stamina" lines must not be read as the item's own stats.
local STOCK_CHANGES = ITEM_DELTA_DESCRIPTION
    or "If you replace this item, the following stat changes will occur:"

local PROFESSIONS = {
    Alchemy = true, Blacksmithing = true, Enchanting = true, Engineering = true,
    Leatherworking = true, Tailoring = true, Cooking = true, ["First Aid"] = true, Fishing = true,
    Mining = true, Herbalism = true, Skinning = true, Jewelcrafting = true, Inscription = true,
}

-- "Requires Blacksmithing (80)": the profession and level a recipe needs.
local function professionRequirement(text)
    local name, level = text:match("^Requires (.-) %((%d+)%)$")
    if name and PROFESSIONS[name] then return name, tonumber(level) end
end

-- "Requires Bronze Bar (10), Sulfuric Acid (2)": a recipe's reagents.
local function reagentList(text)
    text = plainText(text):gsub("^%s*Requires%s+", "")
    if not text:find("%(%d+%)") then return end
    local list = {}
    for piece in (text .. ","):gmatch("%s*(.-)%s*,") do
        if piece == "" then return end
        local name, count = piece:match("^(.-)%s*%((%d+)%)$")
        list[#list + 1] = { name = name or piece, count = tonumber(count) or 1 }
    end
    return list
end

-- Only items the client has seen resolve by name.
local function itemByName(name, game)
    local info = game.itemInfo(name)
    if info and info.link then return info.link, info.quality, info.icon end
end

local function newItemModel()
    return {
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
        kinds = {},
        weaponBonus = {},
    }
end

-- How many the shown stack holds: its bag slot knows, else the data line's
-- price, which covers the stack, gives it away.
local function stackCount(data, unitPrice, linePrice, game)
    local count = game.stackCount(data.guid)
    if count then return count end
    if linePrice and linePrice > unitPrice and linePrice % unitPrice == 0 then
        return linePrice / unitPrice
    end
    return 1
end

-- A recipe's lines hold the crafted item's whole tooltip, from its name line
-- to the reagents; those go into model.created.
local function finishRecipe(tooltip, model, data, game)
    local recipeID = not isSecret(data.id) and data.id or nil
    if recipeID then
        model.link, model.icon = recipeID, game.itemIcon(recipeID) or model.icon
        model.quality, model.level = getQuality(recipeID, data, game), getLevel(recipeID, game)
    end
    model.levelLine = nil
    if model.skill then
        local text = "Requires " .. model.skill.name .. " " .. model.skill.level
        if model.levelRequirement then
            add(model.footerRight, text, "")
            local entry = model.footerRight[#model.footerRight]
            entry.requirement, entry.met = true, model.skill.met
        else
            model.levelRequirement = { text = text, met = model.skill.met }
        end
        model.slot = (model.name:match("^(%a+):") or "Recipe") .. " \194\183 " .. model.skill.name
    end
    local created = model.created
    if created then
        local link, quality, icon = itemByName(created.name, game)
        if not link and tooltip.GetItem then
            -- The game reports the crafted item as the tooltip's item, under the
            -- recipe's name; its link names it, and gives the icon before it loads.
            local ok, _, itemLink = pcall(tooltip.GetItem, tooltip)
            if ok and not isSecret(itemLink) and type(itemLink) == "string"
                and itemLink:match("%[(.-)%]") == created.name then
                link, icon = itemLink, game.itemIcon(itemLink)
                local loaded = itemByName(itemLink, game)
                if loaded then quality = getQuality(itemLink, {}, game) end
            end
        end
        created.link, created.icon = link, icon
        created.quality = type(quality) == "number" and quality or nil
        -- The crafted item's binding usually repeats the recipe's.
        local recipeBinding = model.header[1] and model.header[1].left
        local bindings = {}
        for _, row in ipairs(created.header) do
            if row.left ~= recipeBinding then bindings[#bindings + 1] = plainText(row.left) end
        end
        created.binding = #bindings > 0 and table.concat(bindings, " \194\183 ") or nil
    elseif model.teaches then
        add(model.effects, model.teaches.left, model.teaches.right)
    end
    for _, reagent in ipairs(model.reagents or {}) do
        local link, _, icon = itemByName(reagent.name, game)
        reagent.icon = icon
        reagent.have = game.itemCount(link or reagent.name)
    end
end

local function readModel(tooltip, data, game)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local itemInfo = getItemInfo(tooltip, data)
    local model = newItemModel()
    model.link = itemInfo
    model.quality = getQuality(itemInfo, data, game)
    model.icon = game.itemIcon(itemInfo)
    model.level = getLevel(itemInfo, game)
    model.lineIndices = {}
    -- Lines go to the recipe or, inside its embedded tooltip, the crafted item.
    local m = model
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
            m.hasSellPrice = true
            local price = number(line.price)
            if price then m.sellPrice = price end
        end
        if line.lineIndex then
        local left, right = safeText(line.leftText), safeText(line.rightText)
        if not left or not right then return end
        local lineType = line.type
        if line.lineIndex then model.lineIndices[line.lineIndex] = true end
        local trimmed = left:match("^%s*(.-)%s*$")
        if trimmed == "Quest Item" or trimmed:match("^This Item Begins a Quest") then
            m.quest = true
        end
        if isSecret(line.prettyTooltipDisplay) or isSecret(line.prettyTooltipOriginal) then return end
        local displayed = line.prettyTooltipDisplay or left

        if isStockChange(left) then
            addExtra(m, left, right, colorOf(line.leftColor), colorOf(line.rightColor))
        elseif trimmed:match("^Use: Teaches you how to") then
            model.teaches = { left = left, right = right }
        elseif m == model and professionRequirement(trimmed) then
            local name, level = professionRequirement(trimmed)
            model.skill = { name = name, level = level, text = left, met = requirementMet(trimmed, line.leftColor, game) }
        elseif model.created and not model.reagents and reagentList(trimmed) then
            model.reagents, m = reagentList(trimmed), model
        elseif lineType == LINE.ItemName then
            if not model.name then
                model.name, model.nameColor = left, rgb(line.leftColor)
            elseif not model.created then
                model.created = newItemModel()
                -- Its name line starts with a line break.
                model.created.name, model.created.nameColor = trimmed, rgb(line.leftColor)
                m = model.created
            end
        elseif lineType == LINE.ItemLevel then
            local level = left:match("(%d+)")
            if level then m.level, m.levelLine = tonumber(level), true end
        elseif lineType == LINE.EquipSlot then
            m.equippable = true
            local slot = unusable(left, line.leftColor)
            local kind = unusable(right, line.rightColor)
            m.slot = right ~= "" and (kind .. " \194\183 " .. slot) or slot
        elseif lineType == LINE.ItemBinding or trimmed:match("^Binds ")
            or trimmed == "Soulbound" or trimmed:match("^Unique") then
            add(m.header, left, right)
            if isRed(line.leftColor) then m.header[#m.header].color = UNUSABLE_COLOR end
        elseif trimmed:match("^%d+ Slot %a") and right == "" then
            local count, kind = trimmed:match("^(%d+) Slot (.+)$")
            m.bag = { count = tonumber(count), kind = kind }
        elseif itemKind(left, right) then
            local kind, text = itemKind(left, right, line.leftColor)
            m.kinds[kind] = text
        elseif trimmed ~= "" then
            local setName, count, total = trimmed:match("^(.-) %((%d+)/(%d+)%)$")
            if setName and not m.setName then
                m.setName, m.setCount = setName, count .. "/" .. total
                inSet, setTotal = true, tonumber(total)
            elseif LINE.SellPrice and lineType == LINE.SellPrice then
                m.hasSellPrice = true
            elseif trimmed:match("^Requires Level %d+$") and right == "" then
                m.levelRequirement = {
                    text = trimmed, met = requirementMet(trimmed, line.leftColor, game),
                }
            elseif trimmed:match("^Requires ") then
                add(m.footerRight, left, right)
                local entry = m.footerRight[#m.footerRight]
                entry.requirement = true
                entry.met = requirementMet(trimmed, line.leftColor, game)
            elseif trimmed:match("^Durability %d+ / %d+$") then
                add(m.footerLeft, trimmed, right)
                local current, maximum = trimmed:match("(%d+) / (%d+)")
                m.footerLeft[#m.footerLeft].durability =
                    { tonumber(current), tonumber(maximum) }
            elseif trimmed:match("^Classes:") or trimmed:match("^Races:")
                or trimmed:match("^You haven't collected") or trimmed:match("^Appearance ") then
                add(m.footerLeft, left, right)
                if isRed(line.leftColor) then
                    m.footerLeft[#m.footerLeft].color = UNUSABLE_COLOR
                end
            elseif inSet and trimmed:match("^%(%d+%) Set:") then
                add(m.setBonuses, left, right)
                m.setBonuses[#m.setBonuses].active = isActive(line.leftColor)
            elseif inSet and #m.setItems < setTotal
                and right == "" and trimmed:match("^[%a'%- ]+$") then
                add(m.setItems, trimmed, right)
                m.setItems[#m.setItems].active = isActive(line.leftColor)
            -- A wand names its school: "64 - 120 Shadow Damage".
            elseif right:match("^Speed [%d%.]+$") and (trimmed:match("^[%d,]+%s*%-%s*[%d,]+ Damage$")
                or trimmed:match("^[%d,]+%s*%-%s*[%d,]+ %a+ Damage$")) then
                m.weaponDamage, m.weaponSpeed = left, right
            elseif trimmed:match("^%+%s*[%d,]+%s*%-%s*[%d,]+ %a+ Damage$") then
                -- A weapon's bonus damage of a school, drawn under its base damage.
                m.weaponBonus[#m.weaponBonus + 1] = trimmed
            elseif trimmed:match("^%([%d%.]+ damage per second%)$") then
                m.weaponDps = trimmed:match("^%(([%d%.]+) damage per second%)$")
            elseif trimmed:match("^[%d,]+ Armor$") then
                add(m.armor, left, right)
                m.armor[#m.armor].value = (trimmed:match("^([%d,]+)"):gsub(",", ""))
            elseif ((LINE.ItemSpellTriggerOnProc and lineType == LINE.ItemSpellTriggerOnProc)
                or trimmed:match("^Chance on hit:")) and right == "" then
                -- Rewritten proc text stays an effect, rather than a stat.
                local text = line.prettyTooltipOriginal or trimmed
                add(m.equipEffects, (text:gsub("^Chance on hit:%s*", "")), "")
                m.equipEffects[#m.equipEffects].onHit = true
            elseif line.prettyTooltipOriginal or trimmed:match("^%+[%d%.]+") then
                -- Combined bonuses arrive as one line; each stat needs its own row.
                for piece in (displayed .. "|n"):gmatch("(.-)|n") do
                    local label = plainText(piece):match("^%s*[%+%-]?[%d%.,]+%%? (.+)$")
                    add(PRIMARY_STATS[label] and m.primary or m.secondary, piece, right)
                    right = ""
                end
            elseif trimmed:match('^".+"$') then
                add(m.flavor, left, right)
            elseif readCopyLine(m, left, right) then
                -- Crafter or enchant, taken into their own rows.
            elseif trimmed:match("^<.+>$") then
                add(m.effects, left, right)
            elseif trimmed:match("^Equip:") and right == "" then
                -- Unparsed equip effects join the stats; the list implies "Equip:".
                add(m.equipEffects, (trimmed:gsub("^Equip:%s*", "")), "")
            elseif trimmed:match("^Use:") and right == "" then
                -- Its gear marker stands for the words.
                add(m.effects, (trimmed:gsub("^Use:%s*", "")), "")
                m.effects[#m.effects].use = true
            elseif trimmed:match("^Equip:") or trimmed:match("^Use:") then
                add(m.effects, left, right)
            else
                addExtra(m, left, right, colorOf(line.leftColor), colorOf(line.rightColor))
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
        elseif model.created and not model.reagents and reagentList(trimmed) then
            model.reagents = reagentList(trimmed)
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
    -- Crafted gear can need a profession too; only a recipe teaches.
    local recipe = model.created or (model.skill and model.teaches)
    if recipe then
        finishRecipe(tooltip, model, data, game)
        itemInfo = model.link
    else
        if model.skill then
            add(model.footerRight, model.skill.text, "")
            local entry = model.footerRight[#model.footerRight]
            entry.requirement, entry.met = true, model.skill.met
        end
        if model.teaches then add(model.effects, model.teaches.left, model.teaches.right) end
    end
    local classID, className, subClassName, equipLoc, itemID
    local itemType = game.itemType(itemInfo)
    if itemType then
        classID, className, subClassName = itemType.classID, itemType.className, itemType.subClassName
        equipLoc, itemID = itemType.equipLoc, itemType.id
    end
    if ns.disenchantFor and classID and not recipe then
        local itemLevel = game.itemLevel(itemInfo) or model.level
        model.disenchant = ns.disenchantFor(classID, model.quality, tonumber(itemLevel), equipLoc, itemID, game)
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
    withBagSlots(model)
    if model.created then withBagSlots(model.created) end

    -- The item's own price is per unit; the data line's covers the stack.
    local unitPrice
    local info = model.hasSellPrice and game.itemInfo(itemInfo)
    if info and type(info.price) == "number" and info.price > 0 then unitPrice = info.price end
    -- The coins say what the amount is. A stack leads with its total, then the
    -- count and one item's price, dimmed: 2g  (20 × 10s).
    local count = unitPrice and stackCount(data, unitPrice, model.sellPrice, game) or 1
    local price = count > 1 and unitPrice or model.sellPrice or unitPrice
    if price and price > 0 then
        local text = formatMoney(price * count)
        if count > 1 then
            text = text .. "  |cff" .. PRICE_DETAIL .. "(" .. count .. " \195\151 " .. formatMoney(price) .. ")|r"
        end
        add(model.footerRight, text, "")
        model.footerRight[#model.footerRight].sellPrice = true
    end
    model.quest = model.quest or classID == QUEST_CLASS
    model.comparison = isComparison(tooltip)
    return model
end
readModel = probe("read item", readModel)

-- Where an effect's or enchant's text starts: after a marker and two spaces,
-- as a stat's does.
local function markerIndent(panel, style)
    if not ns.option("statMarkers") then return 0 end
    return MARKER_SIZE + measureStyled(panel, "a  a", style) - measureStyled(panel, "aa", style)
end

-- Equip effects, enchants, and use effects, each led by a marker (a chance on
-- hit by the sword) drawn apart from the text, so wrapped lines hang under it.
-- numbers: an effect's numbers are highlighted, in its school's tint when it
-- names one; enchants read as stats and keep theirs.
local function drawMarked(panel, list, y, style, color, marker, numbers)
    local hang = markerIndent(panel, style)
    local width = panel.width - 2 * pad() - hang
    for _, row in ipairs(list) do
        local text = row.left
        if numbers then text = ns.Stats.styleEffect(text, ns.option("statColors")) end
        local stands = row.onHit and MARKED.onHit or row.use and MARKED.use
        if hang > 0 then
            styledAt(panel, stands and stands[1] or marker, pad(), y, hang, style, color)
        elseif stands then
            -- Without its marker, the line keeps its words.
            text = stands[2] .. text
        end
        y = y + styledAt(panel, text, pad() + hang, y, width, style, color) + 3
    end
    return y
end

-- Use effects are led by the gear; the group's other rows, such as
-- "<Right Click to Open>", are drawn as they come.
local function drawEffects(panel, list, y, style, color)
    for _, row in ipairs(list) do
        if row.use then
            y = drawMarked(panel, { row }, y, style, color, nil, true)
        else
            y = drawRow(panel, row, y, style, color)
        end
    end
    return y
end

local function footerText(row)
    if row.right ~= "" then return row.left .. " " .. row.right end
    return row.left
end

-- Read at draw time, so the editor's samples follow the setting too.
local function shownFooterRight(model)
    if ns.option("sellPrice") then return model.footerRight end
    local rows = {}
    for _, row in ipairs(model.footerRight) do
        if not row.sellPrice then rows[#rows + 1] = row end
    end
    return rows
end

-- Damage of a school in its stat colors, from Data/Stats.lua.
local function damageText(text)
    return ns.Stats.styleDamage(text, ns.option("statColors"))
end

local function weaponText(model)
    local text = damageText(model.weaponDamage)
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

local DISENCHANT_GREY = { .55, .53, .50 }

local function disenchantHeading(result)
    local row = { left = "Disenchant", right = "Requires Enchanting " .. result.skill }
    if not result.player then
        row.rightColor = DISENCHANT_GREY
    elseif result.player < result.skill then
        row.rightColor = UNUSABLE_COLOR
    end
    return row
end

local function disenchantRows(result)
    local rows = {}
    for _, entry in ipairs(result.rows) do
        local count = entry.count[1] == entry.count[2] and (entry.count[1] > 1 and entry.count[1] .. " " or "")
            or (entry.count[1] .. "\226\128\147" .. entry.count[2] .. " ")
        local icon = entry.icon and ("|T" .. entry.icon .. ":0|t ") or ""
        rows[#rows + 1] = {
            left = icon .. count .. (entry.name or "?"),
            right = string.format("%g%%", math.floor(entry.chance * 10 + .5) / 10),
        }
    end
    if result.value then
        rows[#rows + 1] = { left = "Expected value", right = formatMoney(result.value), color = DISENCHANT_GREY }
    end
    return rows
end

local CREATED_ICON = 26

local function reagentRows(model)
    local rows = {}
    for _, reagent in ipairs(model.reagents or {}) do
        local icon = reagent.icon and ("|T" .. reagent.icon .. ":0|t ") or ""
        local row = { left = icon .. reagent.name, right = tostring(reagent.count) }
        if reagent.have then
            row.right = reagent.have .. " / " .. reagent.count
            if reagent.have < reagent.count then row.rightColor = UNUSABLE_COLOR end
        end
        rows[#rows + 1] = row
    end
    return rows
end

local function createdSubtitle(created)
    local parts = {}
    if created.slot and created.slot ~= "" then parts[#parts + 1] = created.slot end
    if created.binding then parts[#parts + 1] = created.binding end
    if created.levelRequirement then parts[#parts + 1] = created.levelRequirement.text end
    if #parts > 0 then return table.concat(parts, " \194\183 ") end
end

-- The item level plate under the icon is as wide as the icon's border, with
-- its text padded 5 on each side; a larger text grows the icon rather than
-- the plate, sized for a two-digit level so every item's icon is the same size.
local function itemIconSize(panel, badge, style)
    if not badge then return ICON_SIZE end
    return math.max(ICON_SIZE, math.ceil(measureStyled(panel, "iLvl 88", style)) + 8)
end

local function fitWidth(panel, model, title, styles, iconSize)
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
    -- Use effects are indented past their gear.
    local function effects(list)
        for _, row in ipairs(list) do
            group({ row }, styles.effects, row.use and markerIndent(panel, styles.effects) or 0, true)
        end
    end
    local indent = model.icon and iconSize + 10 or 0
    consider(measureStyled(panel, title, styles.title) + indent)
    if model.slot then consider(measureStyled(panel, model.slot, styles.subtitle) + indent) end
    group(model.header, styles.header, indent)
    if model.weaponDps then
        consider(measureStyled(panel, valueLabel(model.weaponDps, "Damage per Second"), styles.dps))
    end
    if model.weaponDamage then
        consider(measureStyled(panel, weaponText(model), styles.damage) + 7)
    end
    for _, bonus in ipairs(model.weaponBonus) do
        consider(measureStyled(panel, damageText(bonus), styles.damage) + 7)
    end
    group(model.armor, styles.armor, 0)
    group(model.primary, styles.stats, 0)
    group(model.secondary, styles.stats, 0)
    for _, row in ipairs(model.equipEffects) do
        consider(math.min(measureStyled(panel, row.left, styles.equipEffects), PROSE_WIDTH)
            + markerIndent(panel, styles.equipEffects))
    end
    group(model.enchants, styles.enchants, markerIndent(panel, styles.enchants))
    effects(model.effects)
    group(model.flavor, styles.flavor, 0, true)
    if model.setName then
        local countWidth = measureStyled(panel, model.setCount or "", setCountStyle(styles.setName))
        consider(measureStyled(panel, model.setName, styles.setName)
            + math.max(45, countWidth + COLUMN_GAP))
        group(model.setItems, styles.setItems, 20)
        group(model.setBonuses, styles.setBonuses, 3, true)
    end
    if model.disenchant and ns.option("disenchant") then
        consider(rowWidth(panel, disenchantHeading(model.disenchant), styles.disenchant))
        group(disenchantRows(model.disenchant), styles.disenchant, 0)
    end
    if model.created then
        local created = model.created
        consider(measureStyled(panel, created.name, styles.createdName) + CREATED_ICON + 8)
        local subtitle = createdSubtitle(created)
        if subtitle then consider(math.min(measureStyled(panel, subtitle, styles.subtitle), PROSE_WIDTH) + CREATED_ICON + 8) end
        local body = { "armor", "primary", "secondary", "enchants" }
        for _, key in ipairs(body) do
            local style = styles[key == "armor" and "armor" or key == "enchants" and "enchants" or "stats"]
            group(created[key], style, key == "enchants" and markerIndent(panel, style) or 0)
        end
        effects(created.effects)
        group(created.flavor, styles.flavor, 0, true)
        for _, row in ipairs(created.equipEffects) do
            consider(math.min(measureStyled(panel, row.left, styles.equipEffects), PROSE_WIDTH)
                + markerIndent(panel, styles.equipEffects))
        end
        if created.weaponDps then
            consider(measureStyled(panel, valueLabel(created.weaponDps, "Damage per Second"), styles.dps))
        end
    end
    group(reagentRows(model), styles.reagents, 0)
    group(model.extras, styles.extras, 0, true)
    local footerRight = shownFooterRight(model)
    for index = 1, math.max(#model.footerLeft, #footerRight) do
        local left, right = model.footerLeft[index], footerRight[index]
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
    local width = math.ceil(need + 2 * pad())
    return math.max(minWidth(), math.min(MAX_WIDTH, width))
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
    track:SetPoint("TOPLEFT", panel, "TOPLEFT", pad(), -(y + math.floor(style.size / 2)))
    track:SetSize(DURABILITY_BAR, 4)
    track:SetVertexColor(.16, .14, .13, 1)
    local fill = acquireTexture(panel, nil, 1)
    local width = maximum > 0 and DURABILITY_BAR * current / maximum or 0
    fill:SetPoint("TOPLEFT", track, "TOPLEFT")
    fill:SetSize(math.max(width, 1), 4)
    fill:SetVertexColor(color[1], color[2], color[3], 1)
    if width < 1 then fill:Hide() end
    local healthy = maximum > 0 and current / maximum >= .5
    return styledAt(panel, current .. " / " .. maximum, pad() + DURABILITY_BAR + 7, y,
        math.max(90, style.size * 8), style, healthy and { .82, .78, .71 } or color)
end

-- A shield or off-hand is also compared against the one-hander from the bags
-- it would be worn with; Blizzard heads that one "Equipped With". Asked
-- while drawing, until Phase 5 moves it into the model.
local function isEquipped(model)
    return ns.Game.isEquipped(model.link) ~= false
end

-- Stats, effects, and the set, below a header; opened skips the first divider.
local function drawBody(panel, model, styles, y, inner, opened)
    local sectioned = false
    if model.weaponDps or model.weaponDamage or #model.weaponBonus > 0 or #model.armor > 0 or #model.primary > 0
        or #model.secondary > 0 or #model.equipEffects > 0 or #model.enchants > 0
        or #model.effects > 0 or #model.flavor > 0 then
        if not opened then y = divider(panel, y, GOLD_RULE) end
        if model.weaponDps then
            y = drawRow(panel, {
                left = valueLabel(model.weaponDps, "Damage per Second"), right = "",
            }, y, styles.dps, { .93, .87, .75 }) + 2
        end
        if model.weaponDamage or #model.weaponBonus > 0 then
            if model.weaponDamage then
                y = y + styledAt(panel, weaponText(model), pad() + 7, y, inner - 7, styles.damage,
                    { .71, .72, .73 })
            end
            for _, bonus in ipairs(model.weaponBonus) do
                y = y + 2 + styledAt(panel, damageText(bonus), pad() + 7, y + 2, inner - 7, styles.damage,
                    { .71, .72, .73 })
            end
            y = y + 7
        end
        for _, row in ipairs(model.armor) do
            y = drawRow(panel, {
                left = row.value and valueLabel(row.value, "Armor") or row.left,
                right = row.right, rightColor = row.rightColor,
            }, y, styles.armor, { .93, .87, .75 })
        end
        if #model.armor > 0 then y = y + 5 end
        y = drawGroup(panel, model.primary, y, styles.stats, { .90, .85, .74 })
        -- The rest of the stats sit under a divider, whatever comes above them:
        -- a wand often has its damage and no primary stats.
        local above = #model.primary > 0 or #model.armor > 0 or model.weaponDps or model.weaponDamage
            or #model.weaponBonus > 0
        if (#model.secondary > 0 or #model.equipEffects > 0) and above then
            y = divider(panel, y, GOLD_RULE, 3)
        end
        y = drawGroup(panel, model.secondary, y, styles.stats, { .90, .85, .74 })
        y = drawMarked(panel, model.equipEffects, y, styles.equipEffects, EQUIP_EFFECT_COLOR, STAT_MARKER, true)
        y = drawMarked(panel, model.enchants, y, styles.enchants, { .90, .85, .74 }, ENCHANT_MARKER)
        if #model.effects > 0 then y = y + 5 end
        y = drawEffects(panel, model.effects, y, styles.effects, { .48, .88, .48 })
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
        local titleHeight = styledAt(panel, setTitle, pad(), y, inner - countWidth - 3,
            styles.setName, { 1, .76, .18 })
        local countHeight = styledAt(panel, count, panel.width - pad() - countWidth, y, countWidth,
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
    return y, sectioned
end

-- The item a recipe crafts: a small header, then its own stats and effects.
local function drawCreated(panel, created, styles, y, inner)
    local quality = QUALITY[created.quality] or created.nameColor or QUALITY[1]
    local indent = 0
    local top = y
    if created.icon then
        local border = acquireTexture(panel, nil, 0)
        border:SetPoint("TOPLEFT", panel, "TOPLEFT", pad(), -y)
        border:SetSize(CREATED_ICON + 2, CREATED_ICON + 2)
        border:SetVertexColor(quality[1] * .8, quality[2] * .8, quality[3] * .8, 1)
        local icon = acquireTexture(panel, created.icon, 1)
        icon:SetPoint("TOPLEFT", border, "TOPLEFT", 1, -1)
        icon:SetSize(CREATED_ICON, CREATED_ICON)
        icon:SetTexCoord(.08, .92, .08, .92)
        indent = CREATED_ICON + 10
    end
    y = y + styledAt(panel, created.name, pad() + indent, y, inner - indent, styles.createdName, quality) + 2
    local subtitle = createdSubtitle(created)
    if subtitle then
        local unmet = created.levelRequirement and not created.levelRequirement.met
        y = y + styledAt(panel, subtitle, pad() + indent, y, inner - indent, styles.subtitle,
            unmet and UNUSABLE_COLOR or { quality[1] * .5 + .5, quality[2] * .5 + .5, quality[3] * .5 + .5 }) + 2
    end
    y = math.max(y, top + CREATED_ICON + 2) + 8
    return (drawBody(panel, created, styles, y, inner, true))
end

local function render(panel, tooltip, model)
    panel:Show()
    clearPool(panel)
    local styles = {}
    for _, element in ipairs(ns.ELEMENTS) do
        if not element.tooltipType or element.tooltipType == "shared" then
            styles[element.key] = styleOf(element.key)
        end
    end
    if not ns.option("iconItems") then model.icon = nil end
    local title = model.name
    local badge = model.icon and ns.option("itemLevelBadge") and model.level
        and (model.equippable or model.levelLine) and ("iLvl " .. model.level)
    local iconSize = itemIconSize(panel, badge, styles.badge)
    panel.width = fitWidth(panel, model, title, styles, iconSize)
    panel:SetWidth(panel.width)
    local quality = QUALITY[model.quality] or QUALITY[1]
    local tag
    if model.comparison then
        tag = isEquipped(model) and "EQUIPPED" or "EQUIPPED WITH"
    end
    local accent = model.quest and colors.quest or quality
    local headerMin = drawChrome(panel, tooltip, {
        tooltipType = "item",
        color = accent,
        tint = (model.quest or model.quality >= 2) and accent or nil,
        icon = model.icon,
        iconSize = iconSize,
        badge = badge,
        tag = tag,
    })

    local y = titleTop()
    local inner = panel.width - 2 * pad()
    local indent = model.icon and iconSize + 10 or 0
    local leftIndent, rightIndent = headerInsets(indent)
    y = y + styledAt(panel, title, pad() + leftIndent, y, inner - indent, styles.title, quality) + 4
    if model.slot and model.slot ~= "" then
        y = y + styledAt(panel, model.slot, pad() + leftIndent, y, inner - indent, styles.subtitle,
            { quality[1] * .5 + .5, quality[2] * .5 + .5, quality[3] * .5 + .5 }) + 4
    end
    y = drawGroup(panel, model.header, y, styles.header, { .78, .72, .63 }, leftIndent, nil,
        rightIndent)
    y = math.max(y + 6, headerMin)
    panel.header:SetHeight(y - panel.inset)

    local sectioned
    y, sectioned = drawBody(panel, model, styles, y, inner, false)
    if model.created then
        y = caption(panel, y + (sectioned and 6 or 0), "Creates", styles.caption)
        y = drawCreated(panel, model.created, styles, y, inner)
        sectioned = true
    end
    if model.reagents then
        y = caption(panel, y + 4, "Reagents", styles.caption)
        y = drawGroup(panel, reagentRows(model), y, styles.reagents, { .90, .85, .74 }, 0, 3)
        sectioned = true
    end

    if model.disenchant and ns.option("disenchant") then
        y = divider(panel, y, GOLD_RULE, sectioned and 8 or 0)
        sectioned = true
        y = drawRow(panel, disenchantHeading(model.disenchant), y, styles.disenchant, FLAVOR_GOLD, 0, 4)
        y = drawGroup(panel, disenchantRows(model.disenchant), y, styles.disenchant, { .88, .84, .76 }, 0, 2)
    end

    if #model.extras > 0 then
        if sectioned then
            y = rule(panel, y, { .50, .50, .54 }, 10)
        else
            y = y + 12
        end
        y = drawGroup(panel, model.extras, y, styles.extras, EXTRA_COLOR, 0, 2)
    end

    local footerRight = shownFooterRight(model)
    if #model.footerLeft > 0 or #footerRight > 0 then
        y = y + 9
        local footerStart = y
        local footer = styles.footer
        local rows = math.max(#model.footerLeft, #footerRight)
        for index = 1, rows do
            local left = model.footerLeft[index]
            local right = footerRight[index]
            local h1, h2 = 0, 0
            local rightWidth = 0
            if right then
                local content = footerText(right)
                local color = { .88, .78, .60 }
                if right.requirement then
                    color = right.met and { 1, 1, 1 } or { 1, .34, .28 }
                end
                rightWidth = math.min(measureStyled(panel, content, footer) + 2, inner * .6)
                h2 = styledAt(panel, content, panel.width - pad() - rightWidth, y,
                    rightWidth, footer, color, "RIGHT")
            end
            if left and left.durability then
                h1 = drawDurability(panel, left.durability, y, footer)
            elseif left then
                h1 = styledAt(panel, left.left, pad(), y, inner - rightWidth - COLUMN_GAP,
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

ns.TooltipTypes[ITEM] = { read = readModel, render = render, key = getItemInfo, option = "itemPanels", lite = "itemLite" }
