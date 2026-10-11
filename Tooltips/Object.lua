-- World objects (herbs, ore, chests, quest objects) as a panel.
local _, ns = ...
local ui = ns.ui
local OBJECT = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object
if not (ui and OBJECT and ui.renderView) then
    return
end

local util = ns.util
local colors = ns.Palette.roles
local isSecret, trim = util.isSecret, util.trim
local LINE = Enum.TooltipDataLineType or {}
local ICON_SIZE = 38
local TINT_STRENGTH = .7
local DETAIL_COLOR = colors.detail
local UNMET_COLOR = colors.unmet
local QUEST_GOLD = colors.quest
local PRICE_LABEL = { .88, .78, .60 }
local EXTRAS_RULE = { .50, .50, .54 }
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

-- An ooze covered node yields what the plain one does.
local function nodeFor(name)
    return NODES[(name:gsub("^Ooze Covered ", ""))]
end

-- The item an object yields, by its name; for /ptip capture to record.
function ns.objectYield(name)
    local node = nodeFor(name)
    return node and node[1]
end

-- The yield's name, icon, and sell price; an unseen item is asked for, for a later hover.
local function itemInfo(itemID, game)
    local info = game.itemInfo(itemID) or {}
    if not info.name then game.loadItem(itemID) end
    return info.name, game.itemIcon(itemID), info.price
end

local function completeModel(model, game)
    local node = nodeFor(model.name)
    model.look = model.skill and SKILLS[model.skill] or (#model.quests > 0 and QUEST) or nil
    if model.skill and SKILLS[model.skill] and model.skill ~= "Lockpicking" then
        model.skillRow = {
            name = model.skill,
            level = node and node[2],
            player = game.skill(model.skill),
        }
    end
    if node then
        local name = itemInfo(node[1], game)
        -- A herb yields itself and a node yields an ore; anything else is a bad entry.
        local herb = model.name:gsub("^Ooze Covered ", "")
        if name and name ~= herb and not name:find(" Ore$") then node = nil end
    end
    if node then
        local name, icon, price = itemInfo(node[1], game)
        model.itemName, model.icon = name, icon
        model.prices = {}
        if type(price) == "number" and price > 0 then
            model.prices[#model.prices + 1] = { "Sell Price", ui.formatMoney(price) }
        end
        local auction = game.auctionPrice(node[1])
        if auction then model.prices[#model.prices + 1] = { "Auction", ui.formatMoney(auction) } end
    end
    model.prices = model.prices or {}
    return model
end

local function objectKey(_, data)
    if isSecret(data.lines) or type(data.lines) ~= "table" then return end
    local line = data.lines[1]
    if isSecret(line) or type(line) ~= "table" then return end
    return util.safeText(line.leftText)
end

local function readObject(tooltip, data, game)
    local safeText = util.safeText
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
                    row.requirement, row.met = true, ui.requirementMet(text, line.leftColor, game)
                    for skill in pairs(SKILLS) do
                        if not model.skill and text:find(skill, 1, true) then
                            model.skill, model.skillMet = skill, row.met
                        end
                    end
                elseif SKILLS[text] then
                    -- Colored by how likely gathering is to raise the skill.
                    model.skill = model.skill or text
                    model.skillColor = util.rgb(line.leftColor)
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
    return completeModel(model, game)
end

local function skillText(skill)
    return "Requires " .. (skill.level and (skill.name .. " " .. skill.level) or skill.name)
end

-- What the panel shows, for Panel/Render.lua to draw.
local function objectView(model)
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    local look = model.look
    local color = look and look.color or colors.neutral
    local sections = {}

    local skill = model.skillRow
    local details = {}
    if skill then
        details[1] = {
            left = skillText(skill),
            right = skill.player and ("Your skill " .. skill.player) or "",
            rightColor = colors.caption,
            color = model.skillMet == false and UNMET_COLOR or model.skillColor or DETAIL_COLOR,
        }
    end
    for _, row in ipairs(model.details) do
        -- The skill row already says what this requirement says.
        if not (skill and row.requirement and row.left:find(skill.name, 1, true)) then
            local rowColor = DETAIL_COLOR
            if row.requirement then rowColor = row.met and { 1, 1, 1 } or UNMET_COLOR end
            details[#details + 1] = { left = row.left, right = row.right, color = rowColor }
        end
    end
    if #details > 0 then
        sections[#sections + 1] = { separator = { divider = ui.GOLD_RULE }, kind = "rows", rows = details,
            style = styles.objectDetails, color = DETAIL_COLOR, gap = 2 }
    end
    if #model.quests > 0 then
        local quests = {}
        for index, row in ipairs(model.quests) do
            quests[index] = row.title and { left = row.left, right = row.right, color = QUEST_GOLD }
                or { left = row.left, right = row.right, color = row.completed and colors.done or colors.objective,
                    indent = 8 }
        end
        sections[#sections + 1] = { separator = { divider = ui.GOLD_RULE, before = #sections > 0 and 6 or 0 },
            kind = "rows", rows = quests, style = styles.objectQuests, gap = 2 }
    end
    if #model.extras > 0 then
        sections[#sections + 1] = { separator = #sections > 0 and { rule = EXTRAS_RULE, before = 8 } or { space = 4 },
            kind = "rows", rows = model.extras, style = styles.extras, color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    local prices = {}
    for index, price in ipairs(model.prices) do prices[index] = { left = price[1], right = price[2] } end

    local header = { { text = model.name, style = styles.objectTitle, color = colors.title, gap = 4 } }
    if look then
        header[2] = { text = look.label, style = styles.objectKind,
            color = { color[1] * .5 + .5, color[2] * .5 + .5, color[3] * .5 + .5 }, gap = 4 }
    end
    return {
        tooltipType = "object",
        color = color,
        tint = look and look.color,
        strength = TINT_STRENGTH,
        icon = ns.option("iconObjects") and (model.icon or (look and look.icon)) or nil,
        iconSize = ICON_SIZE,
        header = header,
        sections = sections,
        footer = { rows = prices, style = styles.objectPrices, color = PRICE_LABEL, gap = 4 },
    }
end

local function renderObject(panel, tooltip, model)
    ui.renderView(panel, tooltip, objectView(model))
end

ui.objectModel = function(fields) return completeModel(fields, ns.Game) end
ui.defineTooltipType(OBJECT, {
    read = readObject, render = renderObject, key = objectKey, option = "objectPanels",
})
