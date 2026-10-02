-- Follow cursor: a mouse-over tooltip of an enabled kind moves to the cursor once
-- its content is known. A kind left off is never touched, so addons that place
-- tooltips themselves keep doing so.
local _, ns = ...
local TYPES = Enum and Enum.TooltipDataType
if not (TooltipDataProcessor and TYPES and ns.TOOLTIP_KINDS) then
    return
end

local OFFSET = 16
local placing = false

local function place()
    local x, y = GetCursorPosition()
    local scale = GameTooltip:GetEffectiveScale()
    placing = true
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + OFFSET, y / scale + OFFSET)
    placing = false
end

local follower = CreateFrame("Frame")
follower:Hide()
follower:SetScript("OnUpdate", function(self)
    if GameTooltip:IsShown() then place() else self:Hide() end
end)

-- Bag buttons re-anchor their tooltip after every refresh, about five times a
-- second; undone at once, it never draws at the button.
hooksecurefunc(GameTooltip, "SetPoint", function()
    if follower:IsShown() and not placing then place() end
end)

-- Cleared before every new content, so a kind left off is not dragged along.
local function stop() follower:Hide() end
GameTooltip:HookScript("OnTooltipCleared", stop)
GameTooltip:HookScript("OnHide", stop)

for _, kind in ipairs(ns.TOOLTIP_KINDS) do
    for _, typeName in ipairs(kind.types) do
        local dataType = TYPES[typeName]
        if dataType then
            TooltipDataProcessor.AddTooltipPostCall(dataType, function(tooltip)
                if tooltip == GameTooltip and ns.option(kind.cursor) then
                    place()
                    follower:Show()
                end
            end)
        end
    end
end
