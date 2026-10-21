-- Comparisons as the game anchors them: "TOP" to the hovered tooltip, then
-- "LEFT" or "RIGHT" to its side, a second comparison beside the first. Each
-- one's panel attaches directly to the owner or neighbour at that edge, so
-- resetting the hidden comparison cannot move the visible panel.
return function(test)
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua" },
        { enums = { TooltipDataType = { Item = 0 } } })
    local ui, native = ns.ui, ns.Native
    local main, primary, secondary = ui.getPanel(GameTooltip), ui.getPanel(ShoppingTooltip1),
        ui.getPanel(ShoppingTooltip2)
    for _, panel in ipairs({ main, primary, secondary }) do panel:Show() end

    local function anchored(tooltip, panel)
        native.anchorToPanels(tooltip)
        ui.alignPanel(panel, tooltip)
        local point, relativeTo, relativePoint = panel:GetPoint(1)
        local targets = {}
        for index = 1, tooltip:GetNumPoints() do
            local _, target = tooltip:GetPoint(index)
            targets[index] = target == main and "main" or target == primary and "primary" or "other"
        end
        return { point, relativeTo == main and "main" or relativeTo == primary and "primary" or "other",
            relativePoint, targets }
    end

    -- Left of the hovered tooltip: the comparison's right edge is placed.
    ShoppingTooltip1:SetPoint("TOP", GameTooltip, 0, 0)
    ShoppingTooltip1:SetPoint("RIGHT", GameTooltip, "LEFT")
    test.check("a comparison on the left is pinned by its right edge", anchored(ShoppingTooltip1, primary),
        { "TOPRIGHT", "main", "TOPLEFT", { "main", "main" } })

    ShoppingTooltip2:SetPoint("TOP", GameTooltip, 0, 0)
    ShoppingTooltip2:SetPoint("TOPRIGHT", ShoppingTooltip1, "TOPLEFT")
    test.check("a second comparison on the left is pinned by its right edge", anchored(ShoppingTooltip2, secondary),
        { "TOPRIGHT", "primary", "TOPLEFT", { "main", "primary" } })

    -- Right of it: the left edge.
    ShoppingTooltip1:ClearAllPoints()
    ShoppingTooltip1:SetPoint("TOP", GameTooltip, 0, 0)
    ShoppingTooltip1:SetPoint("LEFT", GameTooltip, "RIGHT")
    test.check("a comparison on the right is pinned by its left edge", anchored(ShoppingTooltip1, primary),
        { "TOPLEFT", "main", "TOPRIGHT", { "main", "main" } })

    -- Anchored by "TOP" alone so far, as between the game's two SetPoint calls.
    ShoppingTooltip1:ClearAllPoints()
    ShoppingTooltip1:SetPoint("TOP", GameTooltip, 0, 0)
    test.check("a comparison placed by its top alone is pinned by its left edge", anchored(ShoppingTooltip1, primary)[1],
        "TOPLEFT")

    -- Native and Pretty frames can use different scales. Preserve the final
    -- physical corner while expressing the new offset in the panel's units.
    UIParent:SetScale(.8)
    main:SetScale(.75)
    primary:SetScale(.75)
    ShoppingTooltip1:SetScale(1.25)
    main.GetRight = function() return 400 end
    main.GetTop = function() return 500 end
    ShoppingTooltip1.GetLeft = function() return 300 end
    ShoppingTooltip1.GetTop = function() return 600 end
    ShoppingTooltip1:ClearAllPoints()
    ShoppingTooltip1:SetPoint("TOP", GameTooltip, 0, 0)
    ShoppingTooltip1:SetPoint("LEFT", GameTooltip, "RIGHT", 0, 0)
    anchored(ShoppingTooltip1, primary)
    local _, target, corner, x, y = primary:GetPoint(1)
    test.check("independent comparison anchors preserve physical position at different scales",
        { target == main, corner, string.format("%.3f", x), string.format("%.3f", y) },
        { true, "TOPRIGHT", "100.000", "500.000" })
end
