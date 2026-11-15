-- The minimap's tooltip as a panel: the game's text as it wrote it, names,
-- greys and arrows included. Forever keeps that text secret, so the panel
-- shows it unread, at the size the game's own tooltip took for it.
local _, ns = ...
local ui = ns.ui
local MINIMAP = Enum and Enum.TooltipDataType and Enum.TooltipDataType.MinimapMouseover
if not (ui and MINIMAP and ui.renderView) then
    return
end

local util = ns.util
local tooltipData = ns.TooltipData
local colors = ns.Palette.roles
local isSecret, safeText, trim = util.isSecret, util.safeText, util.trim
local EXTRAS_RULE = { .50, .50, .54 }
-- The game's tooltip pads its lines this much on each side, when its frame
-- will not say.
local NATIVE_PAD = 10
-- The game's color for its minimap line, secret with the text: every capture
-- has it, retail's too. Greys come as color codes in the text.
local NATIVE_COLOR = { 1, .82, 0 }

local function minimapKey(_, data)
    if isSecret(data.lines) or type(data.lines) ~= "table" then return end
    local parts = {}
    for _, line in ipairs(data.lines) do
        if isSecret(line) or type(line) ~= "table" then return end
        local text = safeText(line.leftText)
        if not text then return end
        parts[#parts + 1] = text
    end
    return table.concat(parts, "\n")
end

-- The room the game's tooltip gives its one line, which the panel cannot
-- measure: the tooltip's size less its padding, and the line's font.
local function nativeBlock(tooltip)
    local line = tooltip:GetLeftLine(1)
    if not line then return end
    local width = util.number((util.call(tooltip.GetWidth, tooltip)))
    local height = util.number((util.call(tooltip.GetHeight, tooltip)))
    local path, size, flags = util.call(line.GetFont, line)
    if not (width and height and type(path) == "string" and util.number(size) and size > 0) then return end
    local padX, padY = NATIVE_PAD, NATIVE_PAD
    local left, top = util.number((util.call(line.GetLeft, line))), util.number((util.call(line.GetTop, line)))
    local outerLeft = util.number((util.call(tooltip.GetLeft, tooltip)))
    local outerTop = util.number((util.call(tooltip.GetTop, tooltip)))
    if left and outerLeft and left - outerLeft > 0 and left - outerLeft < 30 then padX = left - outerLeft end
    if top and outerTop and outerTop - top > 0 and outerTop - top < 30 then padY = outerTop - top end
    width, height = width - 2 * padX, height - 2 * padY
    if width <= 0 or height <= 0 then return end
    return { width = width, height = height, path = path, size = size,
        flags = type(flags) == "string" and flags or "", spacing = util.number((util.call(line.GetSpacing, line))) or 0 }
end

local function readMinimap(tooltip, data)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local model = { lines = {}, extras = {}, lineIndices = {} }
    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.lineIndex) then return end
        if line.lineIndex then
            model.lineIndices[line.lineIndex] = true
            model.color = model.color or util.rgb(line.leftColor) or NATIVE_COLOR
            local text = line.leftText
            if isSecret(text) then
                -- One secret line, which the tooltip's size is all of.
                if #data.lines > 1 or tooltip:NumLines() > 1 then return end
                model.hidden, model.block = text, nativeBlock(tooltip)
                if not model.block then return end
                return model
            end
            text = safeText(text)
            if not text then return end
            -- Blips close together share a line, one name each.
            for part in (text:gsub("|n", "\n") .. "\n"):gmatch("(.-)\n") do
                if trim(util.plainText(part)) ~= "" then model.lines[#model.lines + 1] = trim(part) end
            end
        end
    end
    if #model.lines == 0 then return end
    local appended = tooltipData.appendedRows(tooltip, model.lineIndices)
    if not appended then return end
    tooltipData.addExtras(model.extras, appended)
    return model
end

-- The secret text in the game's font at the game's size, as only that fills
-- the room the game measured: scaled, a name a pixel short wraps.
local function hiddenSection(model)
    local block = model.block
    local font = { path = block.path, size = block.size, flags = block.flags, spacing = block.spacing }
    -- A few pixels over, for the game's rounding.
    local width, height = math.ceil(block.width) + 4, math.ceil(block.height)
    return { kind = "custom", measure = function() return width end, draw = function(panel, y)
        ui.hiddenBlockAt(panel, model.hidden, ui.pad(), y, panel.width - 2 * ui.pad(), font, model.color)
        panel.rowTail = 3
        return y + height
    end }
end

-- The game's text as it wrote it, in its color: the panel adds only its frame.
local function minimapView(model)
    local sections
    if model.hidden then
        sections = { hiddenSection(model) }
    else
        local style = {}
        for key, value in pairs(ui.styleOf("objectDetails")) do style[key] = value end
        style.color = nil
        local rows = {}
        for index, text in ipairs(model.lines) do rows[index] = { left = text } end
        sections = { { kind = "rows", rows = rows, style = style, color = model.color, gap = 3 } }
    end
    if #model.extras > 0 then
        sections[2] = { separator = { rule = EXTRAS_RULE }, kind = "rows", rows = model.extras,
            style = ui.styleOf("extras"), color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    return { tooltipType = "object", color = colors.neutral, header = {}, sections = sections, minWidth = 0 }
end

local function renderMinimap(panel, tooltip, model)
    ui.renderView(panel, tooltip, minimapView(model))
end

ui.defineTooltipType(MINIMAP, { read = readMinimap, render = renderMinimap, key = minimapKey,
    option = "minimapPanels", followsNativeSize = true })
