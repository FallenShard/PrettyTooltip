-- Another addon's own lines (Questie's map icons) reuse the tooltip during a
-- fade: the fading panel goes and their tooltip shows.
return function(test)
    local fixture = { enums = { TooltipDataType = { Item = 0, Object = 33 } },
        data = { type = 33, id = 1, lines = { { lineIndex = 1, leftText = "Mailbox" } } },
        lines = { { left = { text = "Mailbox" } } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua", "Integration/Native.lua",
        "Integration/Placement.lua", "Integration/Hooks.lua" }, fixture)
    local tooltip = world.main
    local queued = {}
    C_Timer.After = function(_, callback) queued[#queued + 1] = callback end
    local function flush()
        local callbacks = queued
        queued = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    ns.Hooks.install()
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    tooltip:Show()
    tooltip:SetAlpha(1)
    world.postCalls[33][1](tooltip, fixture.data)
    flush()
    local panel = ns.ui.panels[tooltip]
    local function step(seconds) panel:GetScript("OnUpdate")(panel, seconds) end
    tooltip:FadeOut()
    tooltip._alpha = .6
    step(.1)
    -- Another addon reuses the tooltip with lines only: the clear fires
    -- inside SetOwner, before its post-hook.
    tooltip:GetScript("OnTooltipCleared")(tooltip)
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:AddLine("[48] Repurposed Totems")
    tooltip:Show()
    tooltip:SetAlpha(1)
    flush()
    step(.3)
    test.check("the old panel is gone and the addon's tooltip shows",
        { panel:IsShown(), tooltip:GetAlpha() }, { false, 1 })
end
