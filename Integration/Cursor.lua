-- Follow cursor. A tooltip type left off is never touched, so addons that place
-- tooltips themselves keep doing so.
local _, ns = ...
ns.Cursor = {}
local registered = false

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

-- Cursor placement follows rewrite restoration and panel fitting.
function ns.Cursor.register()
    if registered then return end
    local TYPES = Enum and Enum.TooltipDataType
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and TYPES and ns.TOOLTIP_TYPES) then return end
    registered = true
    local follower = CreateFrame("Frame")
    follower:Hide()

    -- Only default-anchored tooltips follow, as with EllesmereUI; bags re-anchor
    -- theirs on every refresh.
    local defaultAnchored = false
    local cursorKey, originalPoints
    local function stop()
        follower:Hide()
        reclamp()
        cursorKey, originalPoints = nil, nil
    end
    local function restoreAnchor()
        follower:Hide()
        reclamp()
        if not originalPoints then return end
        -- Restore without SetOwner, which can clear the tooltip's content.
        local points = originalPoints
        originalPoints = nil
        GameTooltip:ClearAllPoints()
        for _, point in ipairs(points) do
            GameTooltip:SetPoint(unpack(point))
        end
        local panel = ns.ui and ns.ui.shownPanel(GameTooltip)
        if panel then pcall(ns.ui.alignPanel, panel, GameTooltip) end
    end
    local function refresh(allowHidden)
        local follows = (allowHidden or GameTooltip:IsShown()) and defaultAnchored and cursorKey and ns.option(cursorKey)
            and not (ns.option("cursorDisableInCombat") and InCombatLockdown())
        if follows then
            if not follower:IsShown() then
                originalPoints = {}
                for index = 1, GameTooltip:GetNumPoints() do
                    originalPoints[index] = { GameTooltip:GetPoint(index) }
                end
            end
            place()
            follower:Show()
        elseif follower:IsShown() then
            -- Keep the cursor preference for combat ending.
            restoreAnchor()
        end
    end
    follower:SetScript("OnUpdate", function() refresh() end)
    follower:RegisterEvent("PLAYER_REGEN_DISABLED")
    follower:RegisterEvent("PLAYER_REGEN_ENABLED")
    follower:SetScript("OnEvent", function() refresh() end)

    hooksecurefunc(GameTooltip, "SetOwner", function()
        defaultAnchored = false
        stop()
    end)
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip)
        if tooltip == GameTooltip then defaultAnchored = true end
    end)

    -- The game re-places a default tooltip when it refreshes; undone at once.
    hooksecurefunc(GameTooltip, "SetPoint", function()
        if follower:IsShown() and not placing then refresh() end
    end)

    -- A world unit's tooltip fades out where it stands, which trails the cursor.
    if GameTooltip.FadeOut then
        hooksecurefunc(GameTooltip, "FadeOut", function(self)
            if follower:IsShown() then self:Hide() end
        end)
    end

    -- Cleared before every new content, so a tooltip type left off is not dragged along.
    GameTooltip:HookScript("OnTooltipCleared", function()
        -- A refresh can reuse the same owner and anchor. Restore before
        -- forgetting it, so its next handover cannot save our cursor position.
        restoreAnchor()
        stop()
    end)
    GameTooltip:HookScript("OnHide", stop)

    for _, tooltipType in ipairs(ns.TOOLTIP_TYPES) do
        for _, typeName in ipairs(tooltipType.types) do
            local dataType = TYPES[typeName]
            if dataType then
                TooltipDataProcessor.AddTooltipPostCall(dataType, function(tooltip)
                    if tooltip == GameTooltip then
                        cursorKey = tooltipType.cursor
                        refresh(true)
                    end
                end)
            end
        end
    end
end
