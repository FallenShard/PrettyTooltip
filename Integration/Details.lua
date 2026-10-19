-- The details a panel shows, appended to the game's own tooltip wherever it
-- shows instead: in the Blizzard layout, and for a type not restyled. The
-- original-tooltip key leaves the game's tooltip as it was.
local _, ns = ...
if not ns.TooltipTypes then return end
local util = ns.util
local isSecret = util.isSecret
local TooltipTypes = ns.TooltipTypes
local DETAIL_COLOR = ns.Palette.roles.detail
ns.Details = {}
local registered = false

-- The data type each tooltip last showed, for the modifier key to refresh.
local shownTypes = setmetatable({}, { __mode = "k" })

local function appends(tooltipType)
    return not ns.originalKeyDown() and not ns.restyles(tooltipType.option)
end

-- Reading costs as much as for a panel, so only while a detail would show.
local function anyDetail(tooltipType)
    for _, key in ipairs(tooltipType.detailKeys) do
        if ns.showsDetail(key) then return true end
    end
    return false
end

local function addRows(tooltip, rows)
    tooltip:AddLine(" ")
    for _, row in ipairs(rows) do
        local r, g, b = unpack(row.color or DETAIL_COLOR)
        if row.right and row.right ~= "" then
            local r2, g2, b2 = unpack(row.rightColor or row.color or DETAIL_COLOR)
            tooltip:AddDoubleLine(row.left, row.right, r, g, b, r2, g2, b2)
        else
            tooltip:AddLine(row.left, r, g, b, true)
        end
    end
    tooltip:Show()
end

local function onTooltipData(dataType, tooltip, data)
    if not util.canModify(tooltip) or tooltip.prettyTooltipScanner then return end
    shownTypes[tooltip] = dataType
    local tooltipType = TooltipTypes[dataType]
    if not (appends(tooltipType) and anyDetail(tooltipType)) then return end
    if isSecret(data) or type(data) ~= "table" then return end
    local ok, model = pcall(tooltipType.read, tooltip, data, ns.Game)
    if not ok or not model then return end
    local built, rows = pcall(tooltipType.details, model)
    if built and rows and #rows > 0 then pcall(addRows, tooltip, rows) end
end

-- Called once by the entry file, after the panels' hooks.
function ns.Details.register()
    if registered then return end
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then return end
    registered = true
    for dataType, tooltipType in pairs(TooltipTypes) do
        if tooltipType.details then
            TooltipDataProcessor.AddTooltipPostCall(dataType, function(tooltip, data)
                onTooltipData(dataType, tooltip, data)
            end)
        end
    end

    -- A game tooltip's lines cannot be taken back, so a key change fills it
    -- again. Refilling runs the game's tooltip code under the addon's taint;
    -- in combat the details wait for the next tooltip instead. Comparisons are
    -- filled with append after a clear, so refilling one would double it; the
    -- tooltip they compare against fills them again.
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("MODIFIER_STATE_CHANGED")
    watcher:SetScript("OnEvent", function(_, _, key)
        if not (ns.isDetailsKey(key) or ns.isOriginalKey(key)) or InCombatLockdown() then return end
        for tooltip, dataType in pairs(shownTypes) do
            if util.canModify(tooltip) and not ns.ui.isComparison(tooltip) and util.call(tooltip.IsShown, tooltip)
                and util.call(tooltip.IsTooltipType, tooltip, dataType) == true
                and not ns.restyles(TooltipTypes[dataType].option) then
                util.call(tooltip.RefreshData, tooltip)
            end
        end
    end)
end
