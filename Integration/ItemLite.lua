-- Native item wording for lite mode and full panels, with modifier-key restoration.
local _, ns = ...
local isSecret = ns.util.isSecret
local stats = ns.Stats
local LINE = Enum and Enum.TooltipDataLineType or {}
ns.ItemLite = {}
local registered = false

local activeLinesByTooltip = setmetatable({}, { __mode = "k" })
local hookedTooltips = setmetatable({}, { __mode = "k" })

local function onItemTooltip(_, data)
    if not ns.option("itemPanels") then return end
    if isSecret(data) or not data then return end
    local lines = data.lines
    if isSecret(lines) or not lines then return end

    -- Keep the line table and its length intact. Other addons may have added
    -- rows to the same cached tooltip data since our previous pass.
    for index, source in ipairs(lines) do
        if not isSecret(source) and source and not source.prettyTooltipOriginal then
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
                    copy.wrapText = copy.wrapText or #displayLines > 1
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
-- key is held, lite mode's shortened wording in native colors but for magic,
-- else the panel's.
local function wordingShown()
    if ns.originalKeyDown() or not ns.option("itemPanels") then return "original" end
    return ns.option("itemLite") and "lite" or "display"
end

local function showWording(tooltip, wording, relayout)
    local rows = activeLinesByTooltip[tooltip]
    if not rows then return end
    for _, row in ipairs(rows) do
        row.fontString:SetText(row[wording] or row.original)
    end
    if relayout then tooltip:Show() end
end

local function onItemShown(tooltip, data)
    if isSecret(data) or not data then return end
    local lines = data.lines
    if isSecret(lines) or not lines then return end

    if not hookedTooltips[tooltip] then
        local function forget(cleared) activeLinesByTooltip[cleared] = nil end
        tooltip:HookScript("OnHide", forget)
        tooltip:HookScript("OnTooltipCleared", forget)
        hookedTooltips[tooltip] = true
    end

    local info = tooltip:GetProcessingTooltipInfo()
    local rows = (info and info.append and activeLinesByTooltip[tooltip]) or {}
    for _, line in ipairs(lines) do
        if not isSecret(line) and line and line.lineIndex and line.prettyTooltipOriginal then
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
    if GetLocale() ~= "enUS" or not (TooltipDataProcessor
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
            if tooltip:IsShown() and tooltip:IsTooltipType(Enum.TooltipDataType.Item) then
                showWording(tooltip, wording, true)
            end
        end
    end)
end
