-- Draws a view: a plain table that says what a panel shows, which a tooltip
-- type's view function builds from its model. The width is fitted to what the
-- view holds, so measuring and drawing cannot disagree.
--
-- view = {
--     tooltipType = "aura",              backdrop and header settings by type
--     color, tint, strength,             the accent; the header's tint and its strength
--     icon, iconSize,                    header lines start beside the icon
--     header = {                         in order, beside the icon
--         { text = "Name", style = styles.auraName, color = TITLE, gap = 4 },
--         { badges = { { "Buff", BLUE } }, style = styles.auraBadges, before = 1, gap = 4 },
--     },
--     sections = {                       in order, below the header
--         { separator = { divider = GOLD } | { rule = color, before = 8 } | { space = 4 },
--           kind = "prose", sentences = { ... }, style, color, numbers = "FFF6E4", gap = 5 },
--         { kind = "rows", rows = { { left, right, color, rightColor } }, style, color, gap = 2,
--           wrap = true },             rows with nothing on the right wrap at prose width
--         { kind = "timer", duration = 30, expires = 1234.5, color = BLUE },
--     },
-- }
local _, ns = ...
local ui = ns.ui
if not ui then return end

local util = ns.util
local PAD = ui.PAD
local BADGE_HEIGHT = 16
local BADGE_GAP = 6
local BAR_HEIGHT = 4
local TRACK = { .16, .14, .13 }

-- Badges -----------------------------------------------------------------------

local function badgesWidth(panel, list, style)
    local width = 0
    for index, badge in ipairs(list) do
        width = width + ui.measureStyled(panel, badge[1], style) + 12 + (index > 1 and BADGE_GAP or 0)
    end
    return width
end

local function drawBadges(panel, list, x, y, style)
    local height = math.max(BADGE_HEIGHT, style.size + 6)
    for _, badge in ipairs(list) do
        local text, color = badge[1], badge[2]
        local width = ui.measureStyled(panel, text, style) + 12
        local border = ui.acquireTexture(panel, nil, -2)
        border:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y)
        border:SetSize(width, height)
        border:SetVertexColor(color[1] * .8, color[2] * .8, color[3] * .8, .9)
        local fill = ui.acquireTexture(panel, nil, -1)
        fill:SetPoint("TOPLEFT", border, "TOPLEFT", 1, -1)
        fill:SetSize(width - 2, height - 2)
        fill:SetVertexColor(color[1] * .14, color[2] * .14, color[3] * .14, 1)
        ui.styledAt(panel, text, x, y + math.floor((height - style.size) / 2), width, style,
            { color[1] * .45 + .55, color[2] * .45 + .55, color[3] * .45 + .55 }, "CENTER")
        x = x + width + BADGE_GAP
    end
    return y + height
end

-- Timers: bars that drain as an aura runs out ----------------------------------------

local timers = setmetatable({}, { __mode = "k" })

local function drawTimerFill(timer)
    local left = math.max(0, timer.expires - GetTime())
    local ratio = math.max(0, math.min(1, left / timer.duration))
    timer.fill:SetWidth(math.max(1, timer.width * ratio))
    timer.fill:SetShown(ratio > 0)
end

local ticker = CreateFrame("Frame")
local elapsedSince = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < .1 then return end
    elapsedSince = 0
    for panel, timer in pairs(timers) do
        if panel:IsShown() then drawTimerFill(timer) else timers[panel] = nil end
    end
end)

-- Sections -------------------------------------------------------------------------

local function indentOf(view)
    return view.icon and view.iconSize + 10 or 0
end

-- The widest thing the view holds, plus the panel's padding, within the limits.
local function fitWidth(panel, view)
    local indent, need = indentOf(view), 0
    local function consider(width) if width > need then need = width end end
    for _, item in ipairs(view.header) do
        if item.text then
            consider(ui.measureStyled(panel, item.text, item.style) + indent)
        elseif item.badges and #item.badges > 0 then
            consider(badgesWidth(panel, item.badges, item.style) + indent)
        end
    end
    for _, section in ipairs(view.sections) do
        if section.kind == "prose" then
            for _, sentence in ipairs(section.sentences) do
                consider(math.min(ui.measureStyled(panel, sentence, section.style), ui.PROSE_WIDTH))
            end
        elseif section.kind == "rows" then
            for _, row in ipairs(section.rows) do
                local width = ui.rowWidth(panel, row, section.style)
                if section.wrap and (not row.right or row.right == "") then width = math.min(width, ui.PROSE_WIDTH) end
                consider(width)
            end
        end
    end
    return math.max(ui.MIN_WIDTH, math.min(ui.MAX_WIDTH, math.ceil(need + 2 * PAD)))
end

local function drawSeparator(panel, y, separator)
    if not separator then return y end
    if separator.divider then return ui.divider(panel, y, separator.divider, separator.before) end
    if separator.rule then return ui.rule(panel, y, separator.rule, separator.before) end
    return y + (separator.space or 0)
end

local DRAW = {
    prose = function(panel, y, section)
        for _, sentence in ipairs(section.sentences) do
            local text = section.numbers and util.colorNumbers(sentence, section.numbers) or sentence
            y = ui.drawRow(panel, { left = text }, y, section.style, section.color, 0, section.gap)
        end
        return y
    end,
    rows = function(panel, y, section)
        return ui.drawGroup(panel, section.rows, y, section.style, section.color, section.indent or 0, section.gap)
    end,
    timer = function(panel, y, section)
        local width = panel.width - 2 * PAD
        local track = ui.acquireTexture(panel, nil, 0)
        track:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
        track:SetSize(width, BAR_HEIGHT)
        track:SetVertexColor(TRACK[1], TRACK[2], TRACK[3], 1)
        local color = section.color
        local timer = { width = width, duration = section.duration, expires = section.expires }
        timer.fill = ui.acquireTexture(panel, nil, 1)
        timer.fill:SetPoint("TOPLEFT", track, "TOPLEFT")
        timer.fill:SetHeight(BAR_HEIGHT)
        timer.fill:SetVertexColor(color[1], color[2], color[3], 1)
        drawTimerFill(timer)
        timers[panel] = timer
        return y + BAR_HEIGHT + 8
    end,
}

-- The panel ---------------------------------------------------------------------

local function renderView(panel, tooltip, view)
    panel:Show()
    ui.clearPool(panel)
    timers[panel] = nil
    panel.width = fitWidth(panel, view)
    panel:SetWidth(panel.width)
    local headerMin = ui.drawChrome(panel, tooltip, {
        tooltipType = view.tooltipType,
        color = view.color,
        tint = view.tint,
        strength = view.strength,
        icon = view.icon,
        iconSize = view.iconSize,
    })

    local indent = indentOf(view)
    local leftIndent = ui.headerInsets(indent)
    local inner = panel.width - 2 * PAD
    local y = ui.TITLE_TOP
    for _, item in ipairs(view.header) do
        if item.text then
            y = y + ui.styledAt(panel, item.text, PAD + leftIndent, y, inner - indent, item.style, item.color)
                + item.gap
        elseif item.badges and #item.badges > 0 then
            y = drawBadges(panel, item.badges, PAD + leftIndent, y + (item.before or 0), item.style) + item.gap
        end
    end
    y = math.max(y + 6, headerMin)
    panel.header:SetHeight(y - panel.inset)
    panel.footer:SetHeight(0)

    for _, section in ipairs(view.sections) do
        y = drawSeparator(panel, y, section.separator)
        y = DRAW[section.kind](panel, y, section)
    end
    ui.finishPanel(panel, tooltip, y)
end

ui.renderView = renderView
ui.drawBadges, ui.badgesWidth = drawBadges, badgesWidth
