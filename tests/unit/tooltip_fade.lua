-- Fade lifecycle: off hides at once, the timings survive native Hide,
-- and a new hover or a hidden parent cannot leave stale content on screen.
return function(test)
    local fixture = { enums = { TooltipDataType = { Item = 0, Object = 33 } },
        data = { type = 33, id = 1, lines = { { lineIndex = 1, leftText = "Mailbox" } } },
        lines = { { left = { text = "Mailbox" } } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Item.lua", "Tooltips/Object.lua", "Integration/Native.lua",
        "Integration/Placement.lua", "Integration/Hooks.lua", "Integration/Cursor.lua", "UI/Samples.lua",
        "UI/EditorSkin.lua", "UI/Editor.lua" }, fixture)
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
    test.check("fading is off by default", ns.option("fadeTooltips"), false)
    tooltip:FadeOut()
    test.check("off, the panel hides as the cursor leaves", { panel:IsShown(), panel.fade == nil }, { false, true })
    flush()

    ns.setOption("fadeTooltips", true)
    ns.setOption("hideDelay", 2)
    ns.setOption("fadeDuration", 1)
    panel = show()
    tooltip:FadeOut()
    step(1)
    tooltip:FadeOut()
    test.check("repeated FadeOut does not restart the clock", panel.fade.elapsed, 1)
    step(1)
    test.check("custom delay holds full opacity", { panel:IsShown(), alpha() }, { true, 100 })
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
    test.check("a tooltip the game hides, as an item's, hides at once with fading on",
        { panel:IsShown(), panel.fade == nil }, { false, true })
    flush()
    panel = show()
    tooltip:FadeOut()
    step(.5)
    hide()
    test.check("a Hide ends a fade at once, as it does the game's",
        { panel:IsShown(), panel.fade == nil, alpha(), ns.Native.isParked(tooltip) }, { false, true, 100, false })
    flush()

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

    ns.resetOptions()
    ns.openEditor()
    local editor = PrettyTooltipEditor
    editor:GetScript("OnShow")(editor)
    local sliders, fadeBox, generalPage = {}, nil, nil
    for _, widget in ipairs(world.objects) do
        if widget:GetObjectType() == "Slider" then
            for _, label in ipairs({ widget:GetParent():GetParent():GetRegions() }) do
                if label.GetText and label:GetText() == "Fade Delay" then sliders[1] = widget end
                if label.GetText and label:GetText() == "Fade Duration" then sliders[2] = widget end
            end
        elseif widget:GetObjectType() == "CheckButton" then
            for _, label in ipairs({ widget:GetRegions() }) do
                if label:GetText() == "Enable Tooltip Fading" then fadeBox = widget end
            end
        elseif widget.label and widget.label.GetText and widget.label:GetText() == "Tooltips" then
            generalPage = widget
        end
    end
    -- Fading is on the shared Tooltips page.
    generalPage:GetScript("OnClick")(generalPage)
    test.check("the editor offers tooltip fading, off", fadeBox:GetChecked(), false)
    test.check("the editor exposes both timing sliders", #sliders, 2)
    test.check("the sliders stay hidden while fading is off", sliders[1]:GetParent():GetParent():IsShown(), false)
    fadeBox:SetChecked(true)
    fadeBox:GetScript("OnClick")(fadeBox)
    test.check("enabling fading shows its timings",
        { ns.option("fadeTooltips"), sliders[1]:GetParent():GetParent():IsShown() }, { true, true })
    sliders[1]:GetScript("OnValueChanged")(sliders[1], 2.5)
    sliders[2]:GetScript("OnValueChanged")(sliders[2], .5)
    test.check("sliders save independent timings", { ns.fadeTiming() }, { 2.5, .5 })
    fadeBox:SetChecked(false)
    fadeBox:GetScript("OnClick")(fadeBox)
    test.check("turning fading off saves it", ns.option("fadeTooltips"), false)

    PrettyTooltipDB = { customFade = true }
    ns.migrateOptions()
    test.check("1.4.1's custom timings keep fading on", { PrettyTooltipDB.fadeTooltips, PrettyTooltipDB.customFade }, { true, nil })
    PrettyTooltipDB = { customFade = false }
    ns.migrateOptions()
    test.check("1.4.1's game-mirrored fade turns off", { ns.option("fadeTooltips"), PrettyTooltipDB.customFade }, { false, nil })
end
