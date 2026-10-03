-- Follow cursor. A kind left off is never touched, so addons that place
-- tooltips themselves keep doing so.
local _, ns = ...
local TYPES = Enum and Enum.TooltipDataType
if not (TooltipDataProcessor and TYPES and ns.TOOLTIP_KINDS) then
    return
end

local OFFSET = 16
local placing = false
local wasClamped

-- Kept on screen, every resize of the larger hidden tooltip near an edge would
-- shift the panel; the panel keeps itself on screen instead.
local function unclamp()
    if wasClamped ~= nil then return end
    wasClamped = GameTooltip:IsClampedToScreen()
    GameTooltip:SetClampedToScreen(false)
end

local function reclamp()
    if wasClamped == nil then return end
    GameTooltip:SetClampedToScreen(wasClamped)
    wasClamped = nil
end

-- The panel hangs from the hidden tooltip's top, and refreshes briefly resize
-- that tooltip; placing its top from the panel's height keeps the panel still.
local function place()
    local x, y = GetCursorPosition()
    local scale = GameTooltip:GetEffectiveScale()
    local panel = ns.ui and ns.ui.shownPanel(GameTooltip)
    local height = panel and panel:GetHeight() * panel:GetEffectiveScale() / scale
        or GameTooltip:GetHeight()
    if panel then unclamp() else reclamp() end
    placing = true
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + OFFSET,
        y / scale + OFFSET + height)
    placing = false
    -- The panel took its side from the anchor the game set before this one.
    if panel then pcall(ns.ui.alignPanel, panel, GameTooltip) end
end

local follower = CreateFrame("Frame")
follower:Hide()
follower:SetScript("OnUpdate", function(self)
    if GameTooltip:IsShown() then place() else self:Hide() end
end)

-- Only default-anchored tooltips follow, as with EllesmereUI; bags re-anchor
-- theirs on every refresh.
local defaultAnchored = false
hooksecurefunc(GameTooltip, "SetOwner", function() defaultAnchored = false end)
hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip)
    if tooltip == GameTooltip then defaultAnchored = true end
end)

-- The game re-places a default tooltip when it refreshes; undone at once.
hooksecurefunc(GameTooltip, "SetPoint", function()
    if follower:IsShown() and not placing then place() end
end)

-- A world unit's tooltip fades out where it stands, which trails the cursor.
if GameTooltip.FadeOut then
    hooksecurefunc(GameTooltip, "FadeOut", function(self)
        if follower:IsShown() then self:Hide() end
    end)
end

-- Cleared before every new content, so a kind left off is not dragged along.
local function stop()
    follower:Hide()
    reclamp()
end
GameTooltip:HookScript("OnTooltipCleared", stop)
GameTooltip:HookScript("OnHide", stop)

for _, kind in ipairs(ns.TOOLTIP_KINDS) do
    for _, typeName in ipairs(kind.types) do
        local dataType = TYPES[typeName]
        if dataType then
            TooltipDataProcessor.AddTooltipPostCall(dataType, function(tooltip)
                if tooltip == GameTooltip and defaultAnchored and ns.option(kind.cursor) then
                    place()
                    follower:Show()
                end
            end)
        end
    end
end
