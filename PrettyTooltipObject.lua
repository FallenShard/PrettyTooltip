-- World objects (herbs, ore, chests, quest objects) as a panel: the name, the
-- skill a node needs, what it yields and is worth, and its quest lines.
local _, ns = ...
local ui = ns.ui
local OBJECT = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object
if not (ui and OBJECT) then
    return
end

local isSecret = ui.isSecret
local LINE = Enum.TooltipDataLineType or {}
local PAD = ui.PAD
local ICON_SIZE = 38
local TEXT_INDENT = ICON_SIZE + 10
local TINT_STRENGTH = .7
local NEUTRAL = { .62, .66, .74 }
local TITLE_COLOR = { .96, .92, .84 }
local DETAIL_COLOR = { .82, .78, .71 }
local MUTED = { .60, .57, .52 }
local UNMET_COLOR = { 1, .34, .28 }
local QUEST_GOLD = { 1, .82, 0 }
local OBJECTIVE_COLOR = { .90, .85, .74 }
local DONE_COLOR = { .45, .80, .40 }
local PRICE_LABEL = { .88, .78, .60 }
local PARTS = { "objectTitle", "objectKind", "objectDetails", "objectQuests", "objectPrices",
    "extras" }

local SKILLS = {
    Herbalism = { label = "Herb", color = { .36, .78, .32 }, icon = "Interface\\Icons\\Trade_Herbalism" },
    Mining = { label = "Mining node", color = { .85, .55, .30 }, icon = "Interface\\Icons\\Trade_Mining" },
    Lockpicking = { label = "Locked", color = { .85, .72, .35 }, icon = "Interface\\Icons\\INV_Misc_Key_03" },
    Fishing = { label = "Fishing pool", color = { .35, .65, .95 }, icon = "Interface\\Icons\\Trade_Fishing" },
}
local QUEST = { label = "Quest object", color = QUEST_GOLD, icon = "Interface\\Icons\\INV_Misc_Note_01" }

-- No API links a node to what it yields or the skill it needs. Item IDs are
-- checked against the item's name, so a wrong entry is skipped, not shown.
local NODES = {
    ["Peacebloom"] = { 2447, 1 }, ["Silverleaf"] = { 765, 1 }, ["Earthroot"] = { 2449, 15 },
    ["Mageroyal"] = { 785, 50 }, ["Briarthorn"] = { 2450, 70 }, ["Stranglekelp"] = { 3820, 85 },
    ["Bruiseweed"] = { 2453, 100 }, ["Wild Steelbloom"] = { 3355, 115 },
    ["Grave Moss"] = { 3369, 120 }, ["Kingsblood"] = { 3356, 125 }, ["Liferoot"] = { 3357, 150 },
    ["Fadeleaf"] = { 3818, 160 }, ["Goldthorn"] = { 3821, 170 },
    ["Khadgar's Whisker"] = { 3358, 185 }, ["Wintersbite"] = { 3819, 195 },
    ["Firebloom"] = { 4625, 205 }, ["Purple Lotus"] = { 8831, 210 },
    ["Arthas' Tears"] = { 8836, 220 }, ["Sungrass"] = { 8838, 230 }, ["Blindweed"] = { 8839, 235 },
    ["Ghost Mushroom"] = { 8845, 245 }, ["Gromsblood"] = { 8846, 250 },
    ["Golden Sansam"] = { 13464, 260 }, ["Dreamfoil"] = { 13463, 270 },
    ["Mountain Silversage"] = { 13465, 280 }, ["Plaguebloom"] = { 13466, 285 },
    ["Icecap"] = { 13467, 290 }, ["Black Lotus"] = { 13468, 300 },
    ["Copper Vein"] = { 2770, 1 }, ["Tin Vein"] = { 2771, 65 },
    ["Incendicite Mineral Vein"] = { 3340, 65 }, ["Silver Vein"] = { 2775, 75 },
    ["Lesser Bloodstone Deposit"] = { 4278, 75 }, ["Iron Deposit"] = { 2772, 125 },
    ["Indurium Mineral Vein"] = { 5833, 150 }, ["Gold Vein"] = { 2776, 155 },
    ["Mithril Deposit"] = { 3858, 175 }, ["Truesilver Deposit"] = { 7911, 230 },
    ["Dark Iron Deposit"] = { 11370, 230 }, ["Small Thorium Vein"] = { 10620, 245 },
    ["Rich Thorium Vein"] = { 10620, 275 },
}

local function trim(text)
    return text:match("^%s*(.-)%s*$")
end

local function rgbOf(color)
    if isSecret(color) or type(color) ~= "table" then return end
    local r, g, b = color.r, color.g, color.b
    if isSecret(r) or isSecret(g) or isSecret(b) or type(r) ~= "number" then return end
    return { r, g, b }
end

-- Older clients list skills; newer ones, like Forever's, only list professions.
local function playerSkill(name)
    if GetNumSkillLines and GetSkillLineInfo then
        for index = 1, GetNumSkillLines() do
            local skillName, isHeader, _, rank = GetSkillLineInfo(index)
            if not isHeader and skillName == name and type(rank) == "number" then return rank end
        end
    end
    if GetProfessions and GetProfessionInfo then
        for _, index in pairs({ GetProfessions() }) do
            local skillName, _, rank = GetProfessionInfo(index)
            if skillName == name and type(rank) == "number" then return rank end
        end
    end
end

local function itemInfo(itemID)
    local _, name, icon, price
    if C_Item and C_Item.GetItemInfo then
        name, _, _, _, _, _, _, _, _, _, price = C_Item.GetItemInfo(itemID)
        if not name and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    end
    if C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(itemID) end
    return name, icon, price
end

local function auctionPrice(itemID)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not (api and api.GetAuctionPriceByItemID) then return end
    local ok, price = pcall(api.GetAuctionPriceByItemID, "PrettyTooltip", itemID)
    if ok and type(price) == "number" and price > 0 then return price end
end

-- Fills in what the tooltip lines cannot say: the node's skill level, the
-- player's own, the item it yields, and that item's prices.
local function completeModel(model)
    local node = NODES[(model.name:gsub("^Ooze Covered ", ""))]
    model.look = model.skill and SKILLS[model.skill] or (#model.quests > 0 and QUEST) or nil
    if model.skill and SKILLS[model.skill] and model.skill ~= "Lockpicking" then
        model.skillRow = {
            name = model.skill,
            level = node and node[2],
            player = playerSkill(model.skill),
        }
    end
    if node then
        local name, icon, price = itemInfo(node[1])
        -- A herb yields itself and a node yields an ore; anything else is a bad entry.
        local herb = model.name:gsub("^Ooze Covered ", "")
        if name and name ~= herb and not name:find(" Ore$") then node = nil end
    end
    if node then
        local name, icon, price = itemInfo(node[1])
        model.itemName, model.icon = name, icon
        model.prices = {}
        if type(price) == "number" and price > 0 then
            model.prices[#model.prices + 1] = { "Sell Price", ui.formatMoney(price) }
        end
        local auction = auctionPrice(node[1])
        if auction then model.prices[#model.prices + 1] = { "Auction", ui.formatMoney(auction) } end
    end
    model.prices = model.prices or {}
    return model
end

local function objectKey(_, data)
    if isSecret(data.lines) or type(data.lines) ~= "table" then return end
    local line = data.lines[1]
    if isSecret(line) or type(line) ~= "table" then return end
    return ui.safeText(line.leftText)
end

local function readObject(tooltip, data)
    local safeText = ui.safeText
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local model = { details = {}, quests = {}, extras = {}, lineIndices = {} }
    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.type) or isSecret(line.lineIndex) then return end
        if line.lineIndex then
            local left, right = safeText(line.leftText), safeText(line.rightText)
            if not left or not right then return end
            model.lineIndices[line.lineIndex] = true
            local text = trim(left)
            if not model.name then
                model.name = text
            elseif text ~= "" or right ~= "" then
                if text:match("^Requires ") then
                    ui.add(model.details, left, right)
                    local row = model.details[#model.details]
                    row.requirement, row.met = true, ui.requirementMet(text, line.leftColor)
                    for skill in pairs(SKILLS) do
                        if not model.skill and text:find(skill, 1, true) then
                            model.skill, model.skillMet = skill, row.met
                        end
                    end
                elseif SKILLS[text] then
                    -- Colored by how likely gathering is to raise the skill.
                    model.skill = model.skill or text
                    model.skillColor = rgbOf(line.leftColor)
                elseif text == "Locked" then
                    model.skill = model.skill or "Lockpicking"
                    ui.add(model.details, left, right)
                elseif LINE.QuestTitle and line.type == LINE.QuestTitle then
                    ui.add(model.quests, left, right)
                    model.quests[#model.quests].title = true
                elseif LINE.QuestObjective and line.type == LINE.QuestObjective then
                    ui.add(model.quests, left, right)
                    if not isSecret(line.completed) then
                        model.quests[#model.quests].completed = line.completed == true
                    end
                else
                    ui.add(model.extras, left, right)
                    local row = model.extras[#model.extras]
                    row.color, row.rightColor = ui.colorOf(line.leftColor), ui.colorOf(line.rightColor)
                end
            end
        end
    end
    if not model.name or model.name == "" then return end
    local appended = ui.appendedRows(tooltip, model.lineIndices)
    if not appended then return end
    for _, row in ipairs(appended) do
        if trim(row.left) ~= "" or row.right ~= "" then model.extras[#model.extras + 1] = row end
    end
    return completeModel(model)
end

local function skillText(skill)
    return "Requires " .. (skill.level and (skill.name .. " " .. skill.level) or skill.name)
end

local function fitWidth(panel, model, styles)
    local indent = (model.icon or model.look) and TEXT_INDENT or 0
    local need = ui.measureStyled(panel, model.name, styles.objectTitle) + indent
    local function consider(width) if width > need then need = width end end
    if model.look then consider(ui.measureStyled(panel, model.look.label, styles.objectKind) + indent) end
    if model.skillRow then
        consider(ui.rowWidth(panel, {
            left = skillText(model.skillRow),
            right = model.skillRow.player and ("Your skill " .. model.skillRow.player) or "",
        }, styles.objectDetails))
    end
    for _, row in ipairs(model.details) do consider(ui.rowWidth(panel, row, styles.objectDetails)) end
    for _, row in ipairs(model.quests) do
        consider(ui.rowWidth(panel, row, styles.objectQuests) + (row.title and 0 or 8))
    end
    for _, row in ipairs(model.extras) do
        local width = ui.rowWidth(panel, row, styles.extras)
        if not row.right or row.right == "" then width = math.min(width, ui.PROSE_WIDTH) end
        consider(width)
    end
    for _, price in ipairs(model.prices) do
        consider(ui.rowWidth(panel, { left = price[1], right = price[2] }, styles.objectPrices))
    end
    return math.max(ui.MIN_WIDTH, math.min(ui.MAX_WIDTH, math.ceil(need + 2 * PAD)))
end

local function renderObject(panel, tooltip, model)
    panel:Show()
    ui.clearPool(panel)
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    local look = model.look
    panel.width = fitWidth(panel, model, styles)
    panel:SetWidth(panel.width)
    local color = look and look.color or NEUTRAL
    local icon = model.icon or (look and look.icon)
    local headerMin = ui.drawChrome(panel, tooltip, {
        color = color,
        tint = look and look.color,
        strength = TINT_STRENGTH,
        icon = icon,
        iconSize = ICON_SIZE,
    })

    local inner = panel.width - 2 * PAD
    local indent = icon and TEXT_INDENT or 0
    local leftIndent = ui.headerInsets(indent)
    local y = ui.TITLE_TOP
    y = y + ui.styledAt(panel, model.name, PAD + leftIndent, y, inner - indent, styles.objectTitle,
        TITLE_COLOR) + 4
    if look then
        y = y + ui.styledAt(panel, look.label, PAD + leftIndent, y, inner - indent, styles.objectKind,
            { color[1] * .5 + .5, color[2] * .5 + .5, color[3] * .5 + .5 }) + 4
    end
    y = math.max(y + 6, headerMin)
    panel.header:SetHeight(y - panel.inset)

    local sectioned = false
    if model.skillRow or #model.details > 0 then
        y = ui.divider(panel, y, ui.GOLD_RULE)
        local skill = model.skillRow
        if skill then
            local skillColor = model.skillMet == false and UNMET_COLOR or model.skillColor or DETAIL_COLOR
            y = ui.drawRow(panel, {
                left = skillText(skill),
                right = skill.player and ("Your skill " .. skill.player) or "",
                rightColor = MUTED,
            }, y, styles.objectDetails, skillColor, 0, 2)
        end
        for _, row in ipairs(model.details) do
            -- The skill row already says what this requirement says.
            if not (skill and row.requirement and row.left:find(skill.name, 1, true)) then
                local rowColor = DETAIL_COLOR
                if row.requirement then rowColor = row.met and { 1, 1, 1 } or UNMET_COLOR end
                y = ui.drawRow(panel, row, y, styles.objectDetails, rowColor, 0, 2)
            end
        end
        sectioned = true
    end
    if #model.quests > 0 then
        y = ui.divider(panel, y, ui.GOLD_RULE, sectioned and 6 or 0)
        for _, row in ipairs(model.quests) do
            if row.title then
                y = ui.drawRow(panel, row, y, styles.objectQuests, QUEST_GOLD, 0, 2)
            else
                y = ui.drawRow(panel, row, y, styles.objectQuests,
                    row.completed and DONE_COLOR or OBJECTIVE_COLOR, 8, 2)
            end
        end
        sectioned = true
    end
    if #model.extras > 0 then
        if sectioned then
            y = ui.rule(panel, y, { .50, .50, .54 }, 8)
        else
            y = y + 4
        end
        y = ui.drawGroup(panel, model.extras, y, styles.extras, ui.EXTRA_COLOR, 0, 2)
    end
    if #model.prices > 0 then
        y = y + 9
        local footerStart = y
        for _, price in ipairs(model.prices) do
            y = ui.drawRow(panel, { left = price[1], right = price[2] }, y, styles.objectPrices,
                PRICE_LABEL, 0, 4)
        end
        panel.footer:SetHeight(y - footerStart + 23)
    else
        panel.footer:SetHeight(0)
    end
    ui.finishPanel(panel, tooltip, y)
end

ui.objectModel = completeModel
ui.registerKind(OBJECT, {
    read = readObject, render = renderObject, key = objectKey, option = "objectPanels",
})
