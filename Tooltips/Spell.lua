-- Spell tooltips as a panel: a strip for cost, cast time, cooldown, and range,
-- then the description one sentence per line, tinted by school or resource.
local _, ns = ...
local ui = ns.ui
local SPELL = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Spell
if not (ui and SPELL and ui.renderView) then
    return
end

local util = ns.util
local colors = ns.Palette.roles
local isSecret, safeText, trim = util.isSecret, util.safeText, util.trim
local add = ui.add
local LINE = Enum.TooltipDataLineType or {}
local styledAt, measureStyled = ui.styledAt, ui.measureStyled
local PAD = ui.PAD
local PARTS = { "spellTitle", "spellBadges", "spellValues", "spellCaptions", "spellDetails",
    "spellText", "extras" }
local TITLE_COLOR = colors.title
local DETAIL_COLOR = colors.detail
local CAPTION_OFFSET = 17
local RANK_BADGE = { .60, .56, .50 }
local REMAINING_COLOR = { 1, .60, .25 }
local UNMET_COLOR = colors.unmet
local STRIP_HEIGHT = 34
-- Spells have one title line, so a smaller icon keeps the header short.
local ICON_SIZE = 38
-- Spells are tinted a little less than items; the school is only a hint.
local SPELL_TINT = .7
local EXTRAS_RULE = { .50, .50, .54 }
local SCHOOL_COLORS = ns.Palette.schools
local POWER_COLORS = {
    Mana = { .25, .55, 1 },
    Rage = { .90, .22, .20 },
    Energy = { 1, .86, .25 },
    Focus = { 1, .55, .25 },
    ["Runic Power"] = { 0, .82, 1 },
}

local function spellKey(_, data)
    if isSecret(data.id) then return end
    return data.id
end

local function titleCase(text)
    return (text:gsub("(%a)([%w']*)", function(first, rest) return first:upper() .. rest end))
end

local function readStat(model, text)
    local lower = text:lower()
    local amount, power = lower:match("^([%d,]+) (%a[%a ]-)$")
    if amount and POWER_COLORS[titleCase(power)] then
        power = titleCase(power)
        model.cost, model.power = { amount, power }, power
        return true
    end
    local percent = lower:match("^(%d+)%% of base mana$")
    if percent then
        model.cost, model.power = { percent .. "%", "Base Mana" }, "Mana"
        return true
    end
    local castLength = #(lower:match("^([%d%.]+ %a+) cast$") or "")
    if castLength > 0 then
        model.cast = { text:sub(1, castLength), "Cast" }
        return true
    end
    if lower == "instant" or lower == "instant cast" then
        model.cast = { "Instant", "Cast" }
        return true
    end
    if lower == "passive" then
        model.passive = text
        return true
    end
    if lower == "channeled" or lower == "next melee" then
        model.cast = { text, "Cast" }
        return true
    end
    local cooldownLength = #(lower:match("^(.+) cooldown$") or "")
    if cooldownLength > 0 then
        model.cooldown = { text:sub(1, cooldownLength), "Cooldown" }
        return true
    end
    local cooldown = text:match("^[Cc]ooldown:%s*(.+)$")
    if cooldown then
        model.cooldown = { cooldown, "Cooldown" }
        return true
    end
    local rangeLength = #(lower:match("^(.+) range$") or "")
    if rangeLength > 0 then
        model.range = { text:sub(1, rangeLength), "Range" }
        return true
    end
end

-- The game can fill a line's right side only in the tooltip text, as it may
-- for a cooldown beside the cast time.
local function nativeRight(tooltip, lineIndex)
    local font = tooltip.GetRightLine and tooltip:GetRightLine(lineIndex)
    if not font then
        local name = tooltip:GetName()
        font = name and _G[name .. "TextRight" .. lineIndex]
    end
    local text = font and font:IsShown() and safeText(font:GetText())
    return text or ""
end

local colorNumbers = util.colorNumbers

local function badges(model, school)
    local list = {}
    if school then list[#list + 1] = { school, SCHOOL_COLORS[school] } end
    if model.rank ~= "" then list[#list + 1] = { model.rank, RANK_BADGE } end
    if model.passive then list[#list + 1] = { model.passive, RANK_BADGE } end
    if model.talent then
        list[#list + 1] = { "Rank " .. model.talent.rank .. "/" .. model.talent.max, RANK_BADGE }
    end
    return list
end

-- Descriptions come in the game's gold; without a readable color, a long
-- line with nothing on the right is taken as one.
local function isDescription(line, text, right)
    local color = line.leftColor
    if not isSecret(color) and type(color) == "table" then
        local r, g, b = color.r, color.g, color.b
        if not isSecret(r) and not isSecret(g) and not isSecret(b)
            and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r > .9 and g > .65 and g < .9 and b < .3
        end
    end
    return right == "" and #text >= 40
end

local function newModel(icon)
    return { cells = {}, details = {}, requirements = {}, description = {}, extras = {}, rank = "",
        icon = icon }
end

-- A description can open with its own requirement, on a line of its own.
local function readDescription(model, text)
    local rest = {}
    for paragraph in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do
        local stripped = trim(paragraph)
        if #rest == 0 and trim(util.uncolored(stripped)):match("^Requires ") then
            add(model.requirements, stripped, "")
        elseif stripped ~= "" then
            rest[#rest + 1] = stripped
        end
    end
    if #rest > 0 then model.description[#model.description + 1] = table.concat(rest, "\n") end
end

local function readLine(model, line, left, right, game)
    local text, rightText = trim(left), trim(right)
    if text == "" and rightText == "" then return end
    if LINE.UsageRequirement and line.type == LINE.UsageRequirement then
        add(model.requirements, text, rightText)
        local usable = line.usable
        if isSecret(usable) then usable = nil end
        if usable == false or not ui.requirementMet(text, line.leftColor, game) then
            model.requirements[#model.requirements].color = UNMET_COLOR
        end
        return
    end
    if rightText ~= "" and readStat(model, rightText) then rightText = "" end
    if text ~= "" and readStat(model, text) then
        if rightText ~= "" then add(model.details, rightText, "") end
    elseif text:match("^Cooldown remaining") then
        add(model.details, text, rightText)
        model.details[#model.details].color = REMAINING_COLOR
    elseif text:match("^Requires ") then
        add(model.requirements, text, rightText)
        local row = model.requirements[#model.requirements]
        row.color = not ui.requirementMet(text, line.leftColor, game) and UNMET_COLOR or nil
    elseif text:match("^Reagents:") or text:match("^Tools:") then
        add(model.details, text, rightText)
    elseif text ~= "" and ((LINE.SpellDescription and line.type == LINE.SpellDescription)
        or isDescription(line, text, rightText)) then
        readDescription(model, text)
    else
        add(model.extras, left, right)
        local row = model.extras[#model.extras]
        row.color, row.rightColor = ui.colorOf(line.leftColor), ui.colorOf(line.rightColor)
    end
end

-- The talent window writes a talent's rank above the tooltip's data, and,
-- below it, another rank and the points still to spend. After "Next Rank:"
-- that rank is the next one. Without the label, a second "Passive" starts it,
-- and then it is the current rank while the data holds the next.
-- Rows it does not claim are other addons' rows. Nil when not a talent.
local function readTalent(model, rows)
    local talent, extras, block, unlabeled
    for _, row in ipairs(rows) do
        local plain = trim(util.plainText(row.left))
        local rank, max = plain:match("^Rank (%d+)/(%d+)$")
        if rank and not talent then
            talent = { rank = tonumber(rank), max = tonumber(max), description = {}, details = {} }
            extras = {}
        elseif not talent then
            return
        elseif plain == "Next Rank:" then
            block = talent
        elseif not block and plain:lower() == "passive" then
            block, unlabeled = talent, true
        elseif plain:match("^Spend %d+ more points? in ") or plain:match("^Requires ") then
            local color = row.textColor
            local unmet = row.left:find("|cffff2020", 1, true) or (color and color[1] > .9 and color[2] < .3)
            add(model.requirements, plain, "")
            model.requirements[#model.requirements].color = unmet and UNMET_COLOR or nil
        elseif block and row.left:find("^|c%x%x%x%x%x%x%x%x") then
            -- The game's own lines bring no color of their own; this is another
            -- addon's, as Forever's "Press F6" line, which can follow the next rank.
            extras[#extras + 1] = row
        elseif block and plain:lower() == "passive" then
            -- The rank after the data repeats it.
        elseif block then
            local color = row.textColor
            local gold = color and color[1] > .9 and color[2] > .7 and color[2] < .9 and color[3] < .2
            if gold then
                block.description[#block.description + 1] = plain
            else
                add(block.details, plain, trim(row.right or ""))
            end
        else
            extras[#extras + 1] = row
        end
    end
    if not talent then return end
    if unlabeled and #talent.description > 0 then
        model.description, talent.description = talent.description, model.description
    end
    model.talent = talent
    return extras
end

local function readSpell(tooltip, data, game)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local model = newModel(game.spellIcon(data.id))
    model.spellID = not isSecret(data.id) and data.id or nil
    model.lineIndices = {}
    local current = model
    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.lineIndex) or isSecret(line.type) then return end
        if line.lineIndex then model.lineIndices[line.lineIndex] = true end
        if LINE.NestedBlock and line.type == LINE.NestedBlock then
            -- Another spell inside this one: another form's version, or a recipe's result.
            local id = line.tooltipID
            if isSecret(id) then id = nil end
            model.nested = newModel(game.spellIcon(id))
            model.nested.spellID = id
            current = model.nested
        elseif line.lineIndex then
            local left, right = safeText(line.leftText), safeText(line.rightText)
            if not left or not right then return end
            if right == "" then right = nativeRight(tooltip, line.lineIndex) end
            local isName = (LINE.SpellName and line.type == LINE.SpellName)
                or (current == model and line.lineIndex == 1)
            if isName and not current.name then
                current.name, current.rank = trim(left), trim(right)
            else
                readLine(current, line, left, right, game)
            end
        end
    end
    -- Talents, and spells with another nested in them, leave their name out of
    -- the data; the game writes it on the tooltip's first line.
    if not model.name or model.name == "" then
        local font = tooltip:GetLeftLine(1)
        model.name = game.spellName(data.id) or trim(font and safeText(font:GetText()) or "")
        model.lineIndices[1] = true
    end
    if model.name == "" then return end

    local appended = ui.appendedRows(tooltip, model.lineIndices)
    if not appended then return end
    local rows = {}
    for _, row in ipairs(appended) do
        if trim(row.left) ~= "" or row.right ~= "" then rows[#rows + 1] = row end
    end
    for _, row in ipairs(readTalent(model, rows) or rows) do model.extras[#model.extras + 1] = row end
    for _, part in ipairs({ model, model.nested }) do
        for _, field in ipairs({ "cost", "cast", "cooldown", "range" }) do
            if part[field] then part.cells[#part.cells + 1] = part[field] end
        end
    end
    return model
end

local function sentencesOf(model)
    local list = {}
    for _, text in ipairs(model.description) do
        for _, sentence in ipairs(util.splitSentences(text)) do list[#list + 1] = sentence end
    end
    return list
end

-- A nested spell's name, a step smaller than the panel's own.
local function nestedTitleStyle(title)
    local style = {}
    for field, value in pairs(title) do style[field] = value end
    style.size = math.max(10, title.size - 4)
    return style
end

-- The strip's cells, always all four and in this order. One the tooltip left
-- out shows what its absence means, dimmed; a spell with none, as a passive,
-- has no strip.
local STRIP = {
    { "cost", "Free", "Cost" },
    { "cast", "Instant", "Cast" },
    { "cooldown", "None", "Cooldown" },
    { "range", "Self", "Range" },
}

local function stripCells(part)
    if #part.cells == 0 then return part.cells end
    local cells = {}
    for index, cell in ipairs(STRIP) do
        cells[index] = part[cell[1]] or { cell[2], cell[3], implied = true }
    end
    return cells
end

-- The widest thing in one spell's body: its strip, rows, and sentences.
local function bodyWidth(panel, part, body, styles)
    local need = 0
    local function consider(width) if width > need then need = width end end
    local cells = stripCells(part)
    if #cells > 0 then
        local widest = 0
        for _, cell in ipairs(cells) do
            widest = math.max(widest, measureStyled(panel, cell[1], styles.spellValues),
                measureStyled(panel, cell[2]:upper(), styles.spellCaptions))
        end
        consider((widest + 16) * #cells)
    end
    for _, rows in ipairs({ part.details, part.requirements }) do
        for _, row in ipairs(rows) do consider(ui.rowWidth(panel, row, styles.spellDetails)) end
    end
    for _, sentence in ipairs(body.sentences) do
        consider(math.min(measureStyled(panel, sentence, styles.spellText), ui.PROSE_WIDTH))
    end
    for _, row in ipairs(body.powerRows or {}) do
        consider(ui.rowWidth(panel, row, styles.spellDetails))
    end
    local next = part.talent
    if next then
        for _, row in ipairs(next.details) do consider(ui.rowWidth(panel, row, styles.spellDetails)) end
        for _, sentence in ipairs(body.nextSentences) do
            consider(math.min(measureStyled(panel, sentence, styles.spellText), ui.PROSE_WIDTH))
        end
    end
    return need
end

local function drawStrip(panel, model, y, color, styles)
    local values, captions = styles.spellValues, styles.spellCaptions
    local cells = stripCells(model)
    local cellWidth = (panel.width - 2 * PAD) / #cells
    local captionOffset = math.max(CAPTION_OFFSET, values.size + 4)
    local height = math.max(STRIP_HEIGHT, captionOffset + captions.size + 8)
    for index, cell in ipairs(cells) do
        local x = PAD + (index - 1) * cellWidth
        local valueColor = cell.implied and colors.caption or TITLE_COLOR
        local power = cell == model.cost and POWER_COLORS[model.power]
        if power then
            valueColor = { power[1] * .45 + .55, power[2] * .45 + .55, power[3] * .45 + .55 }
        end
        styledAt(panel, cell[1], x, y, cellWidth, values, valueColor, "CENTER")
        styledAt(panel, cell[2]:upper(), x, y + captionOffset, cellWidth, captions,
            colors.caption, "CENTER")
        if index > 1 then
            local separator = ui.acquireTexture(panel)
            separator:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -(y + 2))
            separator:SetSize(1, height - 8)
            separator:SetVertexColor(color[1] * .6, color[2] * .6, color[3] * .6, .5)
        end
    end
    return y + height
end

local function hasBody(part, body)
    return #part.cells > 0 or #part.details > 0 or #part.requirements > 0 or #body.sentences > 0
        or body.powerRows ~= nil or (body.nextSentences and #body.nextSentences > 0)
end

-- The strip, requirements, and description of the spell or the one nested in
-- it; body holds its sentences and spell power rows.
local function drawBody(panel, part, body, y, color, styles, numberCode)
    if #part.cells > 0 then
        y = drawStrip(panel, part, y, color, styles) + 2
    end
    if #part.details > 0 or #part.requirements > 0 then
        y = ui.drawGroup(panel, part.requirements, y + 2, styles.spellDetails, DETAIL_COLOR, 0, 2)
        y = ui.drawGroup(panel, part.details, y, styles.spellDetails, DETAIL_COLOR, 0, 2)
    end
    if #body.sentences > 0 then
        if #part.cells > 0 or #part.details > 0 or #part.requirements > 0 then
            y = ui.rule(panel, y, { color[1] * .7, color[2] * .7, color[3] * .7 }, 6)
        end
        for _, sentence in ipairs(body.sentences) do
            y = ui.drawRow(panel, { left = colorNumbers(sentence, numberCode) },
                y, styles.spellText, colors.description, 0, 5)
        end
    end
    if body.powerRows then
        if #part.cells > 0 or #part.details > 0 or #part.requirements > 0 or #body.sentences > 0 then
            y = ui.rule(panel, y, { color[1] * .7, color[2] * .7, color[3] * .7 }, 6)
        end
        y = ui.drawGroup(panel, body.powerRows, y, styles.spellDetails, DETAIL_COLOR, 0, 2)
    end
    -- A talent's next rank, a step dimmer, under its caption.
    local talent = part.talent
    if talent and (#body.nextSentences > 0 or #talent.details > 0) then
        y = ui.caption(panel, y + 4, "NEXT RANK", styles.spellCaptions, colors.caption)
        y = ui.drawGroup(panel, talent.details, y, styles.spellDetails, DETAIL_COLOR, 0, 2)
        for _, sentence in ipairs(body.nextSentences) do
            y = ui.drawRow(panel, { left = colorNumbers(sentence, numberCode) },
                y, styles.spellText, DETAIL_COLOR, 0, 5)
        end
    end
    return y
end

-- What the panel shows, for Panel/Render.lua to draw. Each spell's body,
-- its own and a nested one's, is drawn here as one custom section.
local function spellView(model)
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    local school = ns.Palette.detectSchool(model.description, model.name)
    local numberCode = ns.Palette.numberCode(school and SCHOOL_COLORS[school])
    local power = model.power and POWER_COLORS[model.power]
    local accent = school and SCHOOL_COLORS[school] or power
    local color = accent or colors.neutral
    local function bodyOf(part)
        local nextSentences = {}
        if part.talent then
            for _, text in ipairs(part.talent.description) do
                for _, sentence in ipairs(util.splitSentences(text)) do nextSentences[#nextSentences + 1] = sentence end
            end
        end
        return { sentences = sentencesOf(part), powerRows = ns.option("spellPower") and ns.spellPowerRows
            and ns.spellPowerRows(part, numberCode, ns.Game) or nil, nextSentences = nextSentences }
    end

    local sections = {}
    local body = bodyOf(model)
    if hasBody(model, body) then
        sections[#sections + 1] = { separator = { divider = ui.GOLD_RULE }, kind = "custom",
            measure = function(panel) return bodyWidth(panel, model, body, styles) end,
            draw = function(panel, y) return drawBody(panel, model, body, y, color, styles, numberCode) end }
    end
    local nested = model.nested
    if nested and nested.name then
        local nestedBody = bodyOf(nested)
        local titleStyle = nestedTitleStyle(styles.spellTitle)
        sections[#sections + 1] = { separator = { divider = ui.GOLD_RULE, before = #sections > 0 and 8 or 0 },
            kind = "custom",
            measure = function(panel)
                return math.max(measureStyled(panel, nested.name, titleStyle), bodyWidth(panel, nested, nestedBody, styles))
            end,
            draw = function(panel, y)
                y = y + styledAt(panel, nested.name, PAD, y, panel.width - 2 * PAD, titleStyle, TITLE_COLOR) + 6
                return drawBody(panel, nested, nestedBody, y, color, styles, numberCode)
            end }
    end
    if #model.extras > 0 then
        sections[#sections + 1] = { separator = #sections > 0 and { rule = EXTRAS_RULE, before = 8 } or { space = 12 },
            kind = "rows", rows = model.extras, style = styles.extras, color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    local header = {
        { text = model.name, style = styles.spellTitle, color = TITLE_COLOR, gap = 4 },
        { badges = badges(model, school), style = styles.spellBadges, before = 1, gap = 4 },
    }
    return {
        tooltipType = "spell",
        color = color,
        tint = accent,
        strength = SPELL_TINT,
        icon = ns.option("iconSpells") and model.icon or nil,
        iconSize = ICON_SIZE,
        header = header,
        sections = sections,
    }
end

local function renderSpell(panel, tooltip, model)
    ui.renderView(panel, tooltip, spellView(model))
end

ui.defineTooltipType(SPELL, {
    read = readSpell, render = renderSpell, key = spellKey, option = "spellPanels",
})
