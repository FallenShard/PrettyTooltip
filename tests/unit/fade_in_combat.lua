-- A world unit's tooltip that starts fading: outside combat the panel fades
-- and the game's tooltip hides at once; in combat the addon never hides the
-- game's tooltip, as that would run its OnHide under the addon's taint.
return function(test)
    local fixture = { enums = { TooltipDataType = { Item = 0, Object = 33, UnitAura = 7 } },
        data = { type = 33, id = 1, lines = { { lineIndex = 1, leftText = "Mailbox" } } },
        lines = { { left = { text = "Mailbox" } } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua", "Integration/Native.lua",
        "Integration/Hooks.lua" }, fixture)
    local tooltip = world.main
    local combat = false
    InCombatLockdown = function() return combat end
    ns.Hooks.install()
    local callback = world.postCalls[33][1]
    local function show()
        tooltip:Show()
        tooltip:SetAlpha(1)
        callback(tooltip, fixture.data)
        return ns.ui.panels[tooltip]
    end

    combat = true
    local panel = show()
    ns.Native.fadeOut(tooltip)
    test.check("in combat the game's tooltip is left to its own fade", { tooltip:IsShown(), panel:IsShown() },
        { true, true })
    combat = false
    ns.Native.restoreNative(tooltip)
    panel = show()
    ns.Native.fadeOut(tooltip)
    test.check("outside combat the game's tooltip hides at once", tooltip:IsShown(), false)
end
