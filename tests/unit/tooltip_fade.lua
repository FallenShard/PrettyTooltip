-- Fade lifecycle: native timing is mirrored, custom timing survives native Hide,
-- and a new hover or a hidden parent cannot leave stale content on screen.
return function(test)
    local fixture = { enums = { TooltipDataType = { Item = 0, Object = 33 } },
        data = { type = 33, id = 1, lines = { { lineIndex = 1, leftText = "Mailbox" } } },
        lines = { { left = { text = "Mailbox" } } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua", "Integration/Native.lua", "Integration/Placement.lua",
        "Integration/Hooks.lua", "Integration/Cursor.lua", "UI/Options.lua" }, fixture)
    local tooltip = world.main
    local queued = {}
    C_Timer.After = function(_, callback) queued[#queued + 1] = callback end
    local function flush()
        local callbacks = queued
        queued = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    ns.Hooks.install()
    local post = world.postCalls[33][1]
    local function show()
        tooltip:SetParent(UIParent)
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:ClearAllPoints()
        tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
        tooltip:Show()
        tooltip:SetAlpha(1)
        post(tooltip, fixture.data)
        flush()
        return ns.ui.panels[tooltip]
    end
    local panel = show()
    local function step(seconds) panel:GetScript("OnUpdate")(panel, seconds) end
    local function hide()
        tooltip:Hide()
        tooltip:GetScript("OnHide")(tooltip)
    end
    local function alpha() return math.floor(panel:GetAlpha() * 100 + .5) end
    test.check("Blizzard timing is the default", ns.option("customFade"), false)
    tooltip:FadeOut()
    step(.5)
    test.check("the native delay keeps the panel opaque", { panel:IsShown(), alpha() }, { true, 100 })
    -- C++ writes alpha without going through the Lua SetAlpha hook.
    tooltip._alpha = .4
    step(.1)
    test.check("default fade mirrors the actual client alpha", alpha(), 40)
    tooltip._alpha = 0
    step(.01)
    test.check("zero alpha completes even a native fade that stays shown", { panel:IsShown(), panel.fade == nil }, { false, true })
    panel = show()
    tooltip:FadeOut()
    hide()
    step(.01)
    test.check("native hide also completes the default fade", { panel:IsShown(), panel.fade == nil }, { false, true })

    ns.setOption("customFade", true)
    ns.setOption("hideDelay", 2)
    ns.setOption("fadeDuration", 1)
    panel = show()
    tooltip:FadeOut()
    step(1)
    tooltip:FadeOut()
    test.check("repeated FadeOut does not restart the clock", panel.fade.elapsed, 1)
    hide()
    tooltip:GetScript("OnTooltipCleared")(tooltip)
    flush()
    step(1)
    test.check("custom delay survives native hide and clear", { panel:IsShown(), alpha() }, { true, 100 })
    step(.5)
    test.check("custom fade reaches half opacity", alpha(), 50)
    step(.5)
    test.check("custom fade ends on time and resets alpha", { panel:IsShown(), panel.fade == nil, alpha() }, { false, true, 100 })

    panel = show()
    tooltip:FadeOut()
    step(2.5)
    tooltip:Show()
    test.check("Show cancels the fade and restores full opacity", { panel.fade == nil, alpha(), ns.Native.isParked(tooltip) }, { true, 100, false })
    tooltip:FadeOut()
    step(.5)
    post(tooltip, fixture.data)
    test.check("same-target handover cancels pending dismissal", { panel.fade == nil, panel:IsShown(), alpha() }, { true, true, 100 })
    flush()
    tooltip:FadeOut()
    step(.5)
    fixture.data.id = 2
    fixture.data.lines[1].leftText = "Chest"
    tooltip._left[1]:SetText("Chest")
    post(tooltip, fixture.data)
    test.check("another target replaces the fading tooltip immediately", { panel.key, panel.fade == nil, alpha() }, { "Chest", true, 100 })
    flush()

    panel = show()
    hide()
    step(2.5)
    test.check("direct Hide also uses custom timing", { panel:IsShown(), alpha() }, { true, 50 })
    step(.5)

    panel = show()
    tooltip:FadeOut()
    local parent = CreateFrame("Frame", nil, UIParent)
    parent:Hide()
    tooltip:SetParent(parent)
    -- In the real client a parent hide fires this while IsShown stays true.
    tooltip:GetScript("OnHide")(tooltip)
    test.check("a hidden parent dismisses the fade immediately", { panel:IsShown(), panel.fade == nil }, { false, true })

    ns.setOption("hideDelay", 1)
    ns.setOption("fadeDuration", 0)
    panel = show()
    tooltip:FadeOut()
    step(.9)
    test.check("zero-duration fade stays opaque until its delay", alpha(), 100)
    step(.1)
    test.check("zero-duration fade hides without dividing by zero", panel:IsShown(), false)
    ns.setOption("hideDelay", 0)
    panel = show()
    tooltip:FadeOut()
    test.check("both zero opts into instant hiding", panel:IsShown(), false)

    ns.setOption("hideDelay", -5)
    ns.setOption("fadeDuration", 999)
    test.check("custom values stay in slider bounds", { ns.fadeTiming() }, { 0, 5 })
    ns.setOption("hideDelay", world.secret)
    ns.setOption("fadeDuration", 0 / 0)
    test.check("invalid values get finite defaults", { ns.fadeTiming() }, { 1, 1 })

    local page
    Settings = { RegisterCanvasLayoutCategory = function(frame) page = frame return {} end,
        RegisterAddOnCategory = function() end }
    ns.Options.register()
    local sliders = {}
    local function visit(frame)
        for _, child in ipairs({ frame:GetChildren() }) do
            if child:GetObjectType() == "Slider" and child:GetValue() <= 5 then sliders[#sliders + 1] = child end
            visit(child)
        end
    end
    visit(page)
    test.check("options expose both timing sliders", #sliders, 2)
    sliders[1]:GetScript("OnValueChanged")(sliders[1], 2.5)
    sliders[2]:GetScript("OnValueChanged")(sliders[2], .5)
    test.check("sliders save independent timings", { ns.fadeTiming() }, { 2.5, .5 })
    page.OnDefault()
    test.check("Defaults returns to native timings", ns.option("customFade"), false)
end
