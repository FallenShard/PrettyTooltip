-- Spell tooltips as a panel: a strip for cost, cast time, cooldown, and range,
-- then the description one sentence per line, tinted by school or resource.
local _, ns = ...
local ui = ns.ui
local SPELL = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Spell
if not (ui and SPELL) then
    return
end

local isSecret, safeText, add = ui.isSecret, ui.safeText, ui.add
local textAt, measure = ui.textAt, ui.measure
local PAD = ui.PAD
local TITLE_COLOR = { .96, .92, .84 }
local NEUTRAL = { .62, .66, .74 }
local DESCRIPTION_COLOR = { .92, .87, .76 }
local CAPTION_COLOR = { .60, .57, .52 }
local PILL_HEIGHT = 16
local PILL_GAP = 6
local RANK_PILL = { .60, .56, .50 }
local REMAINING_COLOR = { 1, .60, .25 }
local UNMET_COLOR = { 1, .34, .28 }
local STRIP_HEIGHT = 34
-- Spells have one title line, so a smaller icon keeps the header short.
local ICON_SIZE = 38
local TEXT_INDENT = ICON_SIZE + 10
-- Spells are tinted a little less than items; the school is only a hint.
local SPELL_TINT = .7
-- Same hues as the school stat colors in PrettyTooltip.lua.
local SCHOOL_COLORS = {
    Arcane = { .92, .38, .84 },
    Fire = { 1, .43, .11 },
    Frost = { .30, .78, .97 },
    Holy = { .98, .73, .22 },
    Nature = { .50, .80, .28 },
    Shadow = { .64, .31, .89 },
}
-- Resource colors: the cost value, and the tint when no school is named.
local POWER_COLORS = {
    Mana = { .25, .55, 1 },
    Rage = { .90, .22, .20 },
    Energy = { 1, .86, .25 },
    Focus = { 1, .55, .25 },
    ["Runic Power"] = { 0, .82, 1 },
}

local function trim(text)
    return text:match("^%s*(.-)%s*$")
end

local function spellKey(_, data)
    if isSecret(data.id) then return end
    return data.id
end

local function getSpellIcon(spellID)
    if isSecret(spellID) or type(spellID) ~= "number" then return end
    local getter = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
    if not getter then return end
    local ok, icon = pcall(getter, spellID)
    if ok and not isSecret(icon) and icon then return icon end
end

local function titleCase(text)
    return (text:gsub("(%a)([%w']*)", function(first, rest) return first:upper() .. rest end))
end

-- Fills one strip cell from a cost, cast, cooldown, or range text. Matched
-- without regard to case; the value keeps the game's spelling.
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
    if lower == "channeled" or lower == "next melee" or lower == "passive" then
        model.cast = { text, lower == "passive" and "Ability" or "Cast" }
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

local function hex(color)
    local function byte(value) return math.floor(math.min(1, value) * 255 + .5) end
    return string.format("%02X%02X%02X", byte(color[1]), byte(color[2]), byte(color[3]))
end

-- The game's own escapes; digits inside them (color codes, icon sizes, the
-- plural escape "|4hour:hrs;") must not be recolored.
local ESCAPES = { "|c%x%x%x%x%x%x%x%x", "|r", "|T.-|t", "|A.-|a", "|H.-|h", "|K.-|k", "|4[^;]*;", "|n" }

-- "1 |4hour:hrs;" picks its word from the number before it. Coloring that
-- number would separate the two, so resolve the escape first: singular for 1.
local function resolvePlurals(text)
    return (text:gsub("(%d+)(%s*)|4([^:;]*):([^;]*);", function(number, space, one, many)
        return number .. space .. (tonumber(number) == 1 and one or many)
    end))
end

local function colorPlainNumbers(text, code)
    -- A number must start a word, so "x2" is left alone; a sentence's final
    -- period stays outside the color.
    return (text:gsub("%f[%w](%d+%.?%d*%%?)", function(number)
        local trailing = ""
        if number:sub(-1) == "." then number, trailing = number:sub(1, -2), "." end
        return "|cff" .. code .. number .. "|r" .. trailing
    end))
end

local function colorNumbers(text, code)
    text = resolvePlurals(text)
    local out, plainStart, pos = {}, 1, 1
    while true do
        local bar = text:find("|", pos, true)
        if not bar then break end
        local escapeEnd
        for _, pattern in ipairs(ESCAPES) do
            local _, stop = text:find("^" .. pattern, bar)
            if stop then escapeEnd = stop break end
        end
        -- An escape this list does not know still protects its first character.
        escapeEnd = escapeEnd or math.min(bar + 1, #text)
        out[#out + 1] = colorPlainNumbers(text:sub(plainStart, bar - 1), code)
        out[#out + 1] = text:sub(bar, escapeEnd)
        plainStart, pos = escapeEnd + 1, escapeEnd + 1
    end
    out[#out + 1] = colorPlainNumbers(text:sub(plainStart), code)
    return table.concat(out)
end

local function pills(model)
    local list = {}
    if model.school then list[#list + 1] = { model.school, SCHOOL_COLORS[model.school] } end
    if model.rank ~= "" then list[#list + 1] = { model.rank, RANK_PILL } end
    return list
end

local function pillsWidth(panel, list)
    local width = 0
    for index, pill in ipairs(list) do
        width = width + measure(panel, pill[1], 10) + 12 + (index > 1 and PILL_GAP or 0)
    end
    return width
end

-- Small tags under the name, drawn like the item level badge.
local function drawPills(panel, list, x, y)
    for _, pill in ipairs(list) do
        local text, color = pill[1], pill[2]
        local width = measure(panel, text, 10) + 12
        local border = ui.acquireTexture(panel, nil, -2)
        border:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y)
        border:SetSize(width, PILL_HEIGHT)
        border:SetVertexColor(color[1] * .8, color[2] * .8, color[3] * .8, .9)
        local fill = ui.acquireTexture(panel, nil, -1)
        fill:SetPoint("TOPLEFT", border, "TOPLEFT", 1, -1)
        fill:SetSize(width - 2, PILL_HEIGHT - 2)
        fill:SetVertexColor(color[1] * .14, color[2] * .14, color[3] * .14, 1)
        textAt(panel, text, x, y + 3, width, 10,
            { color[1] * .45 + .55, color[2] * .45 + .55, color[3] * .45 + .55 }, nil, "CENTER")
        x = x + width + PILL_GAP
    end
    return y + PILL_HEIGHT
end

-- No spell API names the school, so take the first school word in the
-- description, then in the name.
local function detectSchool(model)
    for _, text in ipairs(model.description) do
        for word in text:gmatch("%u%l+") do
            if SCHOOL_COLORS[word] then return word end
        end
    end
    for word in model.name:gmatch("%u%l+") do
        if SCHOOL_COLORS[word] then return word end
    end
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

local function readSpell(tooltip, data)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local model = {
        cells = {},
        details = {},
        requirements = {},
        description = {},
        extras = {},
        lineIndices = {},
        icon = getSpellIcon(data.id),
    }
    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.lineIndex) then return end
        if line.lineIndex then
            local left, right = safeText(line.leftText), safeText(line.rightText)
            if not left or not right then return end
            model.lineIndices[line.lineIndex] = true
            if right == "" then right = nativeRight(tooltip, line.lineIndex) end
            local text, rightText = trim(left), trim(right)
            if not model.name then
                model.name, model.rank = text, rightText
            elseif text ~= "" or rightText ~= "" then
                if rightText ~= "" and readStat(model, rightText) then rightText = "" end
                if text ~= "" and readStat(model, text) then
                    if rightText ~= "" then add(model.details, rightText, "") end
                elseif text:match("^Cooldown remaining") then
                    add(model.details, text, rightText)
                    model.details[#model.details].color = REMAINING_COLOR
                elseif text:match("^Requires ") then
                    add(model.requirements, text, rightText)
                    local row = model.requirements[#model.requirements]
                    row.color = not ui.requirementMet(text, line.leftColor) and UNMET_COLOR or nil
                elseif text:match("^Reagents:") or text:match("^Tools:") then
                    add(model.details, text, rightText)
                elseif text ~= "" and isDescription(line, text, rightText) then
                    model.description[#model.description + 1] = text
                else
                    add(model.extras, left, right)
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
    for _, field in ipairs({ "cost", "cast", "cooldown", "range" }) do
        if model[field] then model.cells[#model.cells + 1] = model[field] end
    end
    return model
end

-- Sentences end at . ! or ? followed by a space and a capital, so decimals
-- such as "1.5 sec" stay whole.
local function splitSentences(text)
    local sentences = {}
    for paragraph in (text:gsub("\r?\n", "|n") .. "|n"):gmatch("(.-)|n") do
        local from = 1
        while true do
            local stop, resume = paragraph:find("[%.!?]%s+%f[%u]", from)
            if not stop then break end
            sentences[#sentences + 1] = trim(paragraph:sub(from, stop))
            from = resume + 1
        end
        local rest = trim(paragraph:sub(from))
        if rest ~= "" then sentences[#sentences + 1] = rest end
    end
    return sentences
end

local function fitWidth(panel, model, title, sentences)
    local indent = model.icon and TEXT_INDENT or 0
    local need = measure(panel, title, 17, (ui.titleFont())) + indent
    local list = pills(model)
    if #list > 0 then need = math.max(need, pillsWidth(panel, list) + indent) end
    local function consider(width) if width > need then need = width end end
    if #model.cells > 0 then
        local widest = 0
        for _, cell in ipairs(model.cells) do
            widest = math.max(widest, measure(panel, cell[1], 13),
                measure(panel, cell[2]:upper(), 9))
        end
        consider((widest + 16) * #model.cells)
    end
    for _, list in ipairs({ model.details, model.requirements }) do
        for _, row in ipairs(list) do consider(ui.rowWidth(panel, row, 11)) end
    end
    for _, sentence in ipairs(sentences) do
        consider(math.min(measure(panel, sentence, 12), ui.PROSE_WIDTH))
    end
    for _, row in ipairs(model.extras) do
        local width = ui.rowWidth(panel, row, 11)
        if not row.right or row.right == "" then width = math.min(width, ui.PROSE_WIDTH) end
        consider(width)
    end
    return math.max(ui.MIN_WIDTH, math.min(ui.MAX_WIDTH, math.ceil(need + 2 * PAD)))
end

local function drawStrip(panel, model, y, color)
    local cellWidth = (panel.width - 2 * PAD) / #model.cells
    for index, cell in ipairs(model.cells) do
        local x = PAD + (index - 1) * cellWidth
        local valueColor = TITLE_COLOR
        local power = cell == model.cost and POWER_COLORS[model.power]
        if power then
            valueColor = { power[1] * .45 + .55, power[2] * .45 + .55, power[3] * .45 + .55 }
        end
        textAt(panel, cell[1], x, y, cellWidth, 13, valueColor, nil, "CENTER")
        textAt(panel, cell[2]:upper(), x, y + 17, cellWidth, 9, CAPTION_COLOR, nil, "CENTER")
        if index > 1 then
            local separator = ui.acquireTexture(panel)
            separator:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -(y + 2))
            separator:SetSize(1, STRIP_HEIGHT - 8)
            separator:SetVertexColor(color[1] * .6, color[2] * .6, color[3] * .6, .5)
        end
    end
    return y + STRIP_HEIGHT
end

local function renderSpell(panel, tooltip, model)
    panel:Show()
    ui.clearPool(panel)
    local title = model.name:find("|", 1, true) and model.name or model.name:upper()
    local sentences = {}
    for _, text in ipairs(model.description) do
        for _, sentence in ipairs(splitSentences(text)) do sentences[#sentences + 1] = sentence end
    end
    model.school = detectSchool(model)
    panel.width = fitWidth(panel, model, title, sentences)
    panel:SetWidth(panel.width)
    local power = model.power and POWER_COLORS[model.power]
    local accent = model.school and SCHOOL_COLORS[model.school] or power
    local color = accent or NEUTRAL
    local headerMin = ui.drawChrome(panel, tooltip, {
        color = color,
        tint = accent,
        strength = SPELL_TINT,
        icon = model.icon,
        iconSize = ICON_SIZE,
    })

    local inner = panel.width - 2 * PAD
    local y = ui.TITLE_TOP
    local indent = model.icon and TEXT_INDENT or 0
    local face, fakeBold = ui.titleFont()
    y = y + textAt(panel, title, PAD + indent, y, inner - indent, 17, TITLE_COLOR,
        face, nil, fakeBold) + 4
    local list = pills(model)
    if #list > 0 then y = drawPills(panel, list, PAD + indent, y + 1) + 4 end
    y = math.max(y + 6, headerMin)
    panel.header:SetHeight(y - panel.inset)
    panel.footer:SetHeight(0)

    local sectioned = false
    if #model.cells > 0 or #model.details > 0 or #model.requirements > 0
        or #sentences > 0 then
        y = ui.divider(panel, y, ui.GOLD_RULE)
        if #model.cells > 0 then
            y = drawStrip(panel, model, y, color) + 2
        end
        if #model.details > 0 or #model.requirements > 0 then
            y = ui.drawGroup(panel, model.requirements, y + 2, 11, { .82, .78, .71 }, 0, 2)
            y = ui.drawGroup(panel, model.details, y, 11, { .82, .78, .71 }, 0, 2)
        end
        if #sentences > 0 then
            if #model.cells > 0 or #model.details > 0 or #model.requirements > 0 then
                y = ui.rule(panel, y + 6, { color[1] * .7, color[2] * .7, color[3] * .7 })
            end
            local school = model.school and SCHOOL_COLORS[model.school]
            local numberCode = school
                and hex({ school[1] * .7 + .3, school[2] * .7 + .3, school[3] * .7 + .3 })
                or "FFF6E4"
            for _, sentence in ipairs(sentences) do
                y = ui.drawRow(panel, { left = colorNumbers(sentence, numberCode) },
                    y, 12, DESCRIPTION_COLOR, 0, 5)
            end
        end
        sectioned = true
    end

    if #model.extras > 0 then
        if sectioned then
            y = ui.rule(panel, y + 8, { .50, .50, .54 })
        else
            y = y + 12
        end
        y = ui.drawGroup(panel, model.extras, y, 11, ui.EXTRA_COLOR, 0, 2)
    end
    ui.finishPanel(panel, tooltip, y)
end

ui.registerKind(SPELL, { read = readSpell, render = renderSpell, key = spellKey })
