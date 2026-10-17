-- The options page changes the editor's treatment live, while addon removal
-- and Defaults always leave a usable Blizzard appearance.
return function(test)
    local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Game/Game.lua",
        "UI/Options.lua", "UI/EditorSkin.lua" })
    local installed = false
    C_AddOns.GetAddOnInfo = function(addon)
        if installed and addon == "EllesmereUI" then return addon end
    end
    test.check("Blizzard is the default without EllesmereUI", ns.editorStyle(), "native")
    installed = true
    test.check("installing EllesmereUI keeps the Blizzard default", ns.editorStyle(), "native")

    local skin = ns.EditorSkin.create()
    local window = CreateFrame("Frame", nil, UIParent)
    local flatBackground = window:CreateTexture()
    skin:surface(window, flatBackground, {}, true)
    local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    local parts = skin.templateParts(button)
    local flatButton = button:CreateTexture()
    button.label = button:CreateFontString()
    skin:button(button, flatButton, {}, parts)
    local tab = CreateFrame("Button", nil, window, "MinimalTabTemplate")
    tab.label = tab.Text
    tab.label:SetText("Quests")
    skin:tab(tab, tab:CreateTexture(), {})
    tab:SetSelected(true)
    local slider = CreateFrame("Slider", nil, window, "MinimalSliderTemplate")
    parts = skin.templateParts(slider)
    local track = slider:CreateTexture()
    skin:slider(slider, track, parts)
    slider:SetValue(17)
    local edits = 0
    button:SetScript("OnClick", function() edits = edits + 1 end)
    ns.refreshEditorStyle = function() skin:refresh() end

    local page
    Settings = {
        RegisterCanvasLayoutCategory = function(canvas) page = canvas return {} end,
        RegisterAddOnCategory = function() end,
    }
    ns.Options.register()
    local nativeChoice, flatChoice
    for _, child in ipairs({ page:GetChildren() }) do
        if child:GetObjectType() == "CheckButton" then
            for _, label in ipairs({ child:GetRegions() }) do
                if label:GetText() == "Blizzard" then nativeChoice = child end
                if label:GetText() == "Flat (EllesmereUI)" then flatChoice = child end
            end
        end
    end
    test.check("main options selects Blizzard initially", nativeChoice:GetChecked(), true)
    test.check("EllesmereUI unlocks Flat", flatChoice:IsEnabled(), true)
    ns.refreshEditorStyle()
    test.check("native button artwork is visible", button.Left:IsShown(), true)
    test.check("flat artwork starts hidden", flatBackground:IsShown(), false)

    flatChoice:GetScript("OnClick")(flatChoice)
    test.check("choosing Flat saves the appearance", ns.option("editorStyle"), "flat")
    test.check("options radios update immediately", { nativeChoice:GetChecked(), flatChoice:GetChecked() }, { false, true })
    test.check("the live frame switches to flat", flatBackground:IsShown(), true)
    test.check("native button artwork is hidden in Flat", button.Left:IsShown(), false)
    test.check("Flat hides the native tab artwork", tab.Left:IsShown(), false)
    test.check("the selected tab label stays visible in Flat", tab.label:IsVisible(), true)
    test.check("the flat button artwork is visible", flatButton:IsShown(), true)
    test.check("native slider art is hidden in Flat", slider.Left:IsShown(), false)
    test.check("the slider thumb stays visible", slider:GetThumbTexture():IsShown(), true)
    test.check("button labels stay visible", button.label:IsVisible(), true)
    button:GetScript("OnClick")(button)
    test.check("editing still works after switching", edits, 1)
    test.check("a control's current value survives switching", slider:GetValue(), 17)
    ns.resetStyles()
    test.check("reset fonts and colors keeps editor appearance", ns.editorStyle(), "flat")

    installed = false
    page.OnRefresh()
    ns.refreshEditorStyle()
    test.check("removing EllesmereUI falls back to Blizzard", ns.editorStyle(), "native")
    test.check("Flat is disabled without EllesmereUI", flatChoice:IsEnabled(), false)
    test.check("fallback selects the Blizzard radio", nativeChoice:GetChecked(), true)
    test.check("the fallback restores native controls", button.Left:IsShown(), true)
    test.check("the fallback restores tab artwork", tab.Left:IsShown(), true)
    test.check("the selected tab survives switching", tab.selected, true)
    test.check("the fallback hides flat controls", flatButton:IsShown(), false)
    nativeChoice:GetScript("OnClick")(nativeChoice)
    flatChoice:GetScript("OnClick")(flatChoice)
    test.check("Flat cannot be chosen without EllesmereUI", ns.option("editorStyle"), "native")

    installed = true
    flatChoice:GetScript("OnClick")(flatChoice)
    page.OnDefault()
    test.check("Defaults restores Blizzard even with EllesmereUI", ns.editorStyle(), "native")
    test.check("Defaults immediately updates the editor", flatBackground:IsShown(), false)
    test.check("Defaults refreshes the selected radio", nativeChoice:GetChecked(), true)
    test.check("Defaults leaves the current control value intact", slider:GetValue(), 17)
    ns.setOption("editorStyle", "unknown")
    test.check("an invalid saved appearance uses Blizzard", ns.editorStyle(), "native")
end
