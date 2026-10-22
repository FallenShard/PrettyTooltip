-- Combat hides native tooltips and Pretty panels, then restores them afterward.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Core/TooltipPlacement.lua", "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Panel/Layout.lua", "Panel/Render.lua", "Integration/Native.lua",
        "Integration/Placement.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Object = 33 } },
    })
    local combat = false
    InCombatLockdown = function() return combat end
    ns.TooltipTypes[33] = {
        option = "objectPanels",
        key = function(_, data) return data.id end,
        read = function(_, data) return { id = data.id } end,
        render = function(panel, tooltip)
            panel:SetSize(200, 40)
            ns.ui.alignPanel(panel, tooltip)
            panel:Show()
        end,
    }
    ns.Hooks.install()
    local tooltip = world.main
    local callback = world.postCalls[33][1]
    local data = { type = 33, id = 1, lines = {} }

    tooltip:Show()
    tooltip:SetAlpha(1)
    callback(tooltip, data)
    local panel = ns.ui.panels[tooltip]
    test.check("Pretty panel is initially visible", panel:IsShown(), true)

    combat = true
    world.fireEvent("PLAYER_REGEN_DISABLED")
    test.check("combat hides the Pretty panel and native tooltip",
        { panel:IsShown(), tooltip:GetAlpha() }, { false, 0 })
    tooltip:Show()
    tooltip:SetAlpha(1)
    test.check("native alpha changes cannot reveal a tooltip during combat", tooltip:GetAlpha(), 0)
    tooltip._alpha = 1
    ns.Hooks.enforceCombatVisibility()
    test.check("per-frame native alpha changes are suppressed during combat", tooltip:GetAlpha(), 0)
    panel:Show()
    test.check("a Pretty panel cannot be shown during combat", panel:IsShown(), false)
    callback(tooltip, data)
    test.check("a tooltip first filled during combat remains hidden", { panel:IsShown(), tooltip:GetAlpha() }, { false, 0 })

    combat = false
    world.fireEvent("PLAYER_REGEN_ENABLED")
    test.check("the Pretty panel returns after combat", { panel:IsShown(), tooltip:GetAlpha() }, { true, 0 })

    ns.setOption("layout", "blizzard")
    tooltip:SetAlpha(1)
    callback(tooltip, data)
    test.check("Blizzard layout shows its native tooltip out of combat", tooltip:GetAlpha(), 1)
    combat = true
    world.fireEvent("PLAYER_REGEN_DISABLED")
    tooltip:SetAlpha(1)
    test.check("combat also hides the native Blizzard tooltip", tooltip:GetAlpha(), 0)
    combat = false
    world.fireEvent("PLAYER_REGEN_ENABLED")
    test.check("native tooltip opacity is restored after combat", tooltip:GetAlpha(), 1)

    ns.setOption("hideTooltipsInCombat", false)
    combat = true
    tooltip:Show()
    tooltip:SetAlpha(1)
    test.check("the option can leave tooltips visible during combat", tooltip:GetAlpha(), 1)
end
