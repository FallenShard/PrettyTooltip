-- Item wording for the panel and, shortened, for the game's own tooltip, with
-- modifier-key restoration.
local _, ns = ...
local isSecret = ns.util.isSecret
local util = ns.util
local stats = ns.Stats
local LINE = Enum and Enum.TooltipDataLineType or {}
ns.ItemLite = {}
local registered = false

local activeLinesByTooltip = setmetatable({}, { __mode = "k" })
local hookedTooltips = setmetatable({}, { __mode = "k" })

local function onItemTooltip(tooltip, data)
    if not util.canModify(tooltip) then return end
    if not (ns.restyles("itemPanels") or ns.option("liteWording")) then return end
    if isSecret(data) or type(data) ~= "table" then return end
    local lines = data.lines
    if isSecret(lines) or type(lines) ~= "table" then return end

    -- Keep the line table and its length intact. Other addons may have added
    -- rows to the same cached tooltip data since our previous pass.
    for index, source in ipairs(lines) do
        if not isSecret(source) and type(source) == "table"
            and not isSecret(source.prettyTooltipOriginal) and not source.prettyTooltipOriginal then
            local text = source.leftText
            local rightText = source.rightText
            if not isSecret(text) and type(text) == "string"
                and not isSecret(rightText) and not rightText then
                local replacements = stats.rewrite(text)
                local displayLines = replacements or { text }
                -- Lite shortens wording and keeps the game's colors, but for
                -- magic: spell power rows and what a proc deals, in their colors.
                local liteLines = {}
                local styled = false
                -- The game marks proc lines; the text is the fallback for clients that do not.
                local proc = LINE.ItemSpellTriggerOnProc and not isSecret(source.type)
                    and source.type == LINE.ItemSpellTriggerOnProc
                for displayIndex, displayText in ipairs(displayLines) do
                    local display, colored = stats.styleStat(displayText, ns.option("statColors"), ns.option("statMarkers"))
                    local onHit = proc or ns.util.startsWith(displayText, ITEM_SPELL_TRIGGER_ONPROC)
                    if onHit then
                        local effect = stats.styleEffect(displayText, ns.option("statColors"))
                        if effect ~= displayText then display, colored = effect, effect end
                    end
                    local magical = onHit or stats.isMagical(displayText)
                    liteLines[displayIndex] = colored and magical and ns.option("statColors") and colored or displayText
                    if colored then
                        displayLines[displayIndex] = display
                        styled = true
                    end
                end
                if replacements or styled then
                    local copy = {}
                    for key, value in pairs(source) do
                        copy[key] = value
                    end
                    -- A line break gives combined bonuses two visual lines
                    -- while preserving every other addon's tooltip row.
                    copy.leftText = table.concat(displayLines, "|n")
                    copy.wrapText = util.readable(copy.wrapText) or #displayLines > 1
                    copy.prettyTooltipOriginal = text
                    copy.prettyTooltipDisplay = copy.leftText
                    copy.prettyTooltipLite = table.concat(liteLines, "|n")
                    copy.lineIndex = nil
                    lines[index] = copy
                end
            end
        end
    end
end

-- The rewrite above changes the game's own tooltip text too, so its font
-- strings get the wording that suits: the original while the original-tooltip
-- key is held, the panel's under a panel, else the shortened wording in native
-- colors but for magic.
local function wordingShown()
    if ns.originalKeyDown() then return "original" end
    if ns.restyles("itemPanels") then return "display" end
    return ns.option("liteWording") and "lite" or "original"
end

local function showWording(tooltip, wording, relayout)
    if not util.canModify(tooltip) then return end
    local rows = activeLinesByTooltip[tooltip]
    if not rows then return end
    for _, row in ipairs(rows) do
        if not util.canModify(row.fontString) then return end
        local ok = pcall(row.fontString.SetText, row.fontString, row[wording] or row.original)
        if not ok then return end
    end
    if relayout then tooltip:Show() end
end

local function onItemShown(tooltip, data)
    if not util.canModify(tooltip) then return end
    if isSecret(data) or type(data) ~= "table" then return end
    local lines = data.lines
    if isSecret(lines) or type(lines) ~= "table" then return end

    if not hookedTooltips[tooltip] then
        local function forget(cleared) activeLinesByTooltip[cleared] = nil end
        tooltip:HookScript("OnHide", forget)
        tooltip:HookScript("OnTooltipCleared", forget)
        hookedTooltips[tooltip] = true
    end

    local info = util.call(tooltip.GetProcessingTooltipInfo, tooltip)
    local append = type(info) == "table" and util.readable(info.append)
    local rows = (append and activeLinesByTooltip[tooltip]) or {}
    for _, line in ipairs(lines) do
        if isSecret(line) or type(line) ~= "table" or isSecret(line.lineIndex)
            or isSecret(line.prettyTooltipOriginal) or isSecret(line.prettyTooltipDisplay)
            or isSecret(line.prettyTooltipLite) then return end
        if line.lineIndex ~= nil and type(line.lineIndex) ~= "number" then return end
        for _, key in ipairs({ "prettyTooltipOriginal", "prettyTooltipDisplay", "prettyTooltipLite" }) do
            if line[key] ~= nil and type(line[key]) ~= "string" then return end
        end
        if line.lineIndex and line.prettyTooltipOriginal then
            local fontString = tooltip:GetLeftLine(line.lineIndex)
            if fontString then
                rows[#rows + 1] = {
                    fontString = fontString,
                    original = line.prettyTooltipOriginal,
                    display = line.prettyTooltipDisplay,
                    lite = line.prettyTooltipLite,
                }
            end
        end
    end
    activeLinesByTooltip[tooltip] = #rows > 0 and rows or nil
    -- Cached data can still carry wording rewritten before items were turned off.
    showWording(tooltip, wordingShown(), false)
end

-- Called once by the entry file, before the panel's item hooks.
function ns.ItemLite.register()
    if registered then return end
    if not ns.Locale.supported or not (TooltipDataProcessor
        and TooltipDataProcessor.AddTooltipPreCall and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item) then return end
    registered = true
    TooltipDataProcessor.AddTooltipPreCall(Enum.TooltipDataType.Item, onItemTooltip)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItemShown)

    local modifierWatcher = CreateFrame("Frame")
    modifierWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
    modifierWatcher:SetScript("OnEvent", function(_, _, key)
        if not ns.isOriginalKey(key) then return end
        local wording = wordingShown()
        for tooltip in pairs(activeLinesByTooltip) do
            if util.canModify(tooltip) and tooltip:IsShown()
                and util.call(tooltip.IsTooltipType, tooltip, Enum.TooltipDataType.Item) then
                showWording(tooltip, wording, true)
            end
        end
    end)
end
