-- Players and NPCs as a panel.
local _, ns = ...
local ui = ns.ui
local UNIT = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit
if not (ui and UNIT and ui.drawPills) then
    return
end

local isSecret, safeText = ui.isSecret, ui.safeText
local LINE = Enum.TooltipDataLineType or {}
local PAD = ui.PAD
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ICON_SIZE = 38
local TEXT_INDENT = ICON_SIZE + 10
local TINT_STRENGTH = .7
local BAR_HEIGHT = 5
local NEUTRAL = { .62, .66, .74 }
local TAPPED = { .55, .55, .55 }
local DETAIL_COLOR = { .82, .78, .71 }
local MUTED = { .60, .57, .52 }
local UNMET_COLOR = { 1, .34, .28 }
local QUEST_GOLD = { 1, .82, 0 }
local OBJECTIVE_COLOR = { .90, .85, .74 }
local DONE_COLOR = { .45, .80, .40 }
local REACTION = {
    { 1, .27, .22 }, { 1, .27, .22 }, { 1, .50, .20 }, { 1, .82, .20 },
    { .30, .85, .35 }, { .30, .85, .35 }, { .30, .85, .35 }, { .30, .85, .35 },
}
local BADGES = {
    elite = { "Elite", { .95, .78, .30 } },
    rareelite = { "Rare Elite", { .70, .80, .95 } },
    rare = { "Rare", { .70, .80, .95 } },
    worldboss = { "Boss", { 1, .35, .25 } },
}
local WATERMARK_SIZE = 200
local WATERMARK_ALPHA = .12
-- How far the crest runs off the panel's right and top edges, as parts of its size.
local WATERMARK_BLEED_RIGHT, WATERMARK_BLEED_TOP = .22, .12
local ART = "Interface\\AddOns\\PrettyTooltip\\art\\"
-- White silhouettes, tinted here.
local FACTION_ART = {
    Alliance = { "faction-alliance", { .40, .60, 1 } },
    Horde = { "faction-horde", { .90, .25, .20 } },
}
local PARTS = { "unitName", "unitInfo", "unitBadges", "unitGuild", "unitHealth", "unitDetails",
    "unitQuests", "extras" }

local function trim(text)
    return text:match("^%s*(.-)%s*$")
end

local function get(fn, ...)
    if not fn then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok or isSecret(a) or isSecret(b) or isSecret(c) or isSecret(d) then return end
    return a, b, c, d
end

-- The mouseover token can still be the previous unit; the data's GUID cannot.
local function unitFor(tooltip, guid)
    if isSecret(guid) then guid = nil end
    local _, unit = get(tooltip.GetUnit, tooltip)
    if type(unit) == "string" and get(UnitExists, unit) and (not guid or get(UnitGUID, unit) == guid) then
        return unit
    end
    if guid and UnitTokenFromGUID then
        unit = get(UnitTokenFromGUID, guid)
        if type(unit) == "string" and get(UnitExists, unit) then return unit end
    end
    if guid and get(UnitExists, "mouseover") and get(UnitGUID, "mouseover") == guid then
        return "mouseover"
    end
end

local function hexOf(color)
    return string.format("%02X%02X%02X", math.floor(color[1] * 255 + .5),
        math.floor(color[2] * 255 + .5), math.floor(color[3] * 255 + .5))
end

local function classColor(classFile)
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color then return { color.r, color.g, color.b } end
end

local function unitColor(unit)
    if get(UnitIsPlayer, unit) then
        local _, classFile = get(UnitClass, unit)
        return classColor(classFile)
    end
    local reaction = get(UnitReaction, unit, "player")
    return reaction and REACTION[reaction]
end

local function levelColor(level)
    if level == -1 then return UNMET_COLOR end
    if type(level) ~= "number" or not GetQuestDifficultyColor then return end
    local color = get(GetQuestDifficultyColor, level)
    if type(color) == "table" and color.r then return { color.r, color.g, color.b } end
end

local function healthColor(current, maximum)
    local ratio = maximum > 0 and current / maximum or 0
    if ratio < .25 then return { 1, .34, .28 } end
    if ratio < .5 then return { .95, .76, .30 } end
    return { .45, .80, .40 }
end

local function number(value)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(value) end
    return tostring(value)
end

local function completeModel(model, unit)
    if unit then
        model.isPlayer = get(UnitIsPlayer, unit)
        model.level = get(UnitEffectiveLevel or UnitLevel, unit)
        if model.isPlayer then
            model.className, model.classFile = get(UnitClass, unit)
            model.race = get(UnitRace, unit)
            model.guild, model.guildRank = get(GetGuildInfo, unit)
            model.faction = get(UnitFactionGroup, unit)
            model.afk, model.dnd = get(UnitIsAFK, unit), get(UnitIsDND, unit)
        else
            model.creature = get(UnitCreatureType, unit)
            model.classification = get(UnitClassification, unit)
        end
        model.pvp = get(UnitIsPVP, unit)
        model.dead = get(UnitIsDeadOrGhost, unit)
        model.reaction = get(UnitReaction, unit, "player")
        model.tapped = get(UnitIsTapDenied, unit)
        model.health, model.healthMax = get(UnitHealth, unit), get(UnitHealthMax, unit)
        local target = unit .. "target"
        if get(UnitExists, target) then
            model.target = get(UnitName, target)
            model.targetIsYou = get(UnitIsUnit, target, "player")
            model.targetColor = unitColor(target)
        end
    end
    -- Forever puts the guild, unbracketed, and the class on lines of their own;
    -- the header already shows them.
    local shown = {}
    for _, value in ipairs({ model.guild or false, model.className or false, model.race or false,
        model.creature or false }) do
        if value then shown[value] = true end
    end
    for index = #model.extras, 1, -1 do
        local row = model.extras[index]
        if (row.right or "") == "" and shown[(trim(row.left):gsub("^<(.*)>$", "%1"))] then
            table.remove(model.extras, index)
        end
    end
    if model.isPlayer then
        model.color = classColor(model.classFile)
    elseif model.tapped then
        model.color = TAPPED
    else
        model.color = model.reaction and REACTION[model.reaction]
    end
    return model
end

local function unitKey(_, data)
    if isSecret(data.guid) then return end
    return data.guid
end

local function readUnit(tooltip, data)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local unit = unitFor(tooltip, data.guid)
    local model = { quests = {}, extras = {}, lineIndices = {}, unit = unit }
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
                if text:match("^Level ") then
                    model.levelLine = text:gsub("%s*%(Player%)$", "")
                elseif text:match("^<.+>$") and not model.tag then
                    model.tag = text
                elseif text == "Alliance" or text == "Horde" or text == "PvP" or text == "Dead"
                    or text == "Corpse" then
                    -- Shown as badges.
                elseif LINE.UnitOwner and line.type == LINE.UnitOwner then
                    model.owner = text
                elseif LINE.QuestTitle and line.type == LINE.QuestTitle then
                    ui.add(model.quests, left, right)
                    model.quests[#model.quests].title = true
                elseif (LINE.QuestObjective and line.type == LINE.QuestObjective)
                    or (LINE.QuestPlayer and line.type == LINE.QuestPlayer) then
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
    return completeModel(model, unit)
end

local function infoText(model)
    local level = model.level
    if not level then return model.levelLine end
    local levelText = level == -1 and "??" or tostring(level)
    local color = levelColor(level)
    if color then levelText = "|cff" .. hexOf(color) .. levelText .. "|r" end
    local what = model.isPlayer and table.concat({ model.race or "", model.className or "" }, " ")
        or (model.creature or "")
    return trim("Level " .. levelText .. " " .. what)
end

local function badges(model)
    local list = {}
    local classification = model.classification and BADGES[model.classification]
    if classification then list[#list + 1] = classification end
    if model.pvp then list[#list + 1] = { "PvP", { 1, .45, .35 } } end
    if model.afk then list[#list + 1] = { "AFK", MUTED } end
    if model.dnd then list[#list + 1] = { "DND", MUTED } end
    if model.dead then list[#list + 1] = { "Dead", TAPPED } end
    return list
end

local function guildText(model)
    if model.guild then return "<" .. model.guild .. ">" end
    return model.tag
end

local function detailRows(model)
    local rows = {}
    if model.owner then rows[#rows + 1] = { left = model.owner, right = "" } end
    if model.target then
        rows[#rows + 1] = model.targetIsYou
            and { left = "Target", right = "You", rightColor = UNMET_COLOR }
            or { left = "Target", right = model.target, rightColor = model.targetColor }
    end
    return rows
end

local function healthRow(model)
    local current, maximum = model.health, model.healthMax
    if type(current) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then return end
    return {
        left = number(current) .. " / " .. number(maximum),
        right = math.floor(current / maximum * 100 + .5) .. "%",
    }
end

local function fitWidth(panel, model, styles)
    local indent = not model.hideIcon and (model.unit or model.iconPath) and TEXT_INDENT or 0
    local need = ui.measureStyled(panel, model.name, styles.unitName) + indent
    local function consider(width) if width > need then need = width end end
    local guild, info = guildText(model), infoText(model)
    if guild then consider(ui.measureStyled(panel, guild, styles.unitGuild) + indent) end
    if info then consider(ui.measureStyled(panel, info, styles.unitInfo) + indent) end
    local list = badges(model)
    if #list > 0 then consider(ui.pillsWidth(panel, list, styles.unitBadges) + indent) end
    local health = healthRow(model)
    if health then consider(ui.rowWidth(panel, health, styles.unitHealth)) end
    for _, row in ipairs(detailRows(model)) do consider(ui.rowWidth(panel, row, styles.unitDetails)) end
    for _, row in ipairs(model.quests) do
        consider(ui.rowWidth(panel, row, styles.unitQuests) + (row.title and 0 or 8))
    end
    for _, row in ipairs(model.extras) do
        local width = ui.rowWidth(panel, row, styles.extras)
        if not row.right or row.right == "" then width = math.min(width, ui.PROSE_WIDTH) end
        consider(width)
    end
    return math.max(ui.MIN_WIDTH, math.min(ui.MAX_WIDTH, math.ceil(need + 2 * PAD)))
end

local live = setmetatable({}, { __mode = "k" })

local function drawHealthFill(view, current, maximum)
    local ratio = maximum > 0 and math.max(0, math.min(1, current / maximum)) or 0
    local color = healthColor(current, maximum)
    view.fill:SetWidth(math.max(1, view.width * ratio))
    view.fill:SetVertexColor(color[1], color[2], color[3], 1)
    view.fill:SetShown(ratio > 0)
end

local updater = CreateFrame("Frame")
local elapsedSince = 0
updater:SetScript("OnUpdate", function(_, elapsed)
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < .1 then return end
    elapsedSince = 0
    for panel, view in pairs(live) do
        if panel:IsShown() then
            local current, maximum = get(UnitHealth, view.unit), get(UnitHealthMax, view.unit)
            if type(current) == "number" and type(maximum) == "number" and maximum > 0
                and (current ~= view.current or maximum ~= view.maximum) then
                view.current, view.maximum = current, maximum
                drawHealthFill(view, current, maximum)
                view.left:SetText(number(current) .. " / " .. number(maximum))
                view.right:SetText(math.floor(current / maximum * 100 + .5) .. "%")
            end
        else
            live[panel] = nil
        end
    end
end)

-- The crest runs off the top right; a panel cannot clip what it draws, so only
-- the part over the panel is drawn, cut from the texture.
local function showWatermark(panel, faction)
    local mark = panel.watermark
    if not mark then
        mark = panel:CreateTexture(nil, "BORDER", nil, 3)
        panel.watermark = mark
    end
    local size, inset = WATERMARK_SIZE, panel.inset or 1
    local width, height = panel:GetWidth(), panel:GetHeight()
    local left, top = width - size * (1 - WATERMARK_BLEED_RIGHT), -size * WATERMARK_BLEED_TOP
    local x0, x1 = math.max(left, inset), math.min(left + size, width - inset)
    local y0, y1 = math.max(top, inset), math.min(top + size, height - inset)
    if x1 <= x0 or y1 <= y0 then
        mark:Hide()
        return
    end
    local art = FACTION_ART[faction]
    mark:SetTexture(ART .. art[1])
    mark:SetTexCoord((x0 - left) / size, (x1 - left) / size, (y0 - top) / size, (y1 - top) / size)
    mark:ClearAllPoints()
    mark:SetPoint("TOPLEFT", panel, "TOPLEFT", x0, -y0)
    mark:SetSize(x1 - x0, y1 - y0)
    mark:SetVertexColor(art[2][1], art[2][2], art[2][3], WATERMARK_ALPHA)
    mark:Show()
end

local function renderUnit(panel, tooltip, model)
    panel:Show()
    ui.clearPool(panel)
    live[panel] = nil
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    model.hideIcon = not ns.option("iconUnits")
    panel.width = fitWidth(panel, model, styles)
    panel:SetWidth(panel.width)
    local color = model.color or NEUTRAL
    local hasIcon = not model.hideIcon and (model.unit or model.iconPath)
    local headerMin = ui.drawChrome(panel, tooltip, {
        kind = "unit",
        color = color,
        tint = model.color,
        strength = TINT_STRENGTH,
        icon = hasIcon and (model.iconPath or WHITE),
        iconSize = ICON_SIZE,
    })
    if hasIcon and model.unit and SetPortraitTexture then pcall(SetPortraitTexture, panel.icon, model.unit) end

    local inner = panel.width - 2 * PAD
    local indent = hasIcon and TEXT_INDENT or 0
    local leftIndent = ui.headerInsets(indent)
    local y = ui.TITLE_TOP
    y = y + ui.styledAt(panel, model.name, PAD + leftIndent, y, inner - indent, styles.unitName,
        color) + 2
    local guild = guildText(model)
    if guild then
        y = y + ui.styledAt(panel, guild, PAD + leftIndent, y, inner - indent, styles.unitGuild,
            { color[1] * .5 + .5, color[2] * .5 + .5, color[3] * .5 + .5 }) + 2
    end
    local info = infoText(model)
    if info then
        y = y + ui.styledAt(panel, info, PAD + leftIndent, y, inner - indent, styles.unitInfo,
            DETAIL_COLOR) + 4
    end
    local list = badges(model)
    if #list > 0 then y = ui.drawPills(panel, list, PAD + leftIndent, y + 1, styles.unitBadges) + 4 end
    y = math.max(y + 6, headerMin)
    panel.header:SetHeight(y - panel.inset)
    panel.footer:SetHeight(0)

    local sectioned = false
    local health, details = healthRow(model), detailRows(model)
    if health or #details > 0 then
        y = ui.divider(panel, y, ui.GOLD_RULE)
        if health then
            local barWidth = inner
            y = ui.drawRow(panel, health, y, styles.unitHealth, DETAIL_COLOR, 0, 2)
            local view = {
                unit = model.unit, width = barWidth,
                current = model.health, maximum = model.healthMax,
                -- The row's two halves, the last two strings drawn.
                left = panel.pool[panel.used - 1], right = panel.pool[panel.used],
            }
            local track = ui.acquireTexture(panel, nil, 0)
            track:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
            track:SetSize(barWidth, BAR_HEIGHT)
            track:SetVertexColor(.16, .14, .13, 1)
            view.fill = ui.acquireTexture(panel, nil, 1)
            view.fill:SetPoint("TOPLEFT", track, "TOPLEFT")
            view.fill:SetHeight(BAR_HEIGHT)
            drawHealthFill(view, model.health, model.healthMax)
            y = y + BAR_HEIGHT + 8
            if model.unit then live[panel] = view end
        end
        y = ui.drawGroup(panel, details, y, styles.unitDetails, DETAIL_COLOR, 0, 2)
        sectioned = true
    end
    if #model.quests > 0 then
        y = ui.divider(panel, y, ui.GOLD_RULE, sectioned and 6 or 0)
        for _, row in ipairs(model.quests) do
            if row.title then
                y = ui.drawRow(panel, row, y, styles.unitQuests, QUEST_GOLD, 0, 2)
            else
                y = ui.drawRow(panel, row, y, styles.unitQuests,
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
    ui.finishPanel(panel, tooltip, y)
    if model.isPlayer and (model.faction == "Alliance" or model.faction == "Horde") then
        showWatermark(panel, model.faction)
    end
end

ui.unitModel = function(fields)
    for _, list in ipairs({ "quests", "extras" }) do fields[list] = fields[list] or {} end
    return completeModel(fields)
end
ui.registerKind(UNIT, { read = readUnit, render = renderUnit, key = unitKey, option = "unitPanels" })
