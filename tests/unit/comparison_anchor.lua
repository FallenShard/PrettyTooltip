-- Comparisons as the game anchors them: "TOP" to the hovered tooltip, then
-- "LEFT" or "RIGHT" to its side, a second comparison beside the first. Each
-- one's panel is pinned to the edge those points place, so a hidden tooltip
-- not yet fitted to its panel cannot push the panel over its neighbour.
return function(test)
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Game/Game.lua",
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
        return { point, relativeTo == tooltip, relativePoint, targets }
    end

    -- Left of the hovered tooltip: the comparison's right edge is placed.
    ShoppingTooltip1:SetPoint("TOP", GameTooltip, 0, 0)
    ShoppingTooltip1:SetPoint("RIGHT", GameTooltip, "LEFT")
    test.check("a comparison on the left is pinned by its right edge", anchored(ShoppingTooltip1, primary),
        { "TOPRIGHT", true, "TOPRIGHT", { "main", "main" } })

    ShoppingTooltip2:SetPoint("TOP", GameTooltip, 0, 0)
    ShoppingTooltip2:SetPoint("TOPRIGHT", ShoppingTooltip1, "TOPLEFT")
    test.check("a second comparison on the left is pinned by its right edge", anchored(ShoppingTooltip2, secondary),
        { "TOPRIGHT", true, "TOPRIGHT", { "main", "primary" } })

    -- Right of it: the left edge.
    ShoppingTooltip1:ClearAllPoints()
    ShoppingTooltip1:SetPoint("TOP", GameTooltip, 0, 0)
    ShoppingTooltip1:SetPoint("LEFT", GameTooltip, "RIGHT")
    test.check("a comparison on the right is pinned by its left edge", anchored(ShoppingTooltip1, primary),
        { "TOPLEFT", true, "TOPLEFT", { "main", "main" } })

    -- Anchored by "TOP" alone so far, as between the game's two SetPoint calls.
    ShoppingTooltip1:ClearAllPoints()
    ShoppingTooltip1:SetPoint("TOP", GameTooltip, 0, 0)
    test.check("a comparison placed by its top alone is pinned by its left edge", anchored(ShoppingTooltip1, primary)[1],
        "TOPLEFT")
end
