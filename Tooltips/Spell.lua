-- Spell tooltips as a panel: a strip for cost, cast time, cooldown, and range,
-- then the description one sentence per line, tinted by school or resource.
local _, ns = ...
local ui = ns.ui
local SPELL = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Spell
if not (ui and SPELL) then
    return
end

local util = ns.util
local colors = ns.Palette.roles
local isSecret, safeText, trim = util.isSecret, util.safeText, util.trim
local add = ui.add
local LINE = Enum.TooltipDataLineType or {}
local styledAt, measureStyled = ui.styledAt, ui.measureStyled
local drawBadges, badgesWidth = ui.drawBadges, ui.badgesWidth
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
local TEXT_INDENT = ICON_SIZE + 10
-- Spells are tinted a little less than items; the school is only a hint.
local SPELL_TINT = .7
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

local function badges(model)
    local list = {}
    if model.school then list[#list + 1] = { model.school, SCHOOL_COLORS[model.school] } end
    if model.rank ~= "" then list[#list + 1] = { model.rank, RANK_BADGE } end
    if model.passive then list[#list + 1] = { model.passive, RANK_BADGE } end
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
    for _, row in ipairs(appended) do
        if trim(row.left) ~= "" or row.right ~= "" then model.extras[#model.extras + 1] = row end
    end
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

local function fitWidth(panel, model, styles)
    local indent = model.icon and TEXT_INDENT or 0
    local need = measureStyled(panel, model.name, styles.spellTitle) + indent
    local list = badges(model)
    if #list > 0 then
        need = math.max(need, badgesWidth(panel, list, styles.spellBadges) + indent)
    end
    local function consider(width) if width > need then need = width end end
    for _, part in ipairs({ model, model.nested }) do
        if #part.cells > 0 then
            local widest = 0
            for _, cell in ipairs(part.cells) do
                widest = math.max(widest, measureStyled(panel, cell[1], styles.spellValues),
                    measureStyled(panel, cell[2]:upper(), styles.spellCaptions))
            end
            consider((widest + 16) * #part.cells)
        end
        for _, rows in ipairs({ part.details, part.requirements }) do
            for _, row in ipairs(rows) do consider(ui.rowWidth(panel, row, styles.spellDetails)) end
        end
        for _, sentence in ipairs(part.sentences) do
            consider(math.min(measureStyled(panel, sentence, styles.spellText), ui.PROSE_WIDTH))
        end
        for _, row in ipairs(part.powerRows or {}) do
            consider(ui.rowWidth(panel, row, styles.spellDetails))
        end
    end
    if model.nested and model.nested.name then
        consider(measureStyled(panel, model.nested.name, nestedTitleStyle(styles.spellTitle)))
    end
    for _, row in ipairs(model.extras) do
        local width = ui.rowWidth(panel, row, styles.extras)
        if not row.right or row.right == "" then width = math.min(width, ui.PROSE_WIDTH) end
        consider(width)
    end
    return math.max(ui.MIN_WIDTH, math.min(ui.MAX_WIDTH, math.ceil(need + 2 * PAD)))
end

local function drawStrip(panel, model, y, color, styles)
    local values, captions = styles.spellValues, styles.spellCaptions
    local cellWidth = (panel.width - 2 * PAD) / #model.cells
    local captionOffset = math.max(CAPTION_OFFSET, values.size + 4)
    local height = math.max(STRIP_HEIGHT, captionOffset + captions.size + 8)
    for index, cell in ipairs(model.cells) do
        local x = PAD + (index - 1) * cellWidth
        local valueColor = TITLE_COLOR
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

local function hasBody(part)
    return #part.cells > 0 or #part.details > 0 or #part.requirements > 0 or #part.sentences > 0
        or part.powerRows ~= nil
end

-- The strip, requirements, and description of the spell or the one nested in it.
local function drawBody(panel, part, y, color, styles, numberCode)
    if #part.cells > 0 then
        y = drawStrip(panel, part, y, color, styles) + 2
    end
    if #part.details > 0 or #part.requirements > 0 then
        y = ui.drawGroup(panel, part.requirements, y + 2, styles.spellDetails, DETAIL_COLOR, 0, 2)
        y = ui.drawGroup(panel, part.details, y, styles.spellDetails, DETAIL_COLOR, 0, 2)
    end
    if #part.sentences > 0 then
        if #part.cells > 0 or #part.details > 0 or #part.requirements > 0 then
            y = ui.rule(panel, y, { color[1] * .7, color[2] * .7, color[3] * .7 }, 6)
        end
        for _, sentence in ipairs(part.sentences) do
            y = ui.drawRow(panel, { left = colorNumbers(sentence, numberCode) },
                y, styles.spellText, colors.description, 0, 5)
        end
    end
    if part.powerRows then
        if #part.cells > 0 or #part.details > 0 or #part.requirements > 0 or #part.sentences > 0 then
            y = ui.rule(panel, y, { color[1] * .7, color[2] * .7, color[3] * .7 }, 6)
        end
        y = ui.drawGroup(panel, part.powerRows, y, styles.spellDetails, DETAIL_COLOR, 0, 2)
    end
    return y
end

local function renderSpell(panel, tooltip, model)
    panel:Show()
    ui.clearPool(panel)
    if not ns.option("iconSpells") then model.icon = nil end
    model.school = ns.Palette.detectSchool(model.description, model.name)
    local numberCode = ns.Palette.numberCode(model.school and SCHOOL_COLORS[model.school])
    for _, part in ipairs({ model, model.nested }) do
        part.sentences = sentencesOf(part)
        part.powerRows = ns.option("spellPower") and ns.spellPowerRows
            and ns.spellPowerRows(part, numberCode, ns.Game) or nil
    end
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    panel.width = fitWidth(panel, model, styles)
    panel:SetWidth(panel.width)
    local power = model.power and POWER_COLORS[model.power]
    local accent = model.school and SCHOOL_COLORS[model.school] or power
    local color = accent or colors.neutral
    local headerMin = ui.drawChrome(panel, tooltip, {
        tooltipType = "spell",
        color = color,
        tint = accent,
        strength = SPELL_TINT,
        icon = model.icon,
        iconSize = ICON_SIZE,
    })

    local inner = panel.width - 2 * PAD
    local y = ui.TITLE_TOP
    local indent = model.icon and TEXT_INDENT or 0
    local leftIndent = ui.headerInsets(indent)
    y = y + styledAt(panel, model.name, PAD + leftIndent, y, inner - indent, styles.spellTitle,
        TITLE_COLOR) + 4
    local list = badges(model)
    if #list > 0 then
        y = drawBadges(panel, list, PAD + leftIndent, y + 1, styles.spellBadges) + 4
    end
    y = math.max(y + 6, headerMin)
    panel.header:SetHeight(y - panel.inset)
    panel.footer:SetHeight(0)

    local sectioned = false
    if hasBody(model) then
        y = drawBody(panel, model, ui.divider(panel, y, ui.GOLD_RULE), color, styles, numberCode)
        sectioned = true
    end
    local nested = model.nested
    if nested and nested.name then
        y = ui.divider(panel, y, ui.GOLD_RULE, sectioned and 8 or 0)
        y = y + styledAt(panel, nested.name, PAD, y, inner, nestedTitleStyle(styles.spellTitle),
            TITLE_COLOR) + 6
        y = drawBody(panel, nested, y, color, styles, numberCode)
        sectioned = true
    end

    if #model.extras > 0 then
        if sectioned then
            y = ui.rule(panel, y, { .50, .50, .54 }, 8)
        else
            y = y + 12
        end
        y = ui.drawGroup(panel, model.extras, y, styles.extras, ui.EXTRA_COLOR, 0, 2)
    end
    ui.finishPanel(panel, tooltip, y)
end

ui.registerTooltipType(SPELL, {
    read = readSpell, render = renderSpell, key = spellKey, option = "spellPanels",
})
