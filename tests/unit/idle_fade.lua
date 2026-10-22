-- Visible tooltips fade out after 30 seconds without input.
return function(test)
    local cursorX, cursorY = 500, 400
    GetCursorPosition = function() return cursorX, cursorY end
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Core/TooltipPlacement.lua", "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua",
        "Game/TooltipData.lua", "Data/Stats.lua", "Panel/Layout.lua", "Panel/Render.lua",
        "Tooltips/Object.lua", "Integration/Native.lua", "Integration/Placement.lua", "Integration/Hooks.lua" }, {
        enums = { TooltipDataType = { Item = 0, Object = 33 } },
        data = { type = 33, id = 1, lines = { { lineIndex = 1, leftText = "Mailbox" } } },
        lines = { { left = { text = "Mailbox" } } },
    })
    local duration = ns.ui.fadeOutDuration()
    local halfDuration = duration / 2
    local ticker
    for _, object in ipairs(world.objects) do
        if object._scripts.OnEvent == ns.ui.noteActivity then ticker = object; break end
    end
    test.check("idle activity tracker is installed", ticker ~= nil, true)
    local function tick(elapsed)
        ticker._scripts.OnUpdate(ticker, elapsed)
    end
    local tooltip = world.main
    ns.Hooks.install()
    local callback = world.postCalls[33][1]

    tick(29.9)
    tooltip:Show()
    callback(tooltip, { type = 33, id = 1, lines = { { lineIndex = 1, leftText = "Mailbox" } } })
    local panel = ns.ui.panels[tooltip]
    test.check("tooltip remains immediate before the idle threshold", panel:GetAlpha(), 1)

    tick(.1)
    test.check("idle tooltip starts fading out at 30 seconds", panel:GetAlpha(), 1)
    tick(halfDuration)
    test.check(("idle fade-out reaches half alpha at %g seconds"):format(halfDuration),
        panel:GetAlpha(), .5)
    ns.ui.noteActivity()
    test.check("activity cancels the idle fade-out", panel:GetAlpha(), 1)
    tick(29.9)
    tooltip:Show()
    callback(tooltip, { type = 33, id = 1, lines = { { lineIndex = 1, leftText = "Mailbox" } } })
    test.check("activity resets the idle threshold", panel:GetAlpha(), 1)

    test.check("debug fade starts on visible panels", ns.ui.testFadeOut(), 1)
    test.check("debug fade starts fully visible", panel:GetAlpha(), 1)
    tick(halfDuration)
    test.check(("debug fade reaches half alpha at %g seconds"):format(halfDuration),
        panel:GetAlpha(), .5)
    tick(halfDuration)
    test.check("debug fade completes by hiding the panel", panel:IsShown(), false)

    test.check("debug fade arms when no panel is visible", ns.ui.testFadeOut(), 0)
    tooltip:Show()
    callback(tooltip, { type = 33, id = 1, lines = { { lineIndex = 1, leftText = "Mailbox" } } })
    test.check("armed debug fade starts fully visible", panel:GetAlpha(), 1)
    tick(halfDuration)
    test.check("armed debug fade reaches half opacity", panel:GetAlpha(), .5)
    tick(halfDuration)
    test.check("armed debug fade hides the next tooltip", panel:IsShown(), false)
end
