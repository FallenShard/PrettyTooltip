-- Players and NPCs as a panel.
local _, ns = ...
local ui = ns.ui
local UNIT = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit
if not (ui and UNIT and ui.renderView) then
    return
end

local util = ns.util
local colors = ns.Palette.roles
local isSecret, safeText, trim, hex = util.isSecret, util.safeText, util.trim, util.hex
local get = util.call
local LINE = Enum.TooltipDataLineType or {}
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ICON_SIZE = 38
local TINT_STRENGTH = .7
local BAR_HEIGHT = 5
local TAPPED = { .55, .55, .55 }
local DETAIL_COLOR = colors.detail
local MUTED = colors.caption
local EXTRAS_RULE = { .50, .50, .54 }
local UNMET_COLOR = colors.unmet
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

-- The mouseover token can still be the previous unit; the data's GUID cannot.
local function unitFor(tooltip, guid, game)
    if isSecret(guid) then guid = nil end
    local _, unit = get(tooltip.GetUnit, tooltip)
    if type(unit) == "string" and game.unitExists(unit) and (not guid or game.unitGUID(unit) == guid) then
        return unit
    end
    if guid then
        unit = game.unitToken(guid)
        if type(unit) == "string" and game.unitExists(unit) then return unit end
    end
    if guid and game.unitExists("mouseover") and game.unitGUID("mouseover") == guid then
        return "mouseover"
    end
end

local function unitColor(unit, game)
    if game.unitIsPlayer(unit) then
        local _, classFile = game.unitClass(unit)
        return game.classColor(classFile)
    end
    local reaction = game.unitReaction(unit, "player")
    return reaction and REACTION[reaction]
end

-- Asked while drawing, until Phase 5 moves it into the model.
local function levelColor(level)
    if level == -1 then return UNMET_COLOR end
    return ns.Game.difficultyColor(level)
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

local function completeModel(model, unit, game)
    if unit then
        model.isPlayer = game.unitIsPlayer(unit)
        model.level = game.unitLevel(unit)
        if model.isPlayer then
            model.className, model.classFile = game.unitClass(unit)
            model.race = game.unitRace(unit)
            model.guild, model.guildRank = game.unitGuild(unit)
            model.faction = game.unitFaction(unit)
            model.afk, model.dnd = game.unitIsAFK(unit), game.unitIsDND(unit)
        else
            model.creature = game.unitCreatureType(unit)
            model.classification = game.unitClassification(unit)
        end
        model.pvp = game.unitIsPVP(unit)
        model.dead = game.unitIsDead(unit)
        model.reaction = game.unitReaction(unit, "player")
        model.tapped = game.unitIsTapDenied(unit)
        model.health, model.healthMax = game.unitHealth(unit)
        local target = unit .. "target"
        if game.unitExists(target) then
            model.target = game.unitName(target)
            model.targetIsYou = game.unitIsUnit(target, "player")
            model.targetColor = unitColor(target, game)
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
        model.color = game.classColor(model.classFile)
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

local function readUnit(tooltip, data, game)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local unit = unitFor(tooltip, data.guid, game)
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
    return completeModel(model, unit, game)
end

-- The level on a plate under the portrait, as the game's target frame shows
-- it; nil without a portrait to put it under, or with the plate turned off,
-- and the info line shows it instead.
local function levelBadge(model, hasIcon)
    if not hasIcon or type(model.level) ~= "number" or not ns.option("unitLevelBadge") then return end
    return model.level == -1 and "??" or tostring(model.level)
end

local function infoText(model, plated)
    local what = model.isPlayer and table.concat({ model.race or "", model.className or "" }, " ")
        or (model.creature or "")
    if plated then
        what = trim(what)
        return what ~= "" and what or nil
    end
    local level = model.level
    if not level then return model.levelLine end
    local levelText = level == -1 and "??" or tostring(level)
    local color = levelColor(level)
    if color then levelText = "|cff" .. hex(color) .. levelText .. "|r" end
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

local function drawHealthFill(bar, current, maximum)
    local ratio = maximum > 0 and math.max(0, math.min(1, current / maximum)) or 0
    local color = healthColor(current, maximum)
    bar.fill:SetWidth(math.max(1, bar.width * ratio))
    bar.fill:SetVertexColor(color[1], color[2], color[3], 1)
    bar.fill:SetShown(ratio > 0)
end

-- The health row and a bar under it, red, then yellow, then green; both
-- follow the unit while the panel shows.
local function healthSection(model, row, style, separator)
    return {
        separator = separator,
        kind = "custom",
        measure = function(panel) return ui.rowWidth(panel, row, style) end,
        draw = function(panel, y)
            y = ui.drawRow(panel, row, y, style, DETAIL_COLOR, 0, 2)
            local bar = {
                width = panel.width - 2 * ui.PAD,
                current = model.health, maximum = model.healthMax,
                -- The row's two halves, the last two strings drawn.
                left = panel.pool[panel.used - 1], right = panel.pool[panel.used],
            }
            bar.fill = ui.drawTrack(panel, y, BAR_HEIGHT)
            drawHealthFill(bar, model.health, model.healthMax)
            if model.unit then
                ui.setLive(panel, function()
                    local current, maximum = ns.Game.unitHealth(model.unit)
                    if type(current) == "number" and type(maximum) == "number" and maximum > 0
                        and (current ~= bar.current or maximum ~= bar.maximum) then
                        bar.current, bar.maximum = current, maximum
                        drawHealthFill(bar, current, maximum)
                        bar.left:SetText(number(current) .. " / " .. number(maximum))
                        bar.right:SetText(math.floor(current / maximum * 100 + .5) .. "%")
                    end
                end)
            end
            return y + BAR_HEIGHT + 8
        end,
    }
end

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

-- What the panel shows, for Panel/Render.lua to draw.
local function unitView(model)
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    local color = model.color or colors.neutral
    local hasIcon = ns.option("iconUnits") and (model.unit or model.iconPath) and true or false
    local plate = levelBadge(model, hasIcon)

    local header = { { text = model.name, style = styles.unitName, color = color, gap = 2 } }
    local guild = guildText(model)
    if guild then
        header[#header + 1] = { text = guild, style = styles.unitGuild,
            color = { color[1] * .5 + .5, color[2] * .5 + .5, color[3] * .5 + .5 }, gap = 2 }
    end
    local info = infoText(model, plate ~= nil)
    if info then header[#header + 1] = { text = info, style = styles.unitInfo, color = DETAIL_COLOR, gap = 4 } end
    header[#header + 1] = { badges = badges(model), style = styles.unitBadges, before = 1, gap = 4 }

    local sections = {}
    local health, details = healthRow(model), detailRows(model)
    local separator = (health or #details > 0) and { divider = ui.GOLD_RULE } or nil
    if health then
        sections[#sections + 1] = healthSection(model, health, styles.unitHealth, separator)
        separator = nil
    end
    if #details > 0 then
        sections[#sections + 1] = { separator = separator, kind = "rows", rows = details,
            style = styles.unitDetails, color = DETAIL_COLOR, gap = 2 }
    end
    if #model.quests > 0 then
        local quests = {}
        for index, row in ipairs(model.quests) do
            quests[index] = row.title and { left = row.left, right = row.right, color = colors.quest }
                or { left = row.left, right = row.right, color = row.completed and colors.done or colors.objective,
                    indent = 8 }
        end
        sections[#sections + 1] = { separator = { divider = ui.GOLD_RULE, before = #sections > 0 and 6 or 0 },
            kind = "rows", rows = quests, style = styles.unitQuests, gap = 2 }
    end
    if #model.extras > 0 then
        sections[#sections + 1] = { separator = #sections > 0 and { rule = EXTRAS_RULE, before = 8 } or { space = 4 },
            kind = "rows", rows = model.extras, style = styles.extras, color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    return {
        tooltipType = "unit",
        color = color,
        tint = model.color,
        strength = TINT_STRENGTH,
        icon = hasIcon and (model.iconPath or WHITE) or nil,
        iconSize = ICON_SIZE,
        portrait = hasIcon and model.unit or nil,
        badge = plate,
        badgeColor = model.level and levelColor(model.level),
        header = header,
        sections = sections,
    }
end

local function renderUnit(panel, tooltip, model)
    ui.renderView(panel, tooltip, unitView(model))
    if model.isPlayer and (model.faction == "Alliance" or model.faction == "Horde") then
        showWatermark(panel, model.faction)
    end
end

ui.unitModel = function(fields)
    for _, list in ipairs({ "quests", "extras" }) do fields[list] = fields[list] or {} end
    return completeModel(fields, nil, ns.Game)
end
-- Its target, tapped, and dead rows come from the game, not the tooltip's text.
ui.registerTooltipType(UNIT, { read = readUnit, render = renderUnit, key = unitKey, option = "unitPanels", alwaysRedraw = true })
