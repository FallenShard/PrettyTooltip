-- Macros as a panel: the name, then the macro's lines, in the color of the
-- spell it casts. One with #showtooltip is the spell's panel instead, with the
-- macro named in its subtitle.
local _, ns = ...
local ui = ns.ui
local MACRO = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Macro
if not (ui and MACRO and ui.renderView) then
    return
end

local util = ns.util
local tooltipData = ns.TooltipData
local colors = ns.Palette.roles
local isSecret, safeText, trim = util.isSecret, util.safeText, util.trim
local ICON_SIZE = 38
local TINT_STRENGTH = .7
local EXTRAS_RULE = { .50, .50, .54 }
local COMMAND = util.hex(colors.quest)
local MUTED = util.hex(colors.caption)
local PARTS = { "macroName", "macroBadges", "macroText", "extras" }
local CASTS = { ["#showtooltip"] = true, ["/cast"] = true, ["/use"] = true }
local SPELL = Enum.TooltipDataType.Spell
local NESTED = Enum.TooltipDataLineType and Enum.TooltipDataLineType.NestedBlock

-- With #showtooltip, the game fills the macro's tooltip with the spell it
-- shows: a nested block naming it, then the spell's own lines.
local function shownSpell(data)
    if not NESTED then return end
    for index, line in ipairs(data.lines) do
        if isSecret(line) or type(line) ~= "table" or isSecret(line.type) then return end
        if line.type == NESTED then
            local id, kind = line.tooltipID, line.tooltipType
            if isSecret(id) or isSecret(kind) or kind ~= SPELL or type(id) ~= "number" then return end
            local lines = {}
            for after = index + 1, #data.lines do lines[#lines + 1] = data.lines[after] end
            return { type = SPELL, id = id, lines = lines }
        end
    end
end

local function macroKey(_, data)
    if isSecret(data.lines) or type(data.lines) ~= "table" then return end
    local spell = shownSpell(data)
    if spell then return "spell" .. spell.id end
    local line = data.lines[1]
    if isSecret(line) or type(line) ~= "table" then return end
    return safeText(line.leftText)
end

-- The spell a macro shows or casts: its first option, without conditions or rank.
local function spellOf(body)
    for _, line in ipairs(body) do
        local command, rest = line:match("^([/#]%a+)%s+(.+)$")
        if command and CASTS[command:lower()] then
            local spell = trim((rest:gsub("%b[]", ""):match("^%s*([^;]*)") or ""):gsub("%(.-%)", ""))
            if spell ~= "" then return spell end
        end
    end
end

local function completeModel(model)
    model.extras = model.extras or {}
    model.body = model.body or {}
    model.spell = model.spell or spellOf(model.body)
    return model
end

local function readMacro(tooltip, data, game)
    if isSecret(data) or not data or isSecret(data.lines) or not data.lines then return end
    local spell = shownSpell(data)
    if spell then
        local spellType = ns.TooltipTypes[SPELL]
        local shown = spellType and spellType.read(tooltip, spell, game)
        if not shown then return end
        local name = game.macroShowing(spell.id)
        shown.tag = name and ("Macro: " .. name) or "Macro"
        return { shows = shown }
    end
    local model = { extras = {}, lineIndices = {}, body = {} }
    for _, line in ipairs(data.lines) do
        if isSecret(line) or not line or isSecret(line.lineIndex) then return end
        if line.lineIndex then
            local left, right = safeText(line.leftText), safeText(line.rightText)
            if not left or not right then return end
            model.lineIndices[line.lineIndex] = true
            if not model.name then
                model.name = trim(left)
            elseif trim(left) ~= "" or right ~= "" then
                tooltipData.add(model.extras, left, right)
                local row = model.extras[#model.extras]
                row.color, row.rightColor = tooltipData.colorOf(line.leftColor), tooltipData.colorOf(line.rightColor)
            end
        end
    end
    if not model.name or model.name == "" then return end
    local appended = tooltipData.appendedRows(tooltip, model.lineIndices)
    if not appended then return end
    for _, row in ipairs(appended) do
        if trim(row.left) ~= "" or row.right ~= "" then model.extras[#model.extras + 1] = row end
    end
    -- The tooltip has only the name; the macro itself has its icon and lines.
    local macro = game.macro(model.name)
    if macro then
        model.icon = macro.icon
        for line in (macro.body .. "\n"):gmatch("(.-)\n") do
            line = trim(line)
            if line ~= "" then model.body[#model.body + 1] = line end
        end
    end
    return completeModel(model)
end

-- Commands in gold; directives such as #showtooltip and [conditions] muted.
local function styleLine(line)
    line = line:gsub("|", "||")
    local command, rest = line:match("^([/#]%S+)(.*)$")
    if not command then return line end
    rest = rest:gsub("%b[]", function(condition) return "|cff" .. MUTED .. condition .. "|r" end)
    return "|cff" .. (command:sub(1, 1) == "#" and MUTED or COMMAND) .. command .. "|r" .. rest
end

local function macroView(model)
    local styles = {}
    for _, key in ipairs(PARTS) do styles[key] = ui.styleOf(key) end
    local school = model.spell and ns.spellSchools and ns.spellSchools[model.spell]
    local accent = school and ns.Palette.schools[school]
    local color = accent or colors.neutral
    local sections = {}
    if #model.body > 0 then
        local rows = {}
        for index, line in ipairs(model.body) do rows[index] = { left = styleLine(line), right = "" } end
        sections[1] = { separator = { divider = ui.GOLD_RULE }, kind = "rows", rows = rows,
            style = styles.macroText, color = colors.detail, gap = 2, wrap = true }
    end
    if #model.extras > 0 then
        sections[#sections + 1] = { separator = #sections > 0 and { rule = EXTRAS_RULE, before = 8 } or { space = 4 },
            kind = "rows", rows = model.extras, style = styles.extras, color = ui.EXTRA_COLOR, gap = 2, wrap = true }
    end
    return {
        tooltipType = "macro",
        color = color,
        tint = accent,
        strength = TINT_STRENGTH,
        icon = ns.option("iconMacros") and model.icon or nil,
        iconSize = ICON_SIZE,
        header = {
            { text = model.name, style = styles.macroName, color = colors.title, gap = 4 },
            { badges = { { "Macro", colors.caption } }, style = styles.macroBadges, before = 1, gap = 4 },
        },
        sections = sections,
    }
end

local function renderMacro(panel, tooltip, model)
    if model.shows then
        ns.TooltipTypes[SPELL].render(panel, tooltip, model.shows)
    else
        ui.renderView(panel, tooltip, macroView(model))
    end
end

ui.macroModel = completeModel
ui.defineTooltipType(MACRO, { read = readMacro, render = renderMacro, key = macroKey, option = "macroPanels" })
