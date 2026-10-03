-- Buffs and debuffs as a panel.
local _, ns = ...
local ui = ns.ui
local AURA = Enum and Enum.TooltipDataType and Enum.TooltipDataType.UnitAura
if not (ui and AURA and ui.drawPills and ui.splitSentences) then
    return
end

local isSecret, safeText = ui.isSecret, ui.safeText
local PAD = ui.PAD
local ICON_SIZE = 38
local TEXT_INDENT = ICON_SIZE + 10
local TINT_STRENGTH = .7
local BAR_HEIGHT = 4
local TITLE_COLOR = { .96, .92, .84 }
local TEXT_COLOR = { .92, .87, .76 }
local TIME_COLOR = { .88, .78, .60 }
local BUFF_COLOR = { .45, .75, .95 }
local DEBUFF_COLOR = { .90, .30, .25 }
local MUTED = { .60, .57, .52 }
-- The game's dispel colors.
local DISPELS = {
    Magic = { .20, .60, 1 },
    Curse = { .60, 0, 1 },
    Disease = { .60, .40, 0 },
    Poison = { 0, .60, 0 },
}
local PARTS = { "auraName", "auraBadges", "auraText", "auraTime", "extras" }

local function trim(text)
    return text:match("^%s*(.-)%s*$")
end

local function readable(value)
    if isSecret(value) then return nil end
    return value
end

-- The tooltip's lines lack the duration and stacks; the aura it shows has them.
-- The getter is known only while the game fills the tooltip, so the aura is
-- kept for the redraws after.
local function auraOf(tooltip, spellID)
    local info = tooltip.GetProcessingTooltipInfo and tooltip:GetProcessingTooltipInfo()
    if not (info and C_UnitAuras) or isSecret(info) then
        local kept = tooltip.prettyTooltipAura
        return kept and kept.spellID == spellID and kept.aura or nil
    end
    local getter, args = readable(info.getterName), readable(info.getterArgs)
    if type(getter) ~= "string" or type(args) ~= "table" then return end
    local unit, which, filter = readable(args[1]), readable(args[2]), readable(args[3])
    if type(unit) ~= "string" or which == nil then return end
    local ok, aura
    if getter:find("AuraInstanceID") and C_UnitAuras.GetAuraDataByAuraInstanceID then
        ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, which)
    elseif C_UnitAuras.GetAuraDataByIndex then
        if getter:find("Buff") then filter = "HELPFUL" elseif getter:find("Debuff") then filter = "HARMFUL" end
        ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, which, filter)
    end
    if not ok or isSecret(aura) or type(aura) ~= "table" then return end
    tooltip.prettyTooltipAura = { spellID = spellID, aura = aura }
    return aura
end

local function auraKey(_, data)
    if isSecret(data.id) or isSecret(data.dataInstanceID) then return end
    return data.id
end

local function completeModel(model, aura)
    if aura then
        model.harmful = readable(aura.isHarmful)
        if model.harmful == nil and readable(aura.isHelpful) ~= nil then model.harmful = not aura.isHelpful end
        model.stacks = readable(aura.applications)
        model.duration = readable(aura.duration)
        model.expires = readable(aura.expirationTime)
        local source = readable(aura.sourceUnit)
        if type(source) == "string" and UnitName then
            local ok, name = pcall(UnitName, source)
            if ok and not isSecret(name) and type(name) == "string" then model.caster = name end
        end
        model.dispel = model.dispel or readable(aura.dispelName)
    end
    local dispel = model.dispel and DISPELS[model.dispel]
    model.color = dispel or (model.harmful and DEBUFF_COLOR) or (model.harmful == false and BUFF_COLOR) or nil
    return model
end

local function readAura(tooltip, data)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local spellID = readable(data.id)
    local model = { description = {}, extras = {}, lineIndices = {}, icon = ui.getSpellIcon(spellID) }
    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.lineIndex) then return end
        if line.lineIndex then
            local left, right = safeText(line.leftText), safeText(line.rightText)
            if not left or not right then return end
            model.lineIndices[line.lineIndex] = true
            local text = trim(left)
            if not model.name then
                model.name = text
                if DISPELS[trim(right)] then model.dispel = trim(right) end
            elseif text ~= "" or right ~= "" then
                if text:match("remaining$") then
                    model.remaining = text
                elseif text ~= "" and not model.text then
                    model.text = text
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
    return completeModel(model, auraOf(tooltip, spellID))
end

local function badges(model)
    local list = {}
    if model.harmful ~= nil then
        list[#list + 1] = model.harmful and { "Debuff", DEBUFF_COLOR } or { "Buff", BUFF_COLOR }
    end
    if model.dispel and DISPELS[model.dispel] then list[#list + 1] = { model.dispel, DISPELS[model.dispel] } end
    if type(model.stacks) == "number" and model.stacks > 1 then
        list[#list + 1] = { model.stacks .. " stacks", MUTED }
    end
    return list
end

local function sentencesOf(model)
    local list = {}
    if model.text then
        for _, sentence in ipairs(ui.splitSentences(model.text)) do list[#list + 1] = sentence end
    end
    return list
end

local function timeRow(model)
    local left = model.remaining
    if not left and type(model.duration) == "number" and model.duration == 0 then left = "No time limit" end
    if not left and not model.caster then return end
    return { left = left or "", right = model.caster and ("by " .. model.caster) or "" }
end

local function hasBar(model)
    return type(model.duration) == "number" and model.duration > 0 and type(model.expires) == "number"
end

local function fitWidth(panel, model, styles, sentences)
    local indent = model.icon and TEXT_INDENT or 0
    local need = ui.measureStyled(panel, model.name, styles.auraName) + indent
    local function consider(width) if width > need then need = width end end
    local list = badges(model)
    if #list > 0 then consider(ui.pillsWidth(panel, list, styles.auraBadges) + indent) end
    for _, sentence in ipairs(sentences) do
        consider(math.min(ui.measureStyled(panel, sentence, styles.auraText), ui.PROSE_WIDTH))
    end
    local time = timeRow(model)
    if time then consider(ui.rowWidth(panel, time, styles.auraTime)) end
    for _, row in ipairs(model.extras) do
        local width = ui.rowWidth(panel, row, styles.extras)
        if not row.right or row.right == "" then width = math.min(width, ui.PROSE_WIDTH) end
        consider(width)
    end
    return math.max(ui.MIN_WIDTH, math.min(ui.MAX_WIDTH, math.ceil(need + 2 * PAD)))
end

local live = setmetatable({}, { __mode = "k" })

local function drawBarFill(view)
    local left = math.max(0, view.expires - GetTime())
    local ratio = math.max(0, math.min(1, left / view.duration))
    view.fill:SetWidth(math.max(1, view.width * ratio))
    view.fill:SetShown(ratio > 0)
end

local updater = CreateFrame("Frame")
local elapsedSince = 0
updater:SetScript("OnUpdate", function(_, elapsed)
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < .1 then return end
    elapsedSince = 0
    for panel, view in pairs(live) do
        if panel:IsShown() then drawBarFill(view) else live[panel] = nil end
    end
end)

local function renderAura(panel, tooltip, model)
    panel:Show()
    ui.clearPool(panel)
    live[panel] = nil
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    if not ns.option("iconAuras") then model.icon = nil end
    local sentences = sentencesOf(model)
    panel.width = fitWidth(panel, model, styles, sentences)
    panel:SetWidth(panel.width)
    local color = model.color or { .62, .66, .74 }
    local headerMin = ui.drawChrome(panel, tooltip, {
        kind = "aura",
        color = color,
        tint = model.color,
        strength = TINT_STRENGTH,
        icon = model.icon,
        iconSize = ICON_SIZE,
    })

    local inner = panel.width - 2 * PAD
    local indent = model.icon and TEXT_INDENT or 0
    local leftIndent = ui.headerInsets(indent)
    local y = ui.TITLE_TOP
    y = y + ui.styledAt(panel, model.name, PAD + leftIndent, y, inner - indent, styles.auraName,
        TITLE_COLOR) + 4
    local list = badges(model)
    if #list > 0 then y = ui.drawPills(panel, list, PAD + leftIndent, y + 1, styles.auraBadges) + 4 end
    y = math.max(y + 6, headerMin)
    panel.header:SetHeight(y - panel.inset)
    panel.footer:SetHeight(0)

    local sectioned = false
    if #sentences > 0 then
        y = ui.divider(panel, y, ui.GOLD_RULE)
        local numberCode = ui.hex({ color[1] * .7 + .3, color[2] * .7 + .3, color[3] * .7 + .3 })
        for _, sentence in ipairs(sentences) do
            y = ui.drawRow(panel, { left = ui.colorNumbers(sentence, numberCode) }, y, styles.auraText,
                TEXT_COLOR, 0, 5)
        end
        sectioned = true
    end
    local time = timeRow(model)
    if time or hasBar(model) then
        y = sectioned and ui.rule(panel, y, { color[1] * .7, color[2] * .7, color[3] * .7 }, 4)
            or ui.divider(panel, y, ui.GOLD_RULE)
        if time then
            time.rightColor = MUTED
            y = ui.drawRow(panel, time, y, styles.auraTime, TIME_COLOR, 0, 3)
        end
        if hasBar(model) then
            local track = ui.acquireTexture(panel, nil, 0)
            track:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
            track:SetSize(inner, BAR_HEIGHT)
            track:SetVertexColor(.16, .14, .13, 1)
            local view = { width = inner, duration = model.duration, expires = model.expires }
            view.fill = ui.acquireTexture(panel, nil, 1)
            view.fill:SetPoint("TOPLEFT", track, "TOPLEFT")
            view.fill:SetHeight(BAR_HEIGHT)
            view.fill:SetVertexColor(color[1], color[2], color[3], 1)
            drawBarFill(view)
            live[panel] = view
            y = y + BAR_HEIGHT + 8
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
end

ui.auraModel = function(fields)
    fields.extras = fields.extras or {}
    return completeModel(fields)
end
ui.registerKind(AURA, { read = readAura, render = renderAura, key = auraKey, option = "auraPanels" })
