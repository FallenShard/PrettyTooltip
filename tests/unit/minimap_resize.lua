-- The minimap's secret text is sized by the game's tooltip, which the game
-- sizes after the data arrives: the panel redraws as it resizes.
return function(test)
    local MINIMAP = 21
    local secret = { __secret = true }
    local fixture = { enums = { TooltipDataType = { Item = 0, Object = 33, MinimapMouseover = MINIMAP } },
        data = { type = MINIMAP, lines = { { type = 0, lineIndex = 1, leftText = secret } } },
        lines = { { left = { text = secret } } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Minimap.lua", "Integration/Native.lua",
        "Integration/Placement.lua", "Integration/Hooks.lua" }, fixture)
    local tooltip = world.main
    C_Timer.After = function() end
    ns.Hooks.install()
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    -- The size of the last tooltip, until the game resizes it for this one.
    tooltip:SetSize(66, 33)
    tooltip:Show()
    world.postCalls[MINIMAP][1](tooltip, fixture.data)
    local panel = ns.ui.panels[tooltip]
    local narrow = panel.width
    test.check("the panel shows the secret text", { panel:IsShown(), tooltip:GetAlpha() }, { true, 0 })
    tooltip:SetSize(86, 33)
    tooltip:GetScript("OnSizeChanged")(tooltip, 86, 33)
    test.check("and widens as the game's tooltip does", panel.width - narrow, ns.ui.snap(panel, 20))
end
